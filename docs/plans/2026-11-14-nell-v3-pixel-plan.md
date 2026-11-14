# Nell v3 Pixel Design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Art tasks (6–9) are review-gated with the user, not test-gated.** Use the `hana-pixel:image-to-animated-pixel-art` skill and the Aseprite MCP for them.

**Goal:** Give Nell her real look. That means a Plum Night pixel-art interface, plus a 128 px animated sprite at her desk whose body, face and emoji reactions follow Claude.

**Architecture:**
- **Pure logic in `NellCore`, tested:** recognising test commands and their results, the reaction queue, the body state and face choice, the context meter, the animation scheduler (blinks, resting frames, in-betweens), and parsing Aseprite slices and layers.
- **App glue in `Nell`:** Plum Night styles, `PixelFrame`, and a `SpriteCompositor` view that draws body, then face, then blink, then props, then emoji.
- **Art in `artwork/sprites/*.aseprite`,** exported to `Sources/Nell/Resources/sprites/`.

**Tech Stack:** Swift 6.4 with the Command Line Tools only (`scripts/test.sh`, no SwiftUI `@State`), Aseprite through the Aseprite MCP, the hana-pixel skill, and Departure Mono.

**Spec:** `docs/specs/2026-11-14-nell-v3-pixel-design.md`. Also read `concept-nell-design-system/README.md` and its `components/*/README.md` (the visual spec), and `docs/notes/2026-11-14-design-system-review-findings.md`.

**Branch:** `nell-v3` from `main`.

## Global Constraints

- The sprite canvas is **128 × 128**, drawn at exactly **2×** with nearest-neighbour scaling, so 256 pt on screen. No smoothing, no fractional scaling and no anti-aliasing anywhere.
- Animation runs at 6–12 fps and only redraws when a frame changes.
- **Long quiet:** after 600 s with no events, breathing stops on a resting frame and blinks slow to every 8–15 s. Animation pauses entirely while the screen is locked or the display is asleep. v2's inactivity `sleepy` state is removed.
- **Body loops:** `idle`, `typing`, `yawning`, `sleeping`.
- **Faces:** `idle`, `intent`, `exhausted`, `happy`, `smile`, `sad`, `scared`. Use `awe` instead of `scared` if the user prefers it while iterating.
- **Emoji:** `heart`, `thumbsup`, `crying`, `warning`, `question`, `alert`, `plug`.
  - Only one shows at a time, in priority order warning > question > plug > alert > crying > heart > thumbsup.
  - Brief ones last 2.5 s. warning, question and plug stay until resolved.
- **Faces only change behind a blink** that shares one eye position and closed-eye patch across all faces.
- **Body changes** wait for the next of a loop's 2 resting frames, then play the drawn in-between. Pairs: idle↔typing, typing→yawning, yawning→typing, idle or typing→sleeping, sleeping→idle.
- **Paper stacks** = min(5, context tokens ÷ 100 000), from the Code session only. They reset on `SessionStart` with `source: clear` and on `PreCompact`/`PostCompact`.
- **Test reactions** come from the Code session only. If the command is piped or the result is unclear, there's **no reaction**.
- **Plum Night is the visual spec.** Your own bubbles are cream (`cream` fill, `snow` top edge, `outline` ink). No `cornerRadius`; notched pixel corners only. Interface text is Departure Mono at 11 pt (22 pt for titles), and the console uses 16.5 pt.
- **Wording:** "Open console", "Answer in the console". Labels are uppercase and one or two words. No emoji in interface text; use the pixel icons.
- **Art source files:** the user's expression library lives outside the repo. **Open only the folders the user names; never its private ones.**
- **Never ship art the user hasn't accepted.** Each accepted piece is recorded in `docs/notes/2026-11-14-nell-v3-art-review-log.md`.

## Review Focus

1. **A test command piped through `| tail` or `| grep`:** no ❤️ or 😢, ever. Covered by `pipedTestCommandGivesNoReaction` in Task 2.
2. **A burst of events,** such as several tools finishing in the same second, or an approval arriving during a heart: only the highest-priority emoji shows, and brief ones don't stack up into a queue. Covered by `burstKeepsHighestPriority` in Task 3.
3. **A face change requested mid-blink, or two changes in quick succession:** the face never changes while the eyes are open, and the last request wins. Covered by `faceSwapsOnlyBehindBlink` and `latestFaceRequestWins` in Task 4.
4. **`/clear` or compaction while the paper stacks are showing:** the stacks drop to 0 straight away and climb back as context grows. Covered by `contextResetsOnClearAndCompaction` in Task 3.
5. **Nell left alone for an hour:** CPU near zero, a still sprite apart from slow blinks, and an instant resume on the next event. Covered by `quietStopsBreathingAndSlowsBlinks` in Task 4 and the Task 10 CPU check.

