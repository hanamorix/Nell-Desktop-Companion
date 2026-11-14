# Nell — Desktop Companion for Claude

Date: 2026-11-14 · Status: approved 2026-11-14 · Plan: `docs/superpowers/plans/2026-11-14-nell-v1.md`

## Intent

Nell is a personal daily companion that replaces the Claude App for day-to-day use. The Claude App works well but takes up too much screen. Nell is a small animated pixel-art character who sits on the desktop. You chat with Claude and drive Claude Code through her, and she shows what Claude is doing through her animations and speech bubbles.

Nell is for one person on one Mac. She isn't a product to distribute.

## Goals

- A floating character on the desktop with no window frame, which can be dragged and stays on top. Clicks on empty space pass through to the windows behind her.
- **Two modes**, switched with two small buttons under her desk:
  - **💬 Chat:** a general conversation with Claude.
  - **⌘ Code:** Claude Code working on the current project. The full session is visible in a kitty terminal window.
- **iMessage-style message bar** under Nell. The newest messages float up from her and older ones fade away. The full history lives in kitty.
- **Speech bubbles** show replies, a short live summary of the work in progress, alerts and approval requests, from both modes, including the mode you aren't looking at.
- **Animations for each state:** idle, typing/working, needs approval, failure, alert, done (see the state table).
- **Approvals from the bubble:** Allow and Deny buttons, so you don't need to open kitty.

## Non-goals (v1)

- Syncing with claude.ai history, Projects or memory. Chat conversations start fresh.
- Several Claude Code projects or sessions at once. Nell follows one project at a time.
- Windows or Linux; App Store, notarization or distribution.
- Embedding kitty inside Nell's window (kitty can't be embedded).
- Summaries written by a separate model call. Bubbles use Claude's own text and tool activity.
- Following Claude Code sessions that Nell didn't start, such as the Claude App's Code tab or a `claude` you run yourself.

## Anti-goals (failure even if it "works")

- Nell blocks clicks or gets in the way of other windows.
- An approval gets lost: Claude waits without telling anyone, because Nell missed it or crashed.
- Nell changes the user's global `~/.claude/settings.json` or affects other Claude Code sessions.
- She gets heavy or cluttered. If she feels like a second Claude App, she has failed.

## Constraints

- macOS (Darwin 27.x). kitty is at `/Applications/kitty.app` and isn't on PATH. The `claude` CLI is at `~/.local/bin/claude` and is logged in with the user's subscription. Both modes run on the subscription, with no API key.
- Claude Code hooks are the way Nell gets state. Hooks can block and return an approval decision (`PermissionRequest` → `decision.behavior: allow|deny`, or `PreToolUse` → `permissionDecision`). The default hook timeout is 600s. Docs: https://code.claude.com/docs/en/hooks
- Two programs writing to one Claude session at the same time isn't documented as safe. The design keeps a single writer: the `claude` process running in kitty.
- kitty is controlled only through remote control (`kitten @` over a unix socket). Docs: https://sw.kovidgoyal.net/kitty/remote-control/

## Approaches considered

1. **Native macOS app in Swift (picked).** It uses a borderless, transparent window that stays on top, clicks pass through except over Nell and her bubbles, and nearest-neighbour scaling keeps the pixel art sharp. It's the lightest option (roughly 20–40 MB). Trade-offs: Mac only, and Swift is less familiar to tweak than web code. It was picked because Nell is personal and Mac-only, and her whole point is to be light and stay out of the way.
2. **Tauri web overlay.** CSS makes bubbles and fades easy. Rejected because transparent windows and partial click-through are fiddly on macOS, and it's heavier than native.
3. **Fork clawd-on-desk** (an existing Electron pet with hooks and Allow/Deny cards). It's the fastest start. Rejected because Electron is heavy (150 MB or more), and the fading chat, Chat mode and kitty control would all still need building inside someone else's codebase.

**Who runs the Claude session** (a second, separate choice; my call):

- **Claude runs in kitty and Nell listens through hooks (picked).** There's one writer per session. Typing in kitty and typing in Nell's bar go to the same conversation, and kitty always shows everything. Trade-offs:
  - replies arrive whole when Claude finishes, rather than streaming in;
  - Nell's typing is sent to kitty as keystrokes, so it has to wait while a prompt is open.
