# Codebase review fixes: build ledger (2026-11-15)

Every ruling, review result, fix round and deferred minor from fixing the full codebase review. Packages P1–P3 were built in parallel isolated worktrees and merged into `review-fixes`; P4 followed; then a whole-branch review, a red team on the fixes, and the final fix rounds. Copied from the working ledger with agent ids removed.


Source: docs/notes/2026-11-15-codebase-review-findings.md (red-team-confirmed). Evidence: .superpowers/review/2026-11-15-full/. Branch review-fixes from main@751ecc7 (docs 22544f6).

## Pre-flight
| Tasks | Shared | Found |
|---|---|---|
| T1 ↔ T2 | SIGPIPE (T1 listening socket, T2 process-wide ignore); LaunchTests | Split as planned; T2 adds no tests to LaunchTests. |
| T1 ↔ T3 | Timings.swift (T1 deletes approvalScriptDeadline; T3 uses typingWatchdog) | T1 owns Timings; T3 only reads it. |
| T2 ↔ T4 | AppDelegate.swift (T2 launch section; T4 panel/hide/pause) | T4 runs after the merge. |
| T3 → T4 | NellModel.dismissQuestion (C2) | T4 adds only the button. |
| T3 ↔ T4 | NellModel.swift | T4 after merge. |
- Ruling: T1–T3 run in parallel isolated worktrees and are merged into review-fixes in order T1, T2, T3; conflicts resolved by the controller only where purely textual, else sent back — cost if wrong: a merge round.
- Ruling: B9 left as a documented known limitation (red team: near-impossible trigger, persisting kitty's pid adds state) — cost if wrong: an orphaned kitty after deleting the support folder mid-run.

## Tasks
T1 (IPC), T2 (kitty), T3 (state): dispatched in parallel isolated worktrees, BASE 22544f6.
T3: implementer DONE 5d3d0ea on the P3 worktree branch (233 tests). Ruling: when a hold ends by the watchdog (no event), queued text goes back into the bar's draft instead of being sent — the 180 s silence is a guess and the permission prompt may still be open; sending with Enter could answer it unattended (review focus 2; red team C's safer variant). Holds ended by an event still flush. Cost if wrong: the user re-sends one message by hand.
T2: implementer DONE d9a170c on the P2 worktree branch (220 tests; based on 22544f6). Follow-ups flagged: NellModel marks only one mode launched after a mid-run restart; failed restart → message to dead socket; launch now alerts+quits if kitty doesn't answer in 5 s (behaviour change to check); nell-hook.sh env match (P1).
T1: implementer DONE 182a7cd on the P1 worktree branch (234 tests, hook-script 7/7; based on 22544f6). Flagged: listen backlog 16 → ECONNREFUSED in bursts (and start()'s liveness check would see a refusing live socket as stale); 2 s timeout per read not per request; a second instance refused at start() still saves its stale state.json on quit (AppDelegate).
T3 review: Needs fixes. I1 tick flush sends text+Enter unattended (ruling applies, with conditions); I2 dismissQuestion flushes into a possibly-open picker; I3 (pre-existing) finalized guard drops PermissionRequest → no hold while a prompt is open.
Ruling: I3 enters the T3 fix round — never drop a PermissionRequest under the finalized guard (a blocking hook means a live prompt; review focus 2) — cost if wrong: a nil-id hold for 180 s after a late request from a dead process.
Ruling: I2 uses the same back-to-draft path as the watchdog — nothing confirms the picker closed — cost if wrong: one manual re-send.
T3: minor (deferred): M1 empty lastAssistantMessage → blank error bubble; M2 --no-run matched on whole command / other build-only flags; M3 alert after interrupt counts as running; M4 SessionEnd settles the disconnected nudge; M5 /clear not a turn end; M7 Timings.oopsBeat/doneBeat dead (P1's file).
T3: fix round 1 implemented e6d39e3 (237 tests).
T2 review: Approved; B3 re-verified in a throwaway kitten panel. Important (NellModel, outside T2): restart triggered by a Chat send doesn't mark Code launched; failed restart → message lost. → carried into T4's brief.
Ruling: regrade Minor 3 (5 s launch cap → alert+quit) to Important — a login item quitting at a slow cold login is severe and the fix is one number (≈30 s; the loop exits as soon as kitty answers) — none if wrong.
Ruling: T2 fix round also takes Minor 4 (SIGTERM a stuck-but-alive kitty pid before restarting), 6 (discard tab-switching, ⌘H/⌘M, command palette), 7 (re-show the panel after a restart if it was shown), 8 (match the spawned pid's socket) — small, in T2's files, close real gaps.
T2: minor (deferred): 5 Cancel on a temporarily-missing folder forgets project and Code session (explicit user choice). 9 nell-hook.sh env match → T1's fix round.
T3: fix round 1/5 (3 addressed, 1 new Important — returnQueueToBar merges into the draft and switches mode while the user types in the other mode → one Enter sends both to the wrong Claude; commits 5d3d0ea..e6d39e3)
T3: minor (deferred): removeUser may remove an older identical delivered bubble (queued bubble usually faded already; cosmetic).
T3: fix round 2 implemented c0f5783 (238 tests).
T2: fix round implemented 4064b78 (220 tests).
T3: fix round 2/5 (1 addressed, 0 open — returned text per mode; commits e6d39e3..c0f5783)
T3: complete (commits 751ecc7..c0f5783 on the P3 worktree branch, review clean)
T2: fix round 1/5 (5 addressed, 1 new Important — mid-session restart blocks main actor up to 30 s per retry; commits d9a170c..4064b78)
T1 review: Needs fixes. Important: (1) 2 s timeout is per read — a trickling client holds a thread+fd forever (~245 exhaust the 256-fd limit); (2) backlog 16 + "connect refused = stale" — a busy live Nell returns ECONNREFUSED; a second instance stole a live socket in 1/~25 races.
Ruling: Important 2's root fix is the flock'd lock file (the only way to tell live from stale, race-free), not only SOMAXCONN — do both now (user: resolve the main issue, don't bypass) — cost if wrong: one extra file in the support folder.
Ruling: T1 round also takes Minor 1 (old two-argument settings: jq fallback only where jq exists, so running sessions keep working after upgrade), Minor 4 (O_NOCTTY), and T2-review Minor 9 (nell-hook.sh matches the var tag, not env).
T1: minor (deferred): Thread.start failure leaks the fd silently (unreachable under the 256-fd limit); chmod/listen failure leaves fd open until stop().
Carry to T4: a second instance refused with alreadyRunning still saves its stale state.json on quit (AppDelegate) — take the instance lock before loading state / skip the save.
T2: fix round 2 implemented 73d8f35 (220 tests).
T2: fix round 2/5 (1 addressed, 0 open — 5 s mid-session restart + 30 s cooldown + proc_pidpath check; commits 4064b78..73d8f35)
T2: minor (deferred): isKitty hardcodes "/Applications/kitty.app/" instead of deriving from KittyCommands.kitty.
T2: complete (commits 22544f6..73d8f35 on the P2 worktree branch, review clean). The silent drop of a send while kitty is down is carried to T4 (NellModel: hold or report it).
T1: fix round implemented 297bfaa (237 tests, hook-script 9/9).
Merged T2 and T3 into review-fixes: 239 tests pass, swift build green.
T1: fix round 1/5 re-review: 1,2,3,5 addressed; 4 "not addressed in effect" only because T1's branch lacks T2's var tagging. Ruling: finding 4 is satisfied in the merged tree (T2 adds --var nell_mode / set-user-vars) — verified by grep after the merge — none if wrong (checked).
T1: minor (deferred → final wave): a failed start() after taking the lock leaves it held, and stop() could then unlink a pre-lock Nell's socket (latent: the app never calls stop() after a failed start).
T1: complete (commits 22544f6..297bfaa on the P1 worktree branch, review clean after merge check)
Merged T1 into review-fixes: 257 tests, hook-script all PASS, swift build green. HEAD 5c292e8. T4: dispatched in the main checkout, BASE 5c292e8.
T4: (main checkout).
T4: implementer DONE 760186e, 083ba2a (265 tests). Showcase: 3 MISMATCH in the usage scene's 'reset passed' step — Usage.merged keeps the older window when the new reading resets earlier (from 539971e); → final wave. Limit: 3+ pinned bubbles can still outgrow the column (shortcut note).
T4 review: Approved. Minors (→ final wave triage): parked bubbles keep fading (a reply can fade unseen while 2+ pinned fill the column); one error bubble per failed send; error wording when launchTab failed with kitty up; T1 decision untested in NellCore; runner "beyond" check can pass trivially; pre-existing: hidden + second approval doesn't bring her back (onNeedsYou fires only on change); ⌘C on a selected reply unverified (.accessory app, no Edit menu).
T4: complete (commits 5c292e8..083ba2a, review clean)
Final review: With fixes — I1 opening the console never restarts a dead kitty; I2 Dismiss label can unlock the bar while a picker is open. Red team on fixes: B1 incomplete (unenterable folder still quits), A7 /tmp/nt-* still left, S2 oldest-match regression (misbind → text+Enter into an open prompt), new: fd-pressure ls failure kills a live kitty; other-mode returned text vanishes from view. Pre-existing found: usage reset reading ignored (showcase MISMATCH).
Final: Ruling: one fix wave = final-wave-brief.md items 1–18 (both reports' Important items, the red team's BROKEN/new items, and the cheap real minors incl. pre-existing usage merge and hidden+second approval) — the user asked to resolve root causes rather than defer — cost if wrong: a larger wave to review.
Final: Ruling: S2 root fix is "never settle an approval from a PostToolUse unless the match was unambiguous" — neither oldest nor newest is reliable without a tool_use_id in PermissionRequest — cost if wrong: ambiguous approvals wait for their own hook to settle.
Final fix wave: DONE 3367a94 ac2bd9d a819178 8bf408d (283 tests, hook-script pass, usage showcase 0 MISMATCH ×3 loops; /tmp/nt-* cleaned).
Final wave re-review: 15 HOLD, 3 PARTLY. Residuals touching review focus 2/4: (a) openToolUses cleared at turn end → background call straddling Stop/UserPromptSubmit misbinds (proofTurnBoundaryStraddleMisbinds fails; pre-existing, narrowed); (b) AskUserQuestion after Stop: PreToolUse guard returns before pendingQuestion is set → bar not held (proofQuestionAfterStopHolds fails; pre-existing); (c) item 3 retry overwrites state.codeSessionId (Important).
Final: Ruling: one more targeted round on (a)(b)(c) plus item-1's ordering (openTerminal answers .none before knowing the console can open) and give-back alert dedupe — the user asked for root causes resolved, overriding the skill's single-wave cap; each is small and on review focus 2/4 — cost: one more scoped re-review.
Final: minor (deferred): remaining harmless kitty shortcuts (load_config_file, debug_config, hints, unicode_input, set_tab_title, cmd+` cycle OS windows, next_layout, start_resizing_window); usage showcase scene no longer exercises merged (unit test pins it); no 👍 for an approval answered in kitty after Stop; identical-error dedupe ignores fade state; KittenWontRun at launch quits (fd pressure at launch).
Final targeted round: 9e58737 (288 tests, hook-script 9/9).
Targeted round re-review: a, b, d, e HOLD; c PARTLY (re-picking the same folder via Open project → restartCode wipes codeSessionId). Out of scope but focus 2 (proved in simulator, premise unverified live): Stop's settleAll hands a pending approval to kitty with .none and NO hold; turnEnds clears a pending question — both let the next bar text go into an open background-agent prompt.
Final: Ruling: one last narrow round — the root is "a turn end is assumed to close every open prompt"; when Stop/UserPromptSubmit settles or clears a prompt that was still open, leave a hold (watchdog → text back to the bar) instead of releasing the bar; restartCode keeps the session when the folder is unchanged; codeAway recomputed on kitty reuse — cost: the bar may stay held up to 180 s after a turn that ended with a prompt open.
Last narrow round: 1763589 (291 tests, hook-script 9/9).
Last round re-review: item 2 HOLDS; item 3 BROKEN in effect (codeAway computed from the folder after the picker replaced it — doesn't detect a reused Code sitting in the fallback); item 1 PARTLY + new Important: Stop now leaves a silent ≥180 s hold after every approval DENIED in kitty (spike fact 3: answering in kitty doesn't close the hook, so a kitty-denied approval is still pending at Stop) — a common path.
Final: Ruling (breaker): revert item 1's Stop/StopFailure hold. Spike fact 3 (pipeline spike) says turn ends are how approvals answered in kitty settle, and the main agent can't reach Stop while its own prompt or question is open; the background-agent-prompt-across-Stop premise has never been observed and the hold costs every kitty-denied approval a silent 180 s. Recorded as a known limitation instead — cost if wrong: a background agent's still-open prompt could receive one bar message after a main-turn end.
Final: Ruling: item 3 gets its root fix — on kitty reuse, set codeAway from the Code window's actual cwd in `kitten @ ls` (already fetched) vs the usable project folder — cost: none.
Breaker round: ef6de67 (290 tests; Stop hold reverted, codeAway from ls cwd).
Breaker round re-review: Clean.
Final verification: 290 tests, hook-script 9/9, swift build green, full showcase cycle 0 MISMATCH / 0 STALL, no /tmp/nt-* left.
