# SDD ledger — plan: docs/plans/2026-11-14-nell-v2-console-plan.md
Setup: branch nell-v2 cut from nell-v1 at e066921's parent chain; spec docs/specs/2026-11-14-nell-v2-console-design.md
Pre-flight: T2→T3/T6 ConsolePhase, Layout — consistent
Pre-flight: T3→T5 PanelCalibration (Codable) → SavedState.calibration; KittyCommands panel builders — consistent
Pre-flight: T3 deletes v1 builders (launchKitty/sessionFile/launchWindow) still used by KittyController until T5 — Ruling: keep them until Task 5 rewrites the controller, delete there — cost if wrong: none
Pre-flight: T4 replaces isInteractive(_:rects:) still called by PanelController until T6 — Ruling: T4 updates that call site to the new signature with grabRects: [] / optionHeld: false so the app builds; T6 wires the real values — cost if wrong: none
Pre-flight: T3 BubbleKind.consoleNeeded → T6 NellModel/CompanionView — consistent (views use default branches)
Task 1: Ruling: first window tagged with kitty `-o env=NELL_MODE=code` (not a /usr/bin/env wrapper, which kitty can't see) — cost if wrong: none, verified
Task 1: Ruling: kitty font_size 16.5 pt (3× Departure Mono's pixel grid on 2× Retina) after user asked for "a little bigger" than 11 — cost if wrong: one config value; Nell's own UI stays 11 pt until the Task 7 look
Task 1: Ruling: font licence is public/assets/LICENSE (SIL OFL 1.1), saved as fonts/OFL.txt; repo root LICENSE is MIT for site code
Task 1: complete (commits e066921..8e84ff8, tests: bash -c 'test -s Sources/Nell/Resources/fonts/DepartureMono-Regular.otf && grep -q "SIL OPEN FONT" Sources/Nell/Resources/fonts/OFL.txt && echo font-and-licence-present' → font-and-licence-present)
Task 2: Ruling: console/minimised frames are nil when the free strip beside Nell is under 1 pt wide (never overlap instead of a sliver) — cost if wrong: no console on absurdly narrow screens
Task 2: complete (commits 8e84ff8..3325c50, tests: scripts/test.sh → ✔ Test run with 87 tests in 0 suites passed after 0.368 seconds.)
Task 3: Ruling: panelRequest takes the display's full frame (not just screenTop) so margin-left is display-relative; returns a PanelRequest struct instead of a tuple — cost if wrong: none
Task 3: Ruling: launchPanel puts claude as the panel command directly with -o env=NELL_MODE=code (Task 1 finding), not a /usr/bin/env wrapper
Task 3: Ruling: ConsoleState.minimise() also resets tab to code (Chat's tab is only for its one-time trust prompt); v1 KittyCommands builders kept until Task 5 per pre-flight
Task 3: complete (commits 3325c50..1a80bf5, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh' → PASS notificationDoesNotRaiseKitty)
Task 4: Ruling: removed isInteractiveOnlyInsideRects (old signature) — its cases now live in buttonsAlwaysInteractive; PanelController passes grabRects: [] until Task 6 (pre-flight)
Task 4: complete (commits 1a80bf5..cec21e3, tests: bash -c 'scripts/test.sh && swift build' → Build complete! (1.41 secs))
Task 5: Ruling: v1 KittyCommands show/hide/toggle/closeWindow/launchKitty/sessionFile/launchWindow and Paths.kittySession removed with their tests (replaced by panel builders); focus kept with a new focusUsesEnvMatch test
Task 5: Ruling: showConsole returns the measured calibration (caller stores it in SavedState and re-places) instead of mutating state itself — keeps the controller free of save timing
Task 5: Ruling: NellModel call sites temporarily mapped show→showConsole / toggle→showConsole and ensureWindow→ensureTab; Task 6 replaces them with the click-only console flow
Task 5: Ruling: panel process gets stdout/stderr = /dev/null (a pipe kept a test script hung in Task 1)
Task 5: Live: after launch and after prompting both tabs, kitty pid had 0 on-screen windows; SessionStart/Stop for both modes in nell.log; tabs: 1=code (project), 2=chat (Nell/chat). Hidden panel reports 700x420 (requested size) — calibration must be measured after show, as planned
Task 5: complete (commits cec21e3..87caef0, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh && swift build' → Build complete! (2.16 secs))
Task 6: Ruling: while minimised, Code status bubbles also skip the column (spec: "the status line lives in the minimised bubble"); model publishes codeStatus for it
Task 6: Ruling: the disconnected banner from v1 is replaced by .consoleNeeded bubbles ("Claude needs you in the console" / "Chat needs a one-time OK"); SessionStart settles them; "Answer in the console" bubble added when an approval settles with no decision
Task 6: Ruling: Hide Nell minimises an open console first (otherwise kitty would stay on screen alone) — cost if wrong: console reappears minimised, one click to reopen
Task 6: Ruling: NellCore.Layout qualified in the app target (SwiftUI has its own Layout protocol)
Task 6: Ruling: fixed sizes — Nell block 230x200, column 270x320, minimised bubble 340x30; console cell measured from Departure Mono 16.5 pt; chrome = 3 pt border + 24 pt title strip
Task 6: Ruling: plain bubbles pass clicks through and report hover via HoverRectsKey; chat replies (scrollable) and bubbles with buttons take clicks; drag keeps the sprite solid until mouse-up even if ⌥ is released
Task 6: Live: Nell window at x1508 y95 282x532 (bottom-right, layer 1000); kitty 0 windows on screen; both SessionStarts logged
Task 6: complete (commits 87caef0..4e19b75, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh && swift build' → Build complete! (2.02 secs))
Task 7: Shell: kill -9 Nell → relaunch reuses kitty (one instance: pid 70284 + its __watch_conf__ helper), panel hidden (0 on screen), chat prompt → Stop logged by the new Nell
Task 7: User checklist 2026-11-14 — all eight items passed ("All good"): ⌘ from Chat opens console left + typing; ⌘ minimises/one-line bubble reopens; console open hides Code chatter, approval still shows and Allow works; ⌥-drag to bottom-left re-places console on her right, facing it; click-through without ⌥; ⌥-right-click menu; fonts OK (console 16.5 pt, bubbles 11 pt); no overlap at corners/top
Task 7: Not verified: a second display (none available)