- **Nell runs the session herself through the Agent SDK, and kitty only shows a transcript.** Replies would stream into Nell's bubbles and input would be clean. Rejected because kitty would become read-only, and you asked for a terminal you can work in.

## Architecture

```
┌────────── Nell.app (Swift, no Dock icon) ──────────┐
│  floating overlay: sprite · bubbles · bar · 💬/⌘   │
│  hook server on unix socket nell.sock ◄────────────┼── Claude Code hook scripts
│  kitty controller (kitten @ over unix socket) ─────┼──► kitty instance owned by Nell
└────────────────────────────────────────────────────┘      ├─ OS window "code": claude (in project dir)
                                                            └─ OS window "chat": claude (tools off)
```

- **Claude runs inside kitty, always.** Nell starts one dedicated kitty instance with remote control locked to its socket (`allow_remote_control=socket-only`, `--listen-on unix:…`) and its own small config (no title bar). That instance has two OS windows, *code* and *chat*. Both start hidden.
- **What you type in Nell's bar is sent to kitty.** `kitten @ send-text --match id:<win>` types the text into the selected mode's `claude` window, followed by Enter. You can also type straight into kitty, since it's the same session.
- **Hooks only exist in Nell's sessions.** Nell launches each `claude` with `--settings <nell-hooks-<mode>.json>`, which registers hook scripts that pass the event to Nell's fixed Unix socket (`http://nell/hook?mode=code|chat` via `curl --unix-socket`). See "Hooks are small command scripts" below for what happens when Nell can't be reached. The global settings are never touched, and sessions Nell didn't start never reach her.
- **Chat mode** is `claude` started in a neutral folder such as `~/Library/Application Support/Nell/chat`, with the built-in tools off (`--tools ""`). By default it would still load your plugins, MCP servers and their injected instructions. So Chat also gets `--strict-mcp-config` (no MCP servers) and `--setting-sources` limited so that user plugins and hooks aren't loaded, while `--settings` still adds Nell's hooks *(my call; check that plugins really drop out)*. `--bare` and `--safe-mode` aren't usable: `--bare` ignores the subscription login, and `--safe-mode` turns off hooks.
- **Code mode** is `claude` in the current project folder. Nell gives each new session its own ID when she starts it (`claude --session-id <uuid>`) and saves it in a small state file with the project folder. On launch she resumes that exact session with `claude --resume <id>`. She never uses `--continue`, because that could pick up a session someone else started. If her saved session is gone, she starts a fresh one. Chat mode keeps its own session ID the same way. Right-click Nell → "Open project…" picks a folder and starts a new code session there. *(my call)*
- **Lifecycle** *(my call)*:
  - Nell is a login item.
  - Quitting Nell on purpose closes her kitty instance. Both sessions are saved and resume on the next launch.
  - If Nell crashes, kitty keeps running. On relaunch Nell reconnects to the existing socket instead of starting a new kitty.
- **Hooks are small command scripts, not raw HTTP hooks** *(my call)*:
  - Each hook script sends the event to Nell's local server.
  - If Nell can't be reached, a `PermissionRequest` or `Notification` script instead uses `kitten @` to show and focus the right kitty window, then returns no decision. Claude Code then asks in a terminal you can see.
  - This keeps a crash from hiding an approval.
- **⌘ button:** the first click switches the bar to Code. Clicking ⌘ again while it's already selected shows or hides the kitty code window next to Nell. 💬 works the same way for Chat; its kitty window rarely needs showing.

## Hook → state → bubble mapping

| Hook event | Nell animation | Bubble |
|---|---|---|
| (local) you type in the bar | listening | — |
| `UserPromptSubmit` | thinking | your message goes into the faded history |
| `PreToolUse` | typing (working) | live summary, e.g. "Editing auth.ts", "Running `npm test`", "Reading 3 files" |
| `PermissionRequest` (**blocking**) | needs-you | "Wants to run `npm test`" with **Allow / Deny / Open terminal** |
| `PostToolUseFailure` | oops (short, then back to typing) | "`npm test` failed" |
| `Notification` | alert | the notification text |
| `Stop` | done (short happy beat, then idle) | `last_assistant_message`, cut to about 3 lines plus "…more in ⌘" |
| `StopFailure` | error | the error, briefly |
| no events for N minutes | idle → sleepy | — |

