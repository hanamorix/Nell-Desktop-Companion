# Codebase review fixes: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** fix every confirmed finding in `docs/notes/2026-11-15-codebase-review-findings.md` at its root cause, each one test-first where a test can pin it.

**Architecture:** four packages, split by the files they own.
- P1 (IPC), P2 (kitty/process) and P3 (session state) touch separate files. They run in parallel worktrees and are merged into `review-fixes`.
- P4 (interface) runs after the merge, because it builds on P3's model changes and shares `AppDelegate` with P2.

**Tech stack:** Swift 6.4 SwiftPM, Command Line Tools only, Swift Testing via `scripts/test.sh`, bash.

**Evidence:** for each finding, the reviewer's and red team's evidence is in `.superpowers/review/2026-11-15-full/` (`findings-{A,B,C,D}.md`, `redteam-{A,B,C,D}.md`). That folder is gitignored scratch, so the findings note above is the durable record. When the two disagree, the red-team verdict wins.

## Global constraints

- **Root causes only.** No guards that hide a symptom, and no catching an error just to drop it. If a root fix turns out to be impossible, stop and report it; don't work around it.
- **Test-first.** For every finding a NellCore test can pin, write the test, watch it fail, then fix. Changes inside the app target that can't be unit-tested need a stated live check in the report.
- **Don't break the user's machine or settings:**
  - Never modify `~/.claude/settings.json` or `~/.claude.json`.
  - Never touch the user's running Nell (`build/Nell.app`) or `~/Library/Application Support/Nell`.
  - Never launch Nell, the showcase or claude.
  - P2 may start its own throwaway kitty (never Nell's) on a `/tmp` socket running `/bin/cat`, and must kill only that kitty's pid.
- **Project rules:** no SwiftUI `@State`. Tests run only through `scripts/test.sh`, and `swift build` must also compile the app target. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Keep the design.** Existing behaviour that the specs require stays as it is (approvals, Auto mode, the bar under her desk, themes, usage chips and so on).

## Review focus

1. A crash or hang reachable from the socket. Any input must leave the server alive and still answering.
2. Text sent to kitty while a prompt may be open. Never send bar text while an approval, question or hold is active.
3. Focus. Only the message bar and reply text may take the keyboard, and Allow/Deny must still work without it.
4. Nell must still start and recover in every state: a missing folder, a missing claude, a dead kitty, a corrupt or partial `state.json`.
5. An approval that is never hidden, or hidden but still clickable.

---

### Task 1 (P1): IPC and trust boundary

**Owns:**
- `Sources/NellCore/HookServer.swift`, `HTTPRequest.swift`, `ContextMeter.swift`, `ApprovalRegistry.swift`, `Timings.swift`
- `hooksSettingsJSON` in `Launch.swift`
- `Sources/Nell/Resources/nell-hook.sh`
- the tests for these files, including the hook script test

**Findings:**
- **RA-N1:** set `SO_NOSIGPIPE` on the listening socket. P2 adds the process-wide SIGPIPE ignore.
- **A4:** `SO_RCVTIMEO` of about 2 s on each connection.
- **A1:** serve each connection on a `Thread` with a 4 MB stack.
- **A3:** the watcher consumes stray bytes with `recv` instead of peeking.
- **Ledger:** `reply` checks its write result, and a failed Allow or Deny write settles as `.none`. The `reply` and `registry` paths must report `.none` to the settle callback.
- **Ledger:** `start()` refuses with "already running" when a live server answers on the path, and unlinks the socket only if it's stale.
- **A2 + S3:** harden `ContextMeter.tail` to non-blocking, regular files only, with a byte limit.
- **S1:** `hooksSettingsJSON` passes the event name as `$3`, and `nell-hook.sh` drops jq.
- **A6:** delete `ApprovalRegistry.done`, `pendingIds` (update its tests), `Timings.approvalScriptDeadline`, and the redundant `if let`.
- **A7:** add the HTTP edge-case tests (negative, overflowing and huge Content-Length, the 16 KB header cap, the 4 MB cap, a missing or unknown `mode`). Add a hook-script test that strips `PATH` and checks the exact Allow/Deny JSON against a fake server. Have the tests remove their `/tmp/nt-*` directories.

**Tests that pin it:**
- A client that sends Stop and hangs up leaves the server still answering a second request.
- A 510-deep object body on `/hook` and `/status`, followed by Stop, is delivered.
- One trailing byte after a PermissionRequest doesn't spin (measure CPU time, or assert the watcher loop count).
- A second `start()` on a live path throws, and `rebindsOverStaleSocketFile` still passes.
- `tail` of a FIFO and of `/dev/zero` returns nil promptly.
- The settings command includes the event name.
- The script with no jq on `PATH` prints the exact decision JSON.

**Commit:** `fix: harden the hook socket (SIGPIPE, timeouts, stack, socket ownership, transcript reads, no jq)`

### Task 2 (P2): kitty, process control, persistence and scripts

**Owns:**
- `Sources/Nell/KittyController.swift`, `Sources/NellCore/KittyCommands.swift`, `Sources/Nell/Resources/kitty.conf`
- `Sources/Nell/main.swift`, `Sources/Nell/EventLog.swift`
- `Sources/NellCore/SavedState.swift`
- the launch section of `Sources/Nell/AppDelegate.swift` (`applicationDidFinishLaunching` up to the panel setup, `pickFolder`, `fail`)
- `scripts/bundle.sh`, `scripts/stress.sh`
- their tests: KittyCommandsTests, SavedStateTests, ConsoleStateTests, PanelGeometryTests if argv changes. Put no new tests in LaunchTests, because P1 owns it.

**Findings:**
- **B1:** validate `projectDir` at launch. If it's missing, show the picker again. If that is cancelled, leave it nil.
- **B8:** Cancel leaves `projectDir` nil, and AppDelegate:51 stops force-unwrapping it (use `model.cwd(.code)`).
- **B7:** fail with a clear message if `~/.local/bin/claude` isn't executable.
- **B2:**
  - When `ls` fails, clear the socket and re-run `ensureRunning`.
  - `ensureTab` returns true only if `launchTab` exits 0.
  - Check whether `kitten panel`'s forced `macos_quit_when_last_window_closed=yes` can be overridden in the panel's argv. If it can't, make closing the last tab harmless through B3's shortcut unmapping, and say which you did.
- **B3:**
  - Tag the launched Claude windows with a per-window kitty user var. New windows don't inherit it; the red team verified this with `kitten @ launch --var`.
  - Match `var:` instead of `env:` in every `KittyCommands` command.
  - In `kitty.conf`, unmap the window and tab management shortcuts (new tab or window, close tab or window, quit) and keep copy, paste and scroll.
  - Prove it in a throwaway kitty: a second window created inside it doesn't receive `send-text`.
- **B6:** `quit()` kills only if `ls` still answers.
- **B4:** use `try? write(contentsOf:)` in `runTool`, and `signal(SIGPIPE, SIG_IGN)` in `main.swift`.
- **A8/B11:** EventLog rotates inside `write` past 1 MB, escapes newlines, and uses the throwing non-deprecated APIs.
- **B5:** custom `SavedState.init(from:)` with `decodeIfPresent ?? default` for every field. Test with `positions` missing.
- **B12:** delete `chatChipLeavesConsoleAlone`.
- **B13:** `bundle.sh` refuses a path that doesn't end in `.app`.
- **B14:** `stress.sh` gets a trap and records a crash as FAIL.

**Commit:** `fix: kitty recovery, per-window tags, safe launch state, logs and scripts`

### Task 3 (P3): session state and reactions

**Owns:**
- `Sources/NellCore/SessionTracker.swift`, `Reactions.swift`, `TestRuns.swift`, `InputQueue.swift`
- a new `Sources/NellCore/TurnEnd.swift`, if routing moves there
- the event-handling, queue and tick parts of `Sources/Nell/NellModel.swift`
- their tests

**Findings:**
- **N1:** the hold records its own start (`settleApproval(_:answer:now:)`) and clears only when both the silence and its own age reach `typingWatchdog`. Test: a deadline settle at 591 is still held at 592 and released at 591+180.
- **C1:** once a hold has ended, `NellModel.tick` flushes the queue. Pin the rule in NellCore, for example with an `InputQueue`/tracker helper that reports "release now".
- **A5:** `flushQueue` passes each released message back through `submit(held:)`.
- **C3:**
  - Move turn-end bubble routing into a NellCore function that takes the event, the tracker result and the `BubbleStore`.
  - On UserPromptSubmit, Stop, StopFailure and SessionEnd, settle questions and console-needed bubbles.
  - Test it.
- **C2:** add `SessionTracker.dismissQuestion()` (clears `pendingQuestion`) and a `NellModel` method that calls it and settles that question's bubble. P4 adds the button.
- **C4:** a SessionStart with `startup` or `resume` counts as a turn end.
- **C5:** suppress the duplicate permission notification while a hold is active.
- **C6/C11:** delete the transient and the done/oops beats (failure goes to thinking, Stop goes to idle). Delete `.listening`. Reduce `bodyState` to which of needs-you or question applies, keeping the chime on a needs-you → question change. Keep `hold.since`. Update the tests the red team listed.
- **C7:** `compact` doesn't go idle.
- **C8:** on `isInterrupt`, go idle without finalizing, and skip the "failed" status bubble.
- **S2:** clear `openToolUses` at turn end, then match the oldest unclaimed tool use first. Test with two identical Bash calls.
- **S3:** a denied approval drops its tool use from `testIds`.
- **C9:**
  - When `&&` follows the test, a failure counts only if the summary shows one.
  - Exit codes 126/127 and build-only flags (`--no-run`, `--no-run`-style) get no reaction.
- **C10:** the bubble text is `lastAssistantMessage ?? error ?? "Something went wrong"`. Update FinalFixTests:95.

**Commit:** `fix: holds timed from their start, queued text released, pinned bubbles settle at turn end, tracker clean-up`

### Task 4 (P4): interface and panel (after P1–P3 are merged)

**Owns:**
- `Sources/Nell/CompanionView.swift`, `OverlayPanel.swift`, `PlumNight.swift`, `SpriteCompositor.swift`
- `Sources/NellCore/NellBlock.swift`, a new `Sources/NellCore/BubbleFit.swift`
- the panel, hide/show and pause parts of `AppDelegate.swift`
- their tests, plus LayoutTests

**Findings:**
- **D1:**
  - Opt-in keyboard: a key-rects preference reported only by `MessageBar` and selectable reply bubbles. `clickTakesKeyboard(p) = keyRects.contains(p)`.
  - Delete `passiveRects` and the sprite special case.
  - Test: false for button, chip, title strip and empty points; true for the bar and a reply.
- **D2/D3:**
  - `fitRows(heights:pinned:budget:spacing:) -> [Bool]` in NellCore, with pinned rows placed first and then the newest others while they fit.
  - A SwiftUI `Layout` uses it. Unplaced rows aren't drawn and report no rects.
  - Reported rects are clipped to the column frame.
  - Test: a pinned approval plus three tall bubbles keeps the approval.
- **C2 (UI):** a Dismiss button on the question bubble calls P3's model method.
- **D4:** save the origin after the relayout that follows a drag. Test the NellCore part: the relaunch position is unchanged.
- **D5/B10:** `restore` uses `screen`.
- **D6:** pause while hidden (at the hide/show call sites), guard `redraw()`, and stop and restart the timers while paused.
- **D7:** after D1 the keyboard half is gone. Keep the poll unless a monitor-based approach is proven not to need extra permissions; if you keep it, say why.
- **D8:** `accessibilityValue` for the news dot.
- **D9:** layout tests with `NellBlock.size`, the real column and cell sizes, all console phases, and a screen whose origin isn't zero.
- **Zero screen:** with no screen, relayout keeps the last layout.

**Then:**
- Run the showcase sandboxed and take screenshots of the approval plus tall-bubbles case.
- The user does a manual desktop check covering:
  - S-D1b (type in the bar, click into an editor, click Nell, type);
  - Allow/Deny keeping your keyboard;
  - ⌘T in the console no longer receiving prompts;
  - recovery after ⌘Q.

**Commit:** `fix: opt-in keyboard, approvals never clipped or clickable when hidden, pause while hidden, layout tests`

### Final

- A whole-branch review: an Opus reviewer, plus a red team on the fix diff.
- One fix wave.
- A build ledger in `docs/notes/`.
- Merge as the user directs, then relaunch and do the live checks.
