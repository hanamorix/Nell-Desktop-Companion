# Usage chips status-line spike: 2026-11-15

Tested with Claude Code 2.1.325 and kitty 0.50.0, model `claude-opus-4-8`. Method as in the v3 signal spike: a standalone kitty started with `--start-as=hidden`, `--listen-on` and `-o allow_remote_control=yes`, prompts via `kitten @ send-text`, claude run with `--settings <file>` only. The settings file's `statusLine` command was `cat > <dir>/status-$$.json; echo ok`, so each invocation left one file. Cwd was the (already trusted) repo root, so no trust dialog appeared. Fixture: `Tests/NellCoreTests/Fixtures/statusline.json` (home path replaced by `/Users/me`, session and prompt ids zeroed).

## Results

- **`rate_limits` shape:** `"rate_limits":{"five_hour":{"used_percentage":46,"resets_at":1794760800},"seven_day":{"used_percentage":31,"resets_at":1795226400}}`. `used_percentage` is a number 0-100 (integer here, so decode as `Double`). **`resets_at` is Unix epoch seconds** (a JSON integer, not ISO-8601): 1794760800 is 2026-11-15 16:40 UTC, 1795226400 is 2026-11-21 02:00 UTC.
- **Absent before the first reply:** the first invocation (at startup, `current_usage:null`, `prompt_id` missing) has **no `rate_limits` key**. The one after the reply has it. Decode `rate_limits`, and each window, as optional.
- **Hidden window:** `--start-as=hidden` is supported by kitty 0.50.0. The status line ran in the hidden window and the reply completed normally: yes.
- **Chat's args** (`--tools "" --strict-mcp-config --no-chrome --setting-sources project`): the status line from `--settings` still runs and `rate_limits` is present after the reply (same values): yes. So `--setting-sources project` does not stop `--settings` from applying.
- **Invocations:** two per session-with-one-short-reply, in both runs: one at startup (no `rate_limits`), one after the reply finished. Nothing fired mid-stream for a 1 s reply, so expect one call per completed reply (the docs describe it as debounced, about 300 ms), not a steady tick. Longer replies or tool calls were not tested.
- **Other fields** seen: `session_id`, `transcript_path`, `cwd`, `model.{id,display_name}`, `workspace`, `cost`, `context_window.{context_window_size,current_usage,used_percentage,remaining_percentage}`, `prompt_cache`, `version`. `context_window_size` was **1000000** here, which also answers the v3 spike's open point about the window size.

## Gotchas

- A kitty `--listen-on` unix socket path must be under about 104 characters, so it can't live in the long scratchpad path. Use something short like `/tmp/x.sock`. Without it the connect fails with "invalid argument" and the socket file is never created.
- In these sessions the footer showed "Transcript saving is off — inherited CLAUDE_CODE_CHILD_SESSION marker" (the spike ran from inside another Claude session). It did not affect the status line.
