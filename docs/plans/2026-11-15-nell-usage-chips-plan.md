# Nell usage chips: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two always-visible gauge chips, 7D on top of 5H, above Chat and Code, showing weekly and 5-hour usage. Nell shows her tired face when either one is above 90%.

**Architecture:** Nell's generated `--settings` files gain a `statusLine` command. It posts Claude Code's status JSON to a new `/status` path on Nell's existing socket. The hook server decodes it into a `UsageReading`, replies with the short line Claude prints in its own status bar, and hands the reading to `NellModel`. Pure NellCore functions turn readings into gauges, tooltips, the tired flag and the next reset time. SwiftUI draws the two chips in `NellBlock`'s chip column.

**Tech Stack:** Swift 6.4 SwiftPM (Command Line Tools only), SwiftUI/AppKit, Swift Testing via `scripts/test.sh`, bash plus curl for the status script.

**Spec:** `docs/specs/2026-11-15-nell-usage-chips-design.md`

## Global Constraints

- Never modify `~/.claude/settings.json` or `~/.claude.json`. Settings reach Claude only through Nell's own `--settings` files (`hooks-chat.json`, `hooks-code.json`).
- Never read or handle the user's login token.
- The status line must never slow Claude down. If Nell is unreachable it gives up within a fraction of a second, exits 0 and prints nothing.
- Idle CPU stays near zero. Chips redraw only when a value changes.
- Fill colours: `leaf` below 50%, `gold` from 50% to 80% inclusive, `berry` above 80%. These are Plum Night tokens.
- Tired face: when either limit is **above 90%** and its reset hasn't passed, an idle body gets `exhausted` instead of `idle`. Typing keeps `intent`, and the reaction faces (happy, smile, sad, scared) still win.
- No reading yet: the chip shows a dimmed `–`. Reset passed: the chip shows 0% until the next reading. There is no persistence across relaunches.
- Status line text: `5h 42% · 7d 81%`, or empty when there's no data.
- Tooltip copy: `Session 42% · resets 3:45pm` on the same day, `Weekly 81% · resets Thu 9:00am` on another day, `Session · no reading yet` with no data, and `Session 0% · reset at 3:45pm` once the reset has passed.
- Command Line Tools only. No SwiftUI `@State` (use `@StateObject` or `@Published`). Run tests with `scripts/test.sh`, and package with `bash scripts/bundle.sh`.
- The showcase and stress test never touch `build/Nell.app` or `~/Library/Application Support/Nell`, and never start kitty or claude.
- Docs are dated, typed, filed under `docs/` and indexed in `docs/README.md` in the same commit. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Status JSON with no `rate_limits`** (API-key accounts, or the first render before any reply). Decoding gives no reading, the chips stay at `–`, and the line prints empty. Pinned in Task 2 by `usageDecodeWithoutRateLimitsIsNil`.
2. **Only one window present.** A newer reading must not wipe the other window's last value. Pinned in Task 2 by `usageMergeKeepsMissingWindow`.
3. **`resets_at` format.** Epoch seconds, an ISO-8601 string or a missing value must all decode, and a bad value must not drop the whole reading. Pinned in Task 2 by `usageDecodesResetFormats`.
4. **A reset passing while nothing happens.** The chip empties and the tired face ends without waiting for a hook event. Pinned in Task 2 by `usageNextReset` and wired in Task 3 (wake scheduling).
5. **Nell not running.** The status script still returns quickly, prints nothing and exits 0. Pinned in Task 3 by `statusScriptGivesUpQuietly`.

---

### Task 1: Status-line spike

**Files:**
- Create: `docs/notes/2026-11-15-nell-usage-statusline-findings.md`
- Create: `Tests/NellCoreTests/Fixtures/statusline.json` (one real capture, with home paths replaced by `/Users/me`)
- Modify: `docs/README.md` (index the findings in the "Usage chips" section)