---

### Task 1: Signal spike (gate for sleeping, paper stacks and test reactions)

**Files:**
- Create: `docs/notes/2026-11-14-nell-v3-signal-spike-findings.md`
- Create: `Tests/NellCoreTests/Fixtures/PostToolUse-Bash-testpass.json`, `PostToolUseFailure-Bash-testfail.json`, `transcript-usage.jsonl`, plus a usage-limit fixture if one is found.

- [ ] **Step 1: Test results.** Reuse the v1 spike's logging server (`server.py` from the scratchpad, or rewrite it). In a scratch project with one passing and one failing test (`python3 -m unittest`, so there are no dependencies), ask Claude to run each test, then the failing one piped through `| tail -5`. Record:
  - which event fires on a non-zero exit;
  - the `tool_response` fields (stdout, stderr, interrupted, any exit code);
  - what the piped run reports.
- [ ] **Step 2: Context.** Read the session transcript (`transcript_path` from any event). Record where the last assistant entry's `usage` sits (`input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `output_tokens`). Run `/clear` and then `/compact` and record the events and the `SessionStart.source` values.
- [ ] **Step 3: Usage limits.** Search the Claude Code docs and changelog for how a rate or usage limit reaches hooks (`StopFailure` error text, `Notification` type, or the status-line `rate_limits` JSON). A limit can't safely be triggered on demand, so record the documented shape. If the docs give none, record "deferred" for sleeping.
- [ ] **Step 4:** Write the findings, add the fixtures (with paths scrubbed), add the notes doc to `docs/README.md`, and commit `spike: v3 signals (test results, context usage, usage limits)`. **If both the context signal and the limit signal are missing, stop and report to the user.**

### Task 2: Test commands and results

**Files:**
- Create: `Sources/NellCore/TestRuns.swift`
- Modify: `Sources/NellCore/HookEvent.swift` (add `toolResponse: JSONValue?` from `tool_response`, and `source: String?` from `source`)
- Test: `Tests/NellCoreTests/TestRunsTests.swift`

**Interfaces:**
- Produces:
  - `public enum TestOutcome: Equatable, Sendable { case pass, fail }`
  - `public func isTestCommand(_ command: String) -> Bool`. It uses the spec's list (npm/pnpm/yarn/bun/deno test, `npm run test`, pytest, `python -m pytest`, swift/cargo/go/mix/gradle/mvn/make test, jest, vitest, rspec, `*test*.sh` scripts), matched as whole words at the start of the command or after `&&`, `;` or `cd …&&`.
  - `public func isPiped(_ command: String) -> Bool`. It's true for a `|` outside quotes; `||` doesn't count.
  - `public func testOutcome(_ e: HookEvent) -> TestOutcome?`. It returns nil unless the event is a Bash `PostToolUse` or `PostToolUseFailure` for a test command. If the command is piped, it decides only from the runner's summary line in the output, and returns nil if there isn't one. Otherwise it uses the event and exit status the Task 1 spike found, and the summary line whenever one is present. Summary patterns:
    - pytest `N passed` / `N failed`
    - jest/vitest `Tests: … failed` / `Tests: … passed`
    - Swift Testing `✔ Test run … passed` / `✘ Test run … failed`
    - cargo `test result: ok.` / `FAILED`
    - go `^ok\s` / `^FAIL`
    - unittest `OK` / `FAILED (`

- [ ] **Step 1: Write the failing tests.**
  - `recognisesTestCommands`: true for `npm test`, `cd app && pytest -q`, `swift test --filter X` and `scripts/test.sh`; false for `npm install`, `cat test.txt` and `grep test`.
  - `pipeDetectionIgnoresQuotedAndOr`: `pytest | tail` is true; `echo "a|b"` and `pytest || true` are false.
  - `passAndFailFromSpikeFixtures`: uses the Task 1 fixtures.
  - `pipedTestCommandGivesNoReaction`: a piped command whose output has no summary line returns nil; with `2 failed` in the output it returns `.fail`.
  - `nonTestCommandGivesNil`
