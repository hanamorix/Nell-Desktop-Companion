# Full codebase review: findings (2026-11-15)

**Method:** the user asked for a full review using Superpowers, red teaming, and ponytail, and said to resolve root causes, never cover them up, and always verify. At main@751ecc7:
- Four independent reviewers read every line of one slice each:
  - **A:** hook/status IPC and trust boundaries.
  - **B:** kitty, processes, persistence and scripts.
  - **C:** session state, reactions and the model.
  - **D:** interface, panel, sprite and showcase.
- Each finding was then handed to a separate red team that tried to disprove it, using:
  - scratch harnesses built from the real sources;
  - a throwaway kitty (never Nell's);
  - scratch AppKit programs;
  - fresh proof tests.

Only confirmed findings are listed below.

Final severity is the red team's grade. "Live" marks the few things that can only be confirmed on the desktop.

## Confirmed: Critical and Important

| ID | Severity | Finding | Root fix (as verified by the red team) |
|---|---|---|---|
| B1 | Critical | A saved project folder that no longer exists (renamed, or on an unmounted drive at login) makes every launch fail with "couldn't start kitty" and quit. Recovery means editing state.json by hand. | Check `projectDir` exists and is a directory when it's read at launch. If not, ask again; never let a working-directory failure end the app. |
| RA-N1 | Important | A client that hangs up before Nell replies kills Nell with SIGPIPE. `SO_NOSIGPIPE` set on an accepted socket whose peer has already gone fails with EINVAL, and nothing ignores SIGPIPE. Reproduced at rc=141. | Set `SO_NOSIGPIPE` on the listening socket, which accepted sockets inherit, and ignore SIGPIPE process-wide at app start. |
| S1/A | Important | `nell-hook.sh` uses `/usr/bin/jq`, which exists only from macOS 15 on. The package targets macOS 14, so every approval is lost there. | Pass the event name to the script as an argument (`hooksSettingsJSON` already loops per event) and drop jq. |
| B2 | Important | Nell never recovers if her kitty dies, for example from ⌘Q or from closing the last tab. `kitten panel` overrides `macos_quit_when_last_window_closed` to yes. Bubbles then lead nowhere and sends vanish. | When `ls` fails, clear the socket and run `ensureRunning` again. Treat `launchTab` as successful only on exit 0. Stop the console's own shortcuts from quitting or closing her kitty. |
| B3 | Important | kitty's default shortcuts still work in the console. A ⌘T or ⌘↩ shell inherits `env NELL_MODE=code`, and `send-text --match env:` sends to every match, so Nell's prompts get pasted into a shell, which runs them. | Tag only the window Nell launches, using a per-window user var that new windows don't inherit, and match on that. Unmap the window-management shortcuts in Nell's kitty. |
| D1 | Important | Clicking Allow, Deny, the Chat chip, the console title strip or a reply makes the panel key, taking the keyboard from the app in front. | Make taking the keyboard opt-in: only the message bar and selectable reply bubbles report key rects. `clickTakesKeyboard = keyRects.contains`. Live check needed: the red team saw AppKit make a non-activating panel key through another route (S-D1b). |
| D2 | Important | A pending approval can be clipped out of the bubble column, leaving only about 1 pt of Allow/Deny visible (measured with the real views). | Fit the column by height with pinned rows first (a pure NellCore function behind a SwiftUI `Layout`). Rows that don't fit aren't placed. |
| D3 | Important | With the console open, a hidden, clipped Allow can be clicked in space that looks empty above the column. This was reproduced: `answer(allow)` fired. | D2's fitting, plus reported rects clipped to the column frame. |
| N1/C | Important | After the 590 s deadline hand-off, the input hold expires on the next tick, because its clock starts at the last event. The next bar message is then sent with Enter into a possibly open permission prompt. (Live: what Enter does in that dialog.) | Time the hold from when it starts (`settleApproval(…, now:)`), and clear it only when both the silence and its own age reach the watchdog. |
| C1 | Important | Text queued during a console hand-off is never sent after the hold expires, and every later message queues behind it. | After N1, flush the queue in `NellModel.tick` once a hold has ended. |
| C3 | Important (question half) | Question bubbles, and stale "Answer in the console" bubbles, stay pinned after the turn ends. | Settle questions and console-needed bubbles on every turn end (UserPromptSubmit, Stop, StopFailure, SessionEnd). Move that routing into NellCore so it can be tested. |

## Confirmed: Minor

| ID | Finding | Root fix |
|---|---|---|
| A1 | JSON nested 298+ levels deep (objects) crashes the server on a 512 KB worker stack. This affects `/hook` and `/status`, so it needs a hostile local process. | Serve each connection on a thread with a 4 MB stack, paired with A4's timeout. |
| A2 + S3 | `transcript_path` from the socket is opened blocking on the main thread. A FIFO hangs Nell; `/dev/zero` read 2.4 GB in 2 s. | In `ContextMeter.tail`, open with `O_NONBLOCK`, `fstat` and require a regular file, and read with a byte limit. |
| A3 | One byte after a PermissionRequest spins a CPU core until the approval settles. | Consume the byte with `recv` (no peek); zero or less means the peer closed. |
| A4 | About 64 idle connections starve every hook, and when they close the queued work dies of RA-N1. | `SO_RCVTIMEO` of about 2 s. |
| A5 | Flushing two or more queued messages during a relaunch sends them out of order. | Pass each released message back through `submit(held:)`. |
| A6 / C11 | Dead code: `ApprovalRegistry.done`, `pendingIds`, `Timings.approvalScriptDeadline`, a redundant `if let`, the done/oops transient, `.listening`, and `bodyState`'s unused ranking. (`hold.since` is now used by N1.) | Delete it. |
| A7 | Gaps on the trust boundary: no tests for Content-Length edge cases or a missing `mode`, nothing checks what the hook script prints after Allow or Deny, and 927 leftover `/tmp/nt-*` directories. | Add the tests and clean up the temp directories. |
| A8 / B11 / B4 | EventLog trims itself only at launch, logs raw newlines, and uses the deprecated `FileHandle.write`. `runTool` uses the same API, which crashes on a broken pipe. | Rotate inside `write`, escape newlines, and use `write(contentsOf:)` / `seekToEnd()`. |
| Ledger | `reply`'s `write` result is ignored, so Allow is shown even when it never reached Claude. | Check the result and report `.none` on failure. |
| Ledger | A second instance's `stop()` deletes the first instance's live socket. | In `start()`, connect first and refuse with "already running" instead of unlinking. |
| S2/A | Parallel identical tool calls are matched to the newest open use. | Clear `openToolUses` at turn end, then match the oldest. |
| B5 | A state.json without `positions` loads as blank state, then gets saved over. | Custom `init(from:)` with `decodeIfPresent ?? default`. |
| B6 | `quit()` SIGTERMs a pid that may have been reused. | Kill only if `ls` still answers (B2's clearing covers most cases). |
| B7 | A missing `claude` gets no clear message. | Check that it's executable at launch and fail with a clear message. |
| B8 | Cancelling the first-run picker saves `~` as the Code project folder. | Leave it unset (the chat folder is the working directory), ask again, and remove the force-unwrap at AppDelegate:51. |
| B10 / D5 | `restore` looks up the position by `NSScreen.main` but saves under `screens.first`. | Use `screen` in `restore`. |
| B12 | `chatChipLeavesConsoleAlone` can't fail. | Delete it. |
| B13 | `bundle.sh` runs `rm -rf` on any argument. | Require a `*.app` path. |
| B14 | `stress.sh` has no trap, and a crash gives no FAIL row. | Add an EXIT/INT/TERM trap and record crashes as FAIL. |
| C2 | Esc on an AskUserQuestion holds the bar and ❓ until you type in kitty. A timer was rejected, per v1 ruling line 21. | A Dismiss control on the question bubble. |
| C4 | A relaunched Claude inherits the dead process's question, test run and hold. | A startup/resume SessionStart counts as a turn end. |
| C5 | After CONSOLE, Claude's own permission notification shows ❗. | Suppress it while a hold is active. |
| C6 | An alert during the oops beat leaves her typing for good. | Delete the transient (failure goes to thinking, Stop goes to idle). |
| C7 | A compact SessionStart mid-turn makes her stop typing. | Don't go idle on `compact`. |
| C8 | After an Esc interrupt during a tool she keeps typing for up to 3 min and shows "failed". | On `isInterrupt`, go idle without finalizing (finalizing would drop approvals that come later), and skip the failed bubble. |
| C9 | `test && lint` lint failures show 😢, `--no-run` shows ❤️, and exit 127 shows 😢. | After `&&`, judge failure from the summary only. No reaction for 126/127 or build-only runs. |
| C10 | The StopFailure bubble shows the raw error code. | Use `lastAssistantMessage ?? error`. |
| S3/C | A denied test keeps her yawning until Stop. | Drop the test id when its approval is denied. |
| D4 | After a drag that turns her, she reappears 64 pt off on the next launch. | Save the origin after the relayout that follows the drag. |
| D6 | While hidden she keeps animating, and some redraws ignore the pause. | Pause while hidden, guard `redraw()`, and stop and restart the timers. |
| D7 | The 10 Hz poll lets a click within 100 ms of moving go to the wrong window. | D1 removes the keyboard half. The click-through half is graded with D1's live check. |
| D8 | VoiceOver isn't told about the chips' news dot. | `accessibilityValue`. |
| D9 | Layout tests use the v2 sizes. | Add tests with the real block and cell sizes and a screen whose origin isn't zero. |
| Zero screen | `layout(.zero)` gives a null frame, and `setFrame` throws on it. | Guard against a missing screen in relayout. |

## Not fixed, with reasons

- **B9: orphaned kitty after the support folder is deleted while Nell runs.** The red team graded it "arguably won't-fix": persisting kitty's pid adds state for a near-impossible trigger. It's recorded here as a known limitation.
- **Suspicions left unproven:**
  - the clean environment drops `SSH_AUTH_SOCK`;
  - symlinked or long project paths;
  - Dock moves;
  - fast user switching;
  - the SessionEnd relaunch race;
  - a 10 s `kitten` hang on a stuck kitty.

  Each needs live evidence before a change.

## Outcome (fixed on branch `review-fixes`)

Every confirmed finding above is fixed at its root. Each fix has a test that failed before it, except where the code lives in the app target. Those app-target fixes have a stated desktop check instead.

Process:
- Each package had its own review and fix rounds.
- A whole-branch Opus review and a red team on the fixes found further gaps.
- Those gaps were fixed in a final wave and four narrow rounds, each re-reviewed.

Every ruling is in [2026-11-15-review-fixes-build-ledger.md](2026-11-15-review-fixes-build-ledger.md).

**Final state:**
- 290 tests pass.
- The hook-script tests pass 9/9.
- `swift build` is green.
- The tests leave no temp folders.

**Found and fixed during the fixing** (not in the original review):
- **Holds and queued text:** a hold that ends by timeout returns queued text to the bar, filed under its own mode, instead of sending it.
- **Approvals arriving after Stop:** they are tracked instead of dropped.
- **Ambiguous approvals:** these are two identical calls open at once. They never bind to a guessed call, and they settle only through their own hook.
- **A dead kitty:**
  - Opening the console restarts it.
  - Restarts wait 5 s mid-session and retry at most every 30 s.
  - A failed spawn never kills a live kitty.
- **The instance lock:**
  - An `flock`'d lock file means a busy Nell is never taken for a stale one.
  - A refused second instance never saves `state.json`.
- **Kitty can't enter the project folder:**
  - Code starts in the chat folder instead of quitting.
  - The project's session id is never overwritten.
- **Usage chips:** a reading after a reset is no longer ignored (a pre-existing usage-chips bug).
- **Showing her again and fading bubbles:**
  - She comes back for every new prompt while hidden.
  - Parked bubbles don't fade unseen.

**Known limitations** (each was decided deliberately; the reasons are in the ledger):
- **A background agent's prompt still open when the main agent's turn ends** isn't held. It's never been observed. Holding it would leave a silent 3-minute "Waiting…" after every approval you deny in the console, because answering in kitty doesn't close the hook (pipeline spike fact 3).
- **Text typed after a hold has timed out** sends at once. This is the 3-minute release that v1 accepted.
- **Three or more pinned bubbles below her** can clip the oldest approval's buttons. The hidden part isn't clickable, and it can be answered once a newer one settles, or at the 590 s hand-off.
- **An identical approval stays ambiguous after one is denied in the console:** the next identical approval answered in the console settles through its own hook, not its Post, until Claude restarts. This affects comfort only, not safety.
- **Still to check on the desktop:**
  - **S-D1b:** whether AppKit makes the panel key again after it was key once.
  - **⌘C on a selected reply:** whether it copies in an app with no Edit menu.
  - **What Enter does in Claude's open pickers.**
- **Minor leftovers listed in the ledger:**
  - some harmless kitty shortcuts;
  - the usage showcase scene no longer exercising `merged` (a unit test pins it);
  - `isKitty` hard-coding the kitty.app path.