- [ ] **Step 1:** Make a scratch project in the scratchpad and a temporary settings file whose `statusLine` command is `cat > <scratch>/status-$$.json; echo ok`. Run `claude --settings <tmp.json> "say hi"` inside a standalone `kitty --start-as=hidden` window, without using Nell's kitty or Nell's Application Support files. Wait for the captures, then close that kitty. Record:
  - the exact `rate_limits` shape, and whether `resets_at` is epoch seconds or ISO-8601;
  - whether the status line kept running while the window was hidden.
- [ ] **Step 2:** Repeat with Chat's arguments: `--tools "" --strict-mcp-config --no-chrome --setting-sources project` (see `claudeArgs` in `Sources/NellCore/Launch.swift`). Record whether the status line runs, and how often it runs during one reply.
- [ ] **Step 3:** Write the findings, add the scrubbed fixture, index the doc, and commit `spike: status line usage data`. **If `rate_limits` is absent from every capture, stop and report to the user.**

### Task 2: Usage logic in NellCore

**Files:**
- Create: `Sources/NellCore/Usage.swift`
- Modify: `Sources/NellCore/Reactions.swift:43` (`face`)
- Test: `Tests/NellCoreTests/UsageTests.swift`, `Tests/NellCoreTests/ReactionsTests.swift`

**Interfaces:**
- Produces:
  - `public enum UsageKind: Sendable { case session, weekly }` with `label` (`"5H"` and `"7D"`) and `title` (`"Session"` and `"Weekly"`).
  - `public enum UsageLevel: Sendable, Hashable { case none, low, mid, high }`.
  - `public struct UsageWindow: Equatable, Sendable { var used: Double; var resetsAt: Date? }`, where `used` is in percent (0–100).
  - `public struct UsageReading: Equatable, Sendable { var session: UsageWindow?; var weekly: UsageWindow? }`, with:
    - `static func decode(_ data: Data) -> UsageReading?`, which returns nil when neither window is present;
    - `func merged(_ newer: UsageReading) -> UsageReading`;
    - `func nextReset(after now: Date) -> Date?`.
  - `public struct UsageGauge: Equatable, Sendable { var fraction: Double?; var level: UsageLevel; var tooltip: String }`.
  - `public func gauge(_ w: UsageWindow?, _ kind: UsageKind, now: Date, timeZone: TimeZone = .current) -> UsageGauge`.
  - `public func tired(_ r: UsageReading?, now: Date) -> Bool`.
  - `public func statusLineText(_ r: UsageReading?) -> String`.
  - `face(body:emoji:tired: Bool = false) -> Face`.

- [ ] **Step 1: Write the failing tests** in `UsageTests.swift`, with fixed dates and `TimeZone(identifier: "UTC")!`:
  - `usageDecodesFixture`: decoding `Fixtures/statusline.json` gives both windows with the captured values.
  - `usageDecodeWithoutRateLimitsIsNil`: `{"model":{}}` decodes to nil, and so does `{"rate_limits":{}}`.
  - `usageDecodesResetFormats`: `resets_at` of `1763221500`, of `"2025-11-15T15:45:00Z"` (both give the same Date), and missing (gives nil) all keep `used`. `resets_at: "soon"` keeps `used` with `resetsAt == nil`.
  - `usageMergeKeepsMissingWindow`: an old reading with both windows, merged with a newer one that has only `session`, gives the new session and the old weekly.
  - `usageLevels`: 49.9 is `.low`, 50 is `.mid`, 80 is `.mid`, 80.1 is `.high`, and a nil window is `.none` with `fraction == nil`.
  - `usageGaugeClamps`: `used` of 104 gives fraction 1 and tooltip `Session 104% · resets …`. `used` of -3 gives fraction 0.
  - `usageTooltips`: with now = 2025-11-15 12:00 UTC, the exact strings from Global Constraints for:
    - session 42 resetting at 15:45 the same day;
    - weekly 81 resetting Thursday 2025-11-20 09:00;
    - session with no reading;
    - session 95 whose reset at 11:00 has already passed, which shows `Session 0% · reset at 11:00am` with fraction 0, level `.low`.
  - `usageTired`: either window at 90.5 with a future reset gives true. 90 gives false. 95 with a passed reset gives false. A nil reading gives false.
  - `usageNextReset`: gives the earliest future `resetsAt` and skips past ones. When none are in the future, it gives nil.
  - `statusLineTextFormats`: session 42.4 and weekly 80.6 give `5h 42% · 7d 81%`. Session only gives `5h 42%`. Nil gives `""`.
  - In `ReactionsTests`, `tiredFaceOnlyWhenIdle`: `face(body: .idle, emoji: nil, tired: true) == .exhausted`, `.typing` with tired gives `.intent`, `.idle` with `.heart` and tired gives `.happy`, and the existing expectations are unchanged.