- [ ] **Step 2:** Run `scripts/test.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `scripts/test.sh`. Expected: everything passes. Commit `feat: test command and result recognition`.

### Task 3: Reactions, body state, faces and the context meter

**Files:**
- Create: `Sources/NellCore/Reactions.swift`, `Sources/NellCore/ContextMeter.swift`
- Modify: `Sources/NellCore/SessionTracker.swift` (remove the `sleepy` transition; add a `usageLimited` flag and a `testRunning` flag)
- Test: `Tests/NellCoreTests/ReactionsTests.swift`, `Tests/NellCoreTests/ContextMeterTests.swift`. Update the `SessionTrackerTests` that use `sleepy`.

**Interfaces:**
- Consumes: `testOutcome`, `isTestCommand` (Task 2); `SessionTracker`; `ApprovalAnswer`.
- Produces:
  - `public enum Body: String, Sendable { case idle, typing, yawning, sleeping }`
  - `public enum Face: String, Sendable { case idle, intent, exhausted, happy, smile, sad, scared }`
  - `public enum Emoji: String, Sendable, Comparable { case warning, question, plug, alert, crying, heart, thumbsup }`. The declaration order is the priority.
  - `public struct ReactionState: Sendable`:
    - `mutating func flash(_ e: Emoji, now: Date)`, for the brief ones (2.5 s);
    - `mutating func setHeld(_ e: Emoji, _ on: Bool)`, for warning, question and plug;
    - `func current(now: Date) -> Emoji?`, the highest held one, else the newest brief one still live.
  - `public func body(code: SessionTracker, chat: SessionTracker, selected: Mode) -> Body`. sleeping if either session is usage-limited, then yawning if a Code test is running, then typing if the selected mode's turn is running, else idle.
  - `public func face(body: Body, emoji: Emoji?) -> Face`. Brief emoji map to faces as in the spec (heart → happy, thumbsup → smile, crying → sad, warning → scared). Otherwise the face follows the body: idle → idle, typing → intent, yawning and sleeping → exhausted.
  - `public struct ContextMeter: Sendable`:
    - `mutating func update(tokens: Int)`, `mutating func reset()`;
    - `var stacks: Int` = min(5, tokens / 100 000);
    - `public static func tokens(fromTranscriptTail data: Data) -> Int?`, which sums the last assistant `usage`'s input, cache-read and cache-creation tokens, using the Task 1 field names.

- [ ] **Step 1: Write the failing tests.**
  - `burstKeepsHighestPriority`: flash heart, then thumbsup, then crying in the same second gives crying. With warning held, the result is warning until it's released, then crying if it's still live.
  - `briefEmojiExpiresAfter2_5s`
  - `heldEmojiStaysUntilReleased`
  - `bodyPriorities`: limited beats test running, which beats a turn running, which beats idle. Also a Chat turn while Code is selected gives idle.
  - `faceFollowsEmojiThenBody`
  - `contextStacksCapAt5`: 0, 99 999, 100 000, 250 000 and 900 000 tokens give 0, 0, 1, 2 and 5 stacks.
  - `contextResetsOnClearAndCompaction`: this is NellModel wiring, so test it as `reset()` giving 0 and the transcript parser reading the fixture.
  - `tokensFromTranscriptFixture`
  - `noSleepyAfterLongIdle`: the v2 600 s rule is gone.
- [ ] **Step 2:** Run `scripts/test.sh`. Expected: FAIL. Then implement. Then `scripts/test.sh` passes. Commit `feat: reactions, body state, faces, context meter`.

### Task 4: Animation scheduler and sprite format

**Files:**
- Create: `Sources/NellCore/Animator.swift`
- Modify: `Sources/NellCore/SpriteSheet.swift`. Parse `meta.slices` (name plus per-frame keys `{frame, bounds}`) and `meta.layers`, and treat `frameTags` named `body:<state>`, `face:<name>`, `between:<from>-<to>`, `eyes:closed`, `paper:<n>` and `emoji:<name>`.
- Test: `Tests/NellCoreTests/AnimatorTests.swift`, `Tests/NellCoreTests/SpriteSheetTests.swift` (add a slice and tag fixture `Fixtures/sprite-v3-sample.json`)

**Interfaces:**
- Produces:
  - `SpriteSheet` gains:
    - `slices: [String: [Int: CGRect]]`, slice name → frame → bounds, keyed by the frame each key starts at;
    - `func slice(_ name: String, frame: Int) -> CGRect?`, using the latest key at or before that frame;
    - `func tag(_ name: String) -> ClosedRange<Int>?`;
    - `restingFrames(body:)`, the frames carrying user data `rest` in Aseprite. Tag user data is exported as `data`.
  - `public struct Animator: Sendable` with:
    - `init(sheet: SpriteSheet, seed: UInt64)`
    - `mutating func request(body: Body, face: Face, now: Date)`
    - `mutating func tick(now: Date, quiet: Bool) -> Frame?`, which returns nil when nothing changed
    - `public struct Frame: Equatable { body: Int; face: Int; faceAt: CGRect; eyesClosed: Bool }`

**Rules** (from Global Constraints):
- **Blinks:** every 3–6 s, or every 8–15 s when `quiet`. Each lasts 120 ms. The seeded random generator makes the tests deterministic.
- **Face changes** are applied only while `eyesClosed`. If a change is pending and no blink is due, a blink is started straight away.
- **Body changes** wait for the next resting frame, play `between:<from>-<to>` if it exists, then start the new loop.
- **Quiet:** the body holds its resting frame.

- [ ] **Step 1: Write the failing tests.**
  - `parsesSlicesWithPerFrameKeys`
  - `restingFramesFromTagData`
  - `faceSwapsOnlyBehindBlink`
  - `latestFaceRequestWins`
  - `bodyChangeWaitsForRestingFrameThenInBetween`
  - `missingInBetweenCutsAtRestingFrame`
  - `quietStopsBreathingAndSlowsBlinks`
  - `tickReturnsNilWhenNothingChanges`
- [ ] **Step 2:** Run `scripts/test.sh`. Expected: FAIL. Then implement. Then `scripts/test.sh` passes. Commit `feat: animation scheduler, sprite slices and tags`.

### Task 5: Plum Night interface

**Files:**
- Create: `Sources/Nell/PlumNight.swift`, containing colour constants, a `PixelFrame` ViewModifier (outline, notched corners, top edge, bevel, hard drop), `PixelButton` (allow, deny, quiet, default; pressed and disabled states), `ModeChip` and the pixel `Icon` (SVG via `NSImage`, nearest-neighbour).
- Create: `Sources/Nell/Resources/icons/*.svg` (the 8 icons copied from `concept-nell-design-system/assets/Icons/`).
- Modify: `Sources/Nell/CompanionView.swift`, so every bubble kind, the chips, the bar (with a `QUEUED` tag when `barHeld`), the console frame, the minimised strip and the console-needed bubble follow each component's README in `concept-nell-design-system/components/`, with user bubbles in cream. Wording changes.
- Modify: `Sources/Nell/Resources/kitty.conf`, setting `background #1a1214`, `foreground #f5d4c9`, `cursor #ec9394`, `selection_background #3f3039`, and colours 0–15 from the palette.
- Modify: `concept-nell-design-system/`. Replace `licenses/DepartureMono-LICENSE.txt` with the OFL text from `Sources/Nell/Resources/fonts/OFL.txt`, fill in `tokens.json` `type`, record user-bubble = cream, and add the README sections for the three console components.

- [ ] **Step 1:** Run `swift build`. Expected: clean.
- [ ] **Step 2: Render check.** Run `bash scripts/bundle.sh`, open the app, and trigger each bubble kind with `kitten @ send-text` prompts (an approval, a question, a failure, a reply, Chat and Code). Show the user and record their verdict in the art review log. This is a user-reviewed visual task; there's no logic to test.
- [ ] **Step 3:** Commit `feat: Plum Night interface, pixel icons, kitty palette, design system fixes`.

### Task 6: Master sprite (art, review-gated)

**Files:**
- Create: `artwork/sprites/nell-master.aseprite`, with layers chair, body, desk, laptop, head, face, eyes and props, and slices `face`, `eyes`, `emoji` and `paper`.
- Create: `docs/notes/2026-11-14-nell-v3-art-review-log.md` (and add it to `docs/README.md`).

- [ ] **Step 1:** Load the hana-pixel skill. Use the Aseprite MCP's `animation_workflow_guide`. Convert the first frame of `artwork/concept/nell-typing-4frames.png` to a 128 × 128 base, quantised to the Plum Night palette plus hoodie, skin and hair ramps sampled from `nell-pixel-reference.png`.
- [ ] **Step 2:** Clean it into separate layers following the Aseprite server's rules: silhouette, palette, flats, top-left light, a dark outline. Redraw the hands and the laptop pixel by pixel, and run `lint_sprite` with no findings.
- [ ] **Step 3: Review.** Export a 2× PNG on light and dark backgrounds and show it to the user. Iterate until they accept it, and log each round's notes and the final acceptance.
- [ ] **Step 4:** Place the `face`, `eyes`, `emoji` and `paper` slices. Commit `art: master Nell at her desk`.

### Task 7: Faces and the blink transition (art, review-gated)

**Files:**
- Modify: `artwork/sprites/nell-master.aseprite`, adding face tags `face:idle`, `face:intent`, `face:exhausted`, `face:happy`, `face:smile`, `face:sad` and `face:scared`, plus `eyes:closed`.

- [ ] **Step 1:** For each face, convert the matching expression from the user's library at the head size fixed by Task 6, using hana-pixel. Fit it to the shared eye position.
- [ ] **Step 2:** Draw one shared closed-eye patch.
- [ ] **Step 3:** Export a GIF that cycles every face through blinks. Show it to the user, iterate, and log the result. If they prefer `awe` to `scared`, use it.
- [ ] **Step 4:** Commit `art: faces and blink transition`.

### Task 8: Body loops and in-betweens (art, review-gated)

- [ ] **Step 1:** Draw `body:idle` and `body:typing`, each 4–8 frames with breathing and 2 frames marked `rest` in the tag's user data. Review and log them.
- [ ] **Step 2:** Draw `between:idle-typing` and `between:typing-idle`. Review and log them.
- [ ] **Step 3:** Draw `body:yawning` and `between:typing-yawning` / `between:yawning-typing`, then review and log them.
- [ ] **Step 4:** Draw `body:sleeping`, `between:idle-sleeping`, `between:typing-sleeping` and `between:sleeping-idle`. **Skip this step if Task 1 deferred sleeping, and tell the user.** Review and log.
- [ ] **Step 5:** Commit `art: body loops and in-betweens`.

### Task 9: Paper stacks and emoji icons (art, review-gated)

- [ ] **Step 1:** Draw `paper:1` through `paper:5`, growing stacks for the `paper` slice. Skip this if Task 1 deferred context.
- [ ] **Step 2:** Draw the seven 16 × 16 emoji icons as `emoji:<name>` tags, in the Plum Night palette with an outline.
- [ ] **Step 3:** Review, log, and commit `art: paper stacks and emoji`.

### Task 10: Compositor, wiring and export

**Files:**
- Create: `Sources/Nell/SpriteCompositor.swift`. A view that draws, in order: the body frame, the face at `faceAt` (or the closed eyes when `eyesClosed`), the paper stack at the `paper` slice, and the emoji at the `emoji` slice. Everything is at exactly 2× with `.interpolation(.none)`, redrawn only when `Animator.tick` returns a frame.
- Modify:
  - `NellModel`: feed `ReactionState`, `body()`, `face()`, `ContextMeter` and `Animator` from hook events. That means `testOutcome` on Post events, a held warning, question or plug, a 👍 flash on Allow or on a matching `PostToolUse` after the approval was answered in kitty, ❗ on a non-test failure or alert, and context read from the Code session's transcript tail on `Stop`.
  - `AppDelegate`: replace `SpriteView`.
  - `OverlayPanel` `nellSize` → 280 × 300.
- Create: `Sources/Nell/Resources/sprites/nell.json` and `nell.png`, exported from the `.aseprite` file with tags, slices, layers and user data.

- [ ] **Step 1:** Run `scripts/test.sh` and `swift build`. Expected: everything passes and the build is clean.
- [ ] **Step 2: End-to-end with the user.**
  - [ ] Idle and typing switch smoothly.
  - [ ] A passing test gives a heart and a happy face; a failing test gives crying and a sad face; a piped test gives no reaction.
  - [ ] An approval gives a warning and a scared face; Allow gives a thumbs-up and a smile.
  - [ ] Yawning plays during tests.
  - [ ] Paper stacks grow with context and clear on `/clear`.
  - [ ] Every face change happens behind a blink, and no frame visibly pops.
  - [ ] An hour idle leaves CPU at about 0%. Check with `top -pid`.
- [ ] **Step 3:** Commit `feat: sprite compositor and reactions wired`. Write `docs/notes/YYYY-MM-DD-nell-v3-build-ledger.md` and add it to the index.