Bubbles from the mode you aren't looking at carry a small 💬 or ⌘ badge.

**Which mode drives Nell's body** *(my call)*: needs-you from either mode wins. Next come error and alert from either mode. After that, the selected mode's state decides.

**Approvals:** the `PermissionRequest` hook script waits on Nell until you click.
- **Allow** or **Deny** returns that decision.
- **Open terminal** returns no decision, so Claude Code shows its own prompt in kitty, and Nell brings that window forward.
- **No answer:** if Nell hasn't answered within the script's own deadline (set a little under the hook timeout), the script does the same thing as when Nell is unreachable. It shows and focuses the kitty window, returns no decision, and Nell turns the bubble into "Answer in terminal". So an approval bubble never stays clickable after it has stopped working.

Nell keeps the needs-you animation going until the approval is settled.

**The message bar holds input while Claude is waiting on a prompt** *(my call)*. Text typed into kitty would answer an open permission prompt, question picker or trust dialog instead of becoming a new message. So while Nell knows a prompt is open (`PermissionRequest`, or a `PreToolUse` for the question tool), the bar queues what you type and sends it once the prompt is settled. Nothing is trusted ahead of time, because that would mean writing to `~/.claude.json`. The first time Nell opens any folder, including the Chat folder, the "hooks not connected" state shows kitty after 8 s so you can accept the trust dialog there.

**Chat replies are shown in full** *(my call)*. In Chat the reply is the point, so the latest reply bubble shows the whole `last_assistant_message`, scrolls if it's long, and only then starts to fade. Code-mode replies are cut to about 3 lines plus "…more in ⌘". Replies appear all at once when Claude finishes rather than streaming in, which is the cost of keeping Claude in kitty (see Approaches).

## Fading chat

- **One stack and one text field** (layout A from the mockups). Your messages (blue, right-aligned), Claude's replies, the live work-status bubble and approvals all share a single column rising from Nell's head. The newest is at the bottom, nearest her. The text field with the 💬/⌘ chips sits under her desk. Only the visible bubbles, Nell and the bar take clicks; everything else passes through.
- At most about 4 bubbles are visible, stacked upward from Nell. Each older one is more transparent.
- A bubble fades out completely after a while. The full history is always in kitty.
- Approval bubbles never fade until they're answered.

## Character art

- Nell is from the user's concept: a chibi girl in a dark cat-ear hoodie and round glasses, with long brown hair and pink eyes, sitting at a small desk with a laptop that has a cat logo. The final art is **pixel art**.
- Each state from the table gets its own looping frame strip: idle, listening, thinking, typing, needs-you, oops, alert, done, sleepy, error. Strips are exported from Aseprite as a sprite sheet with JSON frame data, and drawn with nearest-neighbour scaling at a whole-number zoom.
- The art is a separate track, so the app and the art can move forward independently. The concept is at `art/concept/nell-typing-4frames.png`:
  - four frames of about 390×390 px each, in a 1560×438 strip with captions underneath;
  - smooth illustrations on a checkerboard that's baked into the image, so it isn't real transparency;
  - not pixel art yet.
  
  Until the pixel art exists, the app uses these frames as the typing loop with smooth scaling and a cropped background, plus simple placeholders for the other states. Nearest-neighbour scaling starts once the real sprite sheets arrive. *(my call)*

## Lessons from existing companions

Taken from a survey of about 30 projects and about 630 GitHub issues: [reports/Claude companion apps landscape.md](../../../reports/Claude%20companion%20apps%20landscape.md). These apply on top of the sections above. *(my call to include them; they come from bugs other companions shipped)*