- [ ] **Step 2:** Run `scripts/test.sh`. Expect these new tests to fail to compile because the symbols are missing.
- [ ] **Step 3:** Implement `Usage.swift` and the `tired:` parameter.
  - Decode with `JSONSerialization`: `rate_limits.five_hour` and `rate_limits.seven_day`, each with `used_percentage` and `resets_at`. That's tolerant of extra and odd fields.
  - Format times with an `en_US_POSIX` `DateFormatter`: `h:mma` lowercased for the same calendar day in `timeZone`, otherwise `EEE h:mma` with the am/pm marker lowercased.
  - Treat a window whose `resetsAt` is in the past as `used = 0` in `gauge` and `tired`.
- [ ] **Step 4:** Run `scripts/test.sh`. Expect everything to pass (179 + new).
- [ ] **Step 5:** Commit `feat: usage readings, gauges and tired face`.

### Task 3: Wiring the status line into Nell

**Files:**
- Create: `Sources/Nell/Resources/nell-status.sh`
- Modify:
  - `Sources/NellCore/HookServer.swift` (route)
  - `Sources/NellCore/Launch.swift` (`Paths.statusScript`, `hooksSettingsJSON`)
  - `Sources/Nell/KittyController.swift:38-48` (install)
  - `Sources/Nell/AppDelegate.swift:33` (`onStatus`)
  - `Sources/Nell/NellModel.swift` (`usage`, `usageUpdated`, `refresh`, wake)
  - `Package.swift` only if resources are listed one by one
- Test: `Tests/NellCoreTests/HookServerTests.swift`, `Tests/NellCoreTests/LaunchTests.swift`

**Interfaces:**
- Consumes: Task 2's `UsageReading.decode`, `merged`, `nextReset`, `statusLineText`, `tired` and `face(…tired:)`.
- Produces:
  - `HookServer.init(socketPath:registry:onEvent:onRequestSettled:onStatus: @escaping @Sendable (UsageReading) -> Void = { _ in })`;
  - `Paths.statusScript` (`nell-status.sh`);
  - `hooksSettingsJSON(script:statusScript:socket:mode:)`;
  - `NellModel.usage: UsageReading?` (`@Published private(set)`);
  - `NellModel.usageUpdated(_:)`.

- [ ] **Step 1: Write the failing tests:**
  - `statusRouteRepliesWithLineAndReportsReading` (HookServerTests): POST the fixture to `/status` (no `mode` query). The reply body is `statusLineText` of the decoded fixture, `onStatus` gets that reading, and `onEvent` is not called.
  - `statusRouteWithoutLimitsRepliesEmpty`: POST `{"model":{}}`. The reply is empty and `onStatus` is not called.
  - `settingsCarryStatusLine` (LaunchTests): for both modes, `statusLine` is `{"type":"command","command":"'<statusScript>' '<socket>'","padding":0}` (shell-quoted like the hook command), and `hooks` is unchanged.
  - `statusScriptGivesUpQuietly` (LaunchTests): run `Sources/Nell/Resources/nell-status.sh /nonexistent.sock` with the fixture on stdin. It exits 0 with empty stdout in under 1 s.
- [ ] **Step 2:** Run `scripts/test.sh`. Expect the new tests to fail.
- [ ] **Step 3:** Implement.
  - `nell-status.sh <socket>` is essentially `/usr/bin/curl -sf -m 0.3 -H 'Expect:' --unix-socket "$1" --data-binary @- http://nell/status; exit 0`.
  - In `serve`, check `r.path == "/status"` before the mode guard.
  - Install the script next to `nell-hook.sh` with mode 0755.
  - `onStatus` hops to the main actor and calls `model.usageUpdated`. That only assigns `usage` when `merged` differs, and then calls `refresh()`.
  - `refresh()` passes `tired: tired(usage, now:)` to `face`.
  - Include `usage?.nextReset(after: now)` in the wake time that `wakeAtExpiry` schedules, so a passed reset redraws without an event.
