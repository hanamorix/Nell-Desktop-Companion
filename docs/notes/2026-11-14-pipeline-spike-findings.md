# Pipeline spike: 2026-11-14

Tested with Claude Code 2.1.321 and kitty 0.50.0 on Darwin 27.3. Sample payloads are in `Tests/NellCoreTests/Fixtures/`, with paths scrubbed. **Every check passed.** The deviations below are binding for Tasks 2–9.

## Confirmed

- **kitty socket:** `--listen-on 'unix:<dir>/kitty-{kitty_pid}.sock'` creates `kitty-<pid>.sock`. Child processes get `KITTY_LISTEN_ON=unix:<path>` in their environment, and so do their hooks.
- **Show and hide:** `@ resize-os-window --match … --action show|hide|toggle-visibility` works on a `--start-as hidden` window and exits with code 0.
- **Prompts:** `@ send-text --bracketed-paste enable -- <text>` followed by `@ send-key enter` submits a prompt. A 3-line prompt with `"$HOME"`, backticks and 😺 arrived as **one** `UserPromptSubmit`, byte-exact.
- **Event fields:**
  - `UserPromptSubmit.prompt`
  - `Stop.last_assistant_message`
  - `SessionStart.source` (`startup`)
  - `Notification.message` and `notification_type` (`permission_prompt` or `idle_prompt`)
  - `PreToolUse` and `PostToolUse` have `tool_name`, `tool_input` and `tool_use_id`. **`PermissionRequest` has `tool_name` and `tool_input` but no `tool_use_id`.**
  - Every event has `session_id`, `prompt_id` and `permission_mode`.
- **Approval response:** `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}` allows. `"behavior":"deny","message":"…"` denies. An empty body leaves Claude's own prompt open in kitty.
- **Hooks are merged:** with `--settings`, the user's plugin `SessionStart` hooks still ran in the Code session.
- **Folder trust:** the trust dialog appears *before* `SessionStart`. Nothing arrives until it's accepted, so the 8 s `disconnected` rule is how Nell detects it.
- **Transcript path:** `~/.claude/projects/<cwd with every non-[A-Za-z0-9] character → "-">/<session>.jsonl`, one `-` per character. For example `chat 日本` becomes `chat---`, and `/x/.claude` becomes `-x--claude`.

## Deviations later tasks must follow

1. **Windows are matched with `--match env:NELL_MODE=<mode>`, not by title.** Claude overwrites the window title. kitty starts with `--session <file>`, where the file contains `launch --env NELL_MODE=code --cwd <dir> <claude…>`. The chat window is `@ launch --type=os-window --keep-focus --env NELL_MODE=chat …`. A window started directly from the kitty command line has no env tag.
2. **kitty runs in a clean environment.** A kitty launched from inside Claude Code inherits `CLAUDECODE`, `CLAUDE_CODE_*` and `ANTHROPIC_BASE_URL`, which turned off transcript saving and redirected API calls. Nell starts kitty with only `HOME`, `USER`, `LOGNAME`, `SHELL`, `LANG` and `PATH`, where PATH is `~/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin`.
3. **Answering in kitty doesn't close the hook connection.** The blocked `curl` stays alive. An approval therefore settles on either:
   - its own connection closing, or
   - a `PostToolUse` or `PostToolUseFailure` whose `tool_use_id` matches the request, or
   - `Stop`, `StopFailure`, `UserPromptSubmit` or `SessionEnd` for that session.

   `PermissionRequest` has no `tool_use_id`, so Nell takes it from the latest `PreToolUse` in the same session with the same `tool_name` and `tool_input`. When an approval settles this way, Nell replies `.none` to the hanging connection so the `curl` process exits.
4. **`AskUserQuestion` arrives as `PreToolUse` and then `PermissionRequest`,** with `tool_input.questions[].question`. Nell replies `.none` straight away, shows a question bubble ("Answer in terminal") and holds input until the next event.
5. **Chat flags:** `--tools "" --strict-mcp-config --no-chrome --setting-sources project`, plus `--append-system-prompt "You are in a plain chat inside Nell, a desktop companion. You have no tools; never write tool-call markup."`.
   - Without `--no-chrome`, the Claude-in-Chrome tools were still loaded.
   - Without the system prompt, Claude wrote fake `<invoke>` markup.
   - With these flags, no `PreToolUse` fired and no plugins or skills loaded.
6. **A late `SubagentStop` arrives about 1 s after `Stop`** on most turns, so `SubagentStop` is ignored as planned. A permission `Notification` arrives about 6 s after a `PermissionRequest`, so it's suppressed as planned.
7. **Esc in kitty during a permission prompt sends no event at all.** Approvals can therefore also go stale. The typing watchdog (180 s) and the next `UserPromptSubmit` clean them up.
8. **Closing every kitty window doesn't quit kitty.** Quit sends SIGTERM to kitty's pid (the `kitty-<pid>.sock` name gives it).
9. **The hook script uses `$KITTY_LISTEN_ON`** for its fallback instead of searching the folder for sockets.