- **The hook address never changes.** Nell's server listens on a fixed Unix socket in App Support, which hook scripts reach with `curl --unix-socket`. The address can't be a port picked at launch, because a `claude` that outlives a Nell crash keeps the address baked into its `--settings`.
- **Hook scripts** use only system tools, call `kitten` by its full path, and give up quietly within 0.5 s for events that don't block.
- **Each approval bubble is tied to its own request.** It closes as soon as that request is settled in any way, including being answered in kitty. Dismissing the bubble or quitting Nell counts as no decision, never as Deny.
- **Duplicate prompts are dropped.** A permission `Notification` that arrives while a `PermissionRequest` is pending is ignored. An idle-waiting notification is shown at most once.
- **State rules:**
  - After `Stop`, `StopFailure` or `SessionEnd`, nothing changes until the next `UserPromptSubmit`. A `PostToolUse` that arrives late is ignored. `SubagentStop` doesn't count as done.
  - `PostToolUse` moves Nell from typing back to thinking.
  - If no events arrive for a few minutes, a watchdog drops Nell from typing to idle.
- **Claude's questions (`AskUserQuestion`) get their own bubble.** It shows the question text and an "Answer in terminal" button, never Allow/Deny, and it ranks above permission requests.
- **Missing hooks are visible.** If no `SessionStart` arrives within a few seconds of launching `claude`, Nell shows a "hooks not connected" state.
- **Focus:** only the message bar can take keyboard focus, and only when you click it or press the summon hotkey. Bubbles never take focus.
- **Window:** a non-activating `NSPanel` that is visible in every Space (`canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`, `hidesOnDeactivate = false`). Click-through comes from hit-testing transparent pixels. Level `.screenSaver`, so **Nell stays visible over full-screen apps** (the user's decision). "Hide Nell" covers videos and similar. Verify that this works as a borderless panel on Darwin 27.
- **Right-click menu:** Open project…, **Hide Nell** (she comes back on her own at the next needs-you), and **Quit**.
- **Position:** remembered for each display, and Nell is pulled back on screen if a display disappears.
- **Energy:** Nell redraws only when the frame changes, at about 6–12 fps. She stops animating when sleepy, and pauses while the screen is locked or the display is asleep.
- **Bubble fading:** done and error bubbles start their fade only once you're active again (system idle time). Hovering over a bubble pauses its fade.
- **Sound:** one soft sound for needs-you only, skipped when kitty is already in front.
- **A global hotkey** shows Nell and focuses the bar. It must not clash with shell keys.

Ruled out for Nell, with the reasons in the report:
- other agents;
- several sessions at once;
- approvals from a phone;
- quota rings;
- global Allow/Deny hotkeys;
- skins and the Codex Pets format;
- XP/stats;
- following sessions Nell didn't start.

## Verified vs. not yet verified

Verified on this Mac on 2026-11-14 with `claude --help` and `kitten @ send-text --help`:
- `claude` flags: `--settings` (loads *additional* settings), `--session-id <uuid>`, `--resume <id>`, `--tools ""` (turns off all built-in tools), `--strict-mcp-config`, `--setting-sources`. Also that `--bare` ignores the subscription login and `--safe-mode` turns off hooks.
- `kitten @ send-text` with `--match id:N` and `--bracketed-paste enable|auto`.

Taken from docs and research but not tested here:
- the exact `PermissionRequest` input and output schema;
- the `UserPromptSubmit` and `Notification` payload fields;
- that hooks added through `--settings` combine with, rather than replace, other hooks;
- that `--setting-sources` drops user plugins in Chat.

**The first job of the plan:** show that `send-text` submits a prompt into `claude` running in kitty, and that the matching hooks reach Nell's server. That includes one Allow/Deny round trip. Everything else depends on it.

## Left to the builder

- Swift structure (SwiftUI vs AppKit for the overlay), the HTTP server library or a hand-written one, and the project layout.
- The exact CLI flags: how to turn off all tools for Chat mode, and checking that `--settings` stacks hook config on top of the user's own settings. Verify against `claude --help` and the hooks docs before building on them.
- Multi-line input to the kitty TUI (for example, the bracketed-paste option of `send-text`).
- How to place the kitty window next to Nell (kitty launch geometry, or the macOS accessibility API).
- Summary templates for each tool in the `PreToolUse` bubble.
- Timings: fade duration, how long before sleepy, how long the happy beat lasts.
- Nell's on-screen size, as a whole-number zoom of the sprite.