- [ ] **Step 4:** Run `scripts/test.sh`. Expect everything to pass.
- [ ] **Step 5:** Commit `feat: status line feeds usage into Nell`.

### Task 4: Gauge chips and showcase

**Files:**
- Modify:
  - `Sources/NellCore/NellBlock.swift` (`usageChips`)
  - `Sources/Nell/PlumNight.swift` (`UsageChip`)
  - `Sources/Nell/CompanionView.swift:71-96` (place chips)
  - `Sources/NellCore/Showcase.swift` (action, visual, scene)
  - `Sources/Nell/ShowcaseRunner.swift` (run and check)
  - `docs/notes/2026-11-14-nell-v3-art-review-log.md` (new round)
- Test: `Tests/NellCoreTests/NellBlockTests.swift`, `Tests/NellCoreTests/ShowcaseTests.swift`

**Interfaces:**
- Consumes: Task 2's `gauge`, `UsageKind` and `UsageLevel`, and Task 3's `NellModel.usage` and `usageUpdated`.
- Produces:
  - `NellBlock.usageChips(_ chip: CGSize, mirrored: Bool) -> (weekly: CGRect, session: CGRect)`;
  - `Showcase.Action.usage(session: Double?, weekly: Double?, resetsIn: TimeInterval)`;
  - `Showcase.Visual.gauge(UsageKind, UsageLevel)`.

- [ ] **Step 1: Write the failing tests:**
  - `usageChipsStackAboveChat` (NellBlockTests): for both `mirrored` values, with a 38×30 chip:
    - `session.maxY == chat.minY - chipGap` and `weekly.maxY == session.minY - chipGap`;
    - all four chips share `minX`;
    - `weekly.minY >= 0`;
    - neither new chip intersects `bar(mirrored:)` or the sprite rect.
  - `showcaseCoversUsageChips` (ShowcaseTests): across all scenes, `.gauge(k, l)` appears for every `UsageKind` × `UsageLevel`. One step shows both `.face(.exhausted)` and `.body(.idle)` after a `.usage` action above 90.
- [ ] **Step 2:** Run `scripts/test.sh`. Expect these to fail.
- [ ] **Step 3:** Implement.
  - `UsageChip(kind:gauge:)` is a non-button Plum Night chip the size of `ModeChip`, with `pixelFrame` on `plum700`. The label is in `muted` Departure Mono. Below it is a `plum900` meter well, filled to `fraction` in `leaf`, `gold` or `berry`. With `fraction == nil` the meter is replaced by a dimmed `–`. Add `.help(gauge.tooltip)` and `.accessibilityLabel(gauge.tooltip)`, then `.interactive()` so hovering works.
  - Place 7D and 5H at `usageChips`, so they mirror with her.
  - Add a `usage` scene. It starts fresh (both `.none`), then steps through 20/30 (low), 60/70 (mid), 85/81 (high), and 95/50 (tired: `.face(.exhausted)` and `.body(.idle)`). Last comes a step with `resetsIn: -60` and session 95 (0%, `.low`, `.face(.idle)`).
  - The runner builds a `UsageReading` with `resetsAt = now + resetsIn` and calls `model.usageUpdated`. It checks `.gauge` against `gauge(model.usage?…, now:)`.
- [ ] **Step 4:** Run `scripts/test.sh`, then `bash scripts/showcase.sh usage`. Expect all tests to pass and no `MISMATCH` lines in the showcase log. Screenshot each step of the showcase copy.
- [ ] **Step 5:** Commit `feat: usage gauge chips above Chat and Code`.
- [ ] **Step 6 (user gate):** Show the user the screenshots of the six states and the tooltip. Record their notes and acceptance as a new round in the art review log, and commit. After they accept, relaunch their Nell from `bash scripts/bundle.sh`, but only once they agree.
