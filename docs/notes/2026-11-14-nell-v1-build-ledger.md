# SDD ledger — plan: docs/plans/2026-11-14-nell-v1-plan.md
Setup: Ruling: repo was not a git repo — git init on main with docs commit 7cadcf5, work on branch nell-v1; repo-local git identity set (none existed) — cost if wrong: author line edit
Setup: Ruling: .gitignore created at setup (adds .impeccable/) instead of in Task 2 — no effect on Task 2 tests
Pre-flight: T2→T4/T5 HookEvent, Mode, Timings, parseHTTPRequest — consistent
Pre-flight: T4→T5/T8/T9 ApprovalAnswer (moved to T4), SessionTracker.inputHeld/settleApproval — consistent
Pre-flight: T3→T6 Paths, claudeArgs, transcriptPath — consistent
Pre-flight: T5→T9 HookServer onRequestSettled; BubbleStore.settle — consistent
Pre-flight: T6→T8/T9 KittyController.send/show/ensureWindow — consistent
Pre-flight: T1→T2/T3/T5/T6 fixtures + response format + socket naming — T1 values override plan values
Task 1: Ruling: spike deviations 1-9 in docs/notes/2026-11-14-pipeline-spike-findings.md bind later tasks (env-match windows via kitty --session, clean env, approval settle via tool_use_id/turn end, AskUserQuestion via PermissionRequest→.none, chat --no-chrome + system prompt, quit via SIGTERM, hook fallback via $KITTY_LISTEN_ON) — cost if wrong: stale bubbles or misrouted text
Task 1: complete (commits 7cadcf5..e4a265b, tests: bash -c 'ls Tests/NellCoreTests/Fixtures/*.json | wc -l' →       14)
Task 2: Ruling: plain `swift test` fails on incremental builds (TestingMacros plugin not found, CLT-only toolchain); all test runs use scripts/test.sh which loads the plugin explicitly — cost if wrong: none, flag is additive
Task 2: Ruling: decodesEveryFixture skips kitty-*.json (not hook events)
Task 2: complete (commits e4a265b..e790bb2, tests: scripts/test.sh → ✔ Test run with 7 tests in 0 suites passed after 0.004 seconds.)
Task 3: Ruling: hook script fallback uses $KITTY_LISTEN_ON + --match env:NELL_MODE=<mode> (resize-os-window show + focus-window) per spike deviations 1,9; chat args add --no-chrome and --append-system-prompt (deviation 5); Paths gains kittySession for the kitty --session file (deviation 1)
Task 3: Ruling: transcript munging maps per UTF-16 unit (matches observed "日本"→"--"; emoji assumed 2 dashes like JS) — cost if wrong: emoji-named folder starts a fresh session instead of resuming
Task 3: complete (commits e790bb2..ef4e036, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh' → PASS permissionRaisesKittyWhenNellDown)
Task 4: Ruling: SessionTracker.handle returns [String] (approval request ids settled by the event: matching tool_use_id via last PreToolUse with same tool_name+tool_input, or turn end on UserPromptSubmit/Stop/StopFailure/SessionEnd) — spike deviation 3; app answers .none to those hanging connections
Task 4: Ruling: AskUserQuestion PermissionRequest never becomes an approval; it sets pendingQuestion (from PreToolUse) and the app answers .none — spike deviation 4
Task 4: Ruling: Notification and SubagentStop (and the question's own PreToolUse/PermissionRequest) don't release holds/questions — a permission Notification arrives ~6s after the prompt
Task 4: Ruling: watchdog never fires while an approval/question is pending (a person may legitimately be away); stale Esc'd approvals clear at the 590s script deadline or the next prompt — deviates from spike note 7 — cost if wrong: needs-you lingers up to ~10 min after an Esc in kitty
Task 4: Ruling: alert is sticky until clearAlert() (app calls it when the alert bubble fades); lastAlert carries the text; shown-once set resets per prompt
Task 4: Ruling: NellState gains .question (plan Task 4 interface already listed it)
Task 4: complete (commits ef4e036..09db603, tests: scripts/test.sh → ✔ Test run with 36 tests in 0 suites passed after 0.011 seconds.)
Task 5: Ruling: ApprovalRegistry API is register(id)/answer(id,_)->Bool/closed(id)/wait(id,timeout)/pendingIds (register before onEvent so an instant answer can't be lost) instead of the plan's open()/Waiter
Task 5: Ruling: Bubble.fadeStart renamed clockStart (start of visible countdown); hover restarts the countdown instead of pausing it (shortcut comment) — cost if wrong: a hovered bubble lingers a little longer
Task 5: Ruling: BubbleStore gains clearStatus(mode:) and settleQuestions(mode:) (needed by Task 9 routing); deny response carries message "Denied from Nell"
Task 5: Ruling: server watches the blocked connection with poll+MSG_PEEK every 200ms to detect the hook script dying → .none
Task 5: complete (commits 09db603..68b28f2, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh' → PASS permissionRaisesKittyWhenNellDown)
Task 6: Ruling: kitty is launched with -c kitty.conf --session kitty.session (code window line with --env NELL_MODE=code); chat window via @ launch --env NELL_MODE=chat; all commands match env:NELL_MODE=<mode>; windowExists(lsJSON:mode:) instead of title: — spike deviation 1
Task 6: Ruling: kitty gets KittyCommands.cleanEnvironment (HOME/USER/LOGNAME/SHELL/LANG/PATH only) — spike deviation 2
Task 6: Ruling: hook script + kitty.conf moved to Sources/Nell/Resources (SwiftPM resources must live in the target); resourceURL() prefers Bundle.main (inside .app) then Bundle.module (swift run); Tests/hook-script-test.sh path updated
Task 6: Ruling: kitty.conf uses hide_window_decorations titlebar-only (not "yes") so the window can still be dragged/resized when shown — cost if wrong: one config line
Task 6: Ruling: KittyController.ensureWindow takes cwd; quit() SIGTERMs kitty's pid parsed from the socket name — spike deviation 8
Task 6: complete (commits 68b28f2..da9804f, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh && swift build' → Build complete! (1.08 secs))
Task 7: Ruling: SwiftUI @State can't be used — its macro plugin ships only with Xcode (CLT has none); view state uses @StateObject/@Published classes (probe: @StateObject/@ObservedObject/@Binding/@FocusState/@Environment/@AppStorage compile fine) — cost if wrong: none
Task 7: Ruling: SpriteSheet.isPlaceholder replaces the inline width check; placeholder caption shown for every state (not just non-typing) — informative while art is pending
Task 7: Ruling: Step 7 eye-check deferred to the user's end-to-end pass (screencapture blocked: no Screen Recording permission); verified programmatically: window layer 1000 (.screenSaver), 320x520, bottom-right 24pt inset on the 1800x1169 display, demo runs without crash
Task 7: Ruling: Open project…/Hide Nell menu items land in Task 8/9 with the real view (demo has Quit only)
Task 7: complete (commits da9804f..94e9a98, tests: bash -c 'scripts/test.sh && swift build' → Build complete! (1.59 secs))
Task 8: Ruling: NellModel (Sources/Nell/NellModel.swift) holds the event routing planned for Task 9 Step 2 — same object the view binds to; Task 9 only wires lifecycle into it
Task 8: Ruling: approval bubble text via new tested NellCore approvalSummary() ("Wants to run `ls`"); a prompt typed in the bar is shown at once and its UserPromptSubmit echo is skipped (sentByNell)
Task 8: Ruling: approvals settled by the tracker (answered in kitty / turn end) are labelled "Answered in terminal" and released with .none without re-showing kitty; question requests are answered .none immediately (spike deviation 4)
Task 8: Ruling: the needs-you sound + auto-unhide run from NellModel.onNeedsYou, set in Task 9's AppDelegate; Step 5 visual check deferred to the user's end-to-end pass (no screen capture permission)
Task 8: complete (commits 94e9a98..749b6e6, tests: bash -c 'scripts/test.sh && swift build' → Build complete! (1.86 secs))
Task 9: Ruling: Info.plist lives in scripts/ (a plist inside the SwiftPM resources dir would be copied as a resource); resourceURL checks Bundle.main.resourceURL/<name> first
Task 9: Ruling: added EventLog (Application Support/Nell/nell.log, reset past 1 MB) — one line per hook event and settlement; needed to verify end-to-end without screen capture
Task 9: Ruling: ensureRunning returns reused:Bool and markLaunched takes modes, so a crash-relaunch onto a live kitty (no new SessionStart) and Open project (code only) don't raise false "disconnected"
Task 9: Ruling: --demo mode dropped; the real app run is the check
Task 9: Ruling: NellModel.refresh publishes `shown` only when it changes (ShownBubble: Equatable)
Task 9: E2E (Claude-run): kitty+2 env-tagged windows launched ✓; code+chat SessionStart reach nell.sock ✓; chat prompt→reply→Stop ✓; approval → bubble → user clicked Allow (log "settled allow") → command ran ✓; kill -9 Nell → kitty survives, relaunch reuses it (1 kitty) and hooks reach new Nell ✓; ~/.claude/settings.json mtime unchanged (1794652445) ✓; steady CPU 0.1%, footprint 21 MB ✓
Task 9: E2E left for the user (no screen capture): Deny / Open terminal buttons, multi-line prompt typed in the bar, click-through + full-screen + drag + right-click menu + ⌥⌘N, fresh untrusted folder via Open project…, lid close / display unplug
Task 9: complete (commits 749b6e6..ae7c259, tests: bash -c 'scripts/test.sh && bash Tests/hook-script-test.sh && swift build' → Build complete! (1.25 secs))
Final: fixed Critical backslash escaping in send-text — sendTextPipesTextOnStdinSoNoEscapesApply RED→GREEN, live check C:\tmp\new \e \x41 a\\b arrived intact, suite 79/79
Final: fixed Important 1 bar not held before SessionStart — heldUntilSessionStartAfterLaunch RED→GREEN (+ send() queues text when ensureWindow relaunches claude), suite 79/79
Final: fixed Important 2 unrelated events released hold/question — unrelatedEventsKeepHoldAfterOpenTerminal, unrelatedEventsKeepQuestion RED→GREEN, suite 79/79
Final: fixed Important 3 pending approval could fade/vanish — hoveredPendingApprovalStays, pendingApprovalSurvivesNewerBubbles RED→GREEN, suite 79/79
Final: fixed Important 4 kitty reuse trusted pid alone — pickKittySocketSkipsDeadPids (isLive path+pid) RED→GREEN; controller requires `kitten @ ls` success and unlinks stale sockets, suite 79/79
Final: fixed Important 5 >1MB hook bodies dropped (curl Expect: 100-continue) — hookScriptDeliversHugeBodyQuickly RED→GREEN, suite 79/79
Final: fixed Important 6 single PreToolUse slot — permissionMatchedWithTwoOpenPreToolUses RED→GREEN, suite 79/79
Final: fixed Important 7 old SessionEnd marked new session connected — sessionEndDoesNotCountAsConnected RED→GREEN, suite 79/79
Final: fixed Important 8 held bar silent/forever — holdExpiresAfterSilence RED→GREEN + bar placeholder "Waiting — answer in the terminal first", suite 79/79
Final: fixed Important 9 saved session id never followed live session — sessionStartRecordsSessionId RED→GREEN + NellModel saves it on SessionStart, suite 79/79
Final: Ruling: old test heldAfterNoneSettleUntilNextEvent renamed/adjusted — with an unknown tool_use_id the hold now ends only at turn end or 180s silence, not on any event — cost if wrong: bar waits up to 3 min after a prompt answered in kitty when the tool id couldn't be matched
Final: minor (deferred): PermissionRequest after Stop dropped by tracker but still bubbled
Final: minor (deferred): dismissed question bubble stays pinned until its PostToolUse/turn end
Final: minor (deferred): HookServer ignores write() result (click in 200ms after script death shows "Allowed")
Final: minor (deferred): undecodable PermissionRequest gets empty 200 (skips script fallback)
Final: minor (deferred): peer watcher may poll fd after close; stop() fd unsynchronised
Final: minor (deferred): second Nell instance steals nell.sock
Final: minor (deferred): no read timeout; each pending approval holds 2 threads
Final: minor (deferred): hook script install is remove-then-copy (not atomic)
Final: minor (deferred): onNeedsYou only on body transition (2nd approval while hidden doesn't unhide)
Final: minor (deferred): sentByNell grows when a send yields no UserPromptSubmit
Final: minor (deferred): ApprovalRegistry.done never pruned
Final: minor (deferred): with Nell down every Notification (incl. idle) raises kitty
Final: minor (deferred): hook-script test lives at Tests/ (case-insensitive FS made tests/ == Tests/)
