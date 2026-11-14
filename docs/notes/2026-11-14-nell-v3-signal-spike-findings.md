# v3 signal spike: 2026-11-14

Tested with Claude Code 2.1.325 and kitty 0.50.0, using the v1 pipeline method (logging server on a unix socket, hooks via `--settings`, prompts via `kitten @ send-text`). Auto permission mode, model `claude-opus-4-8`. Payloads are in `Tests/NellCoreTests/Fixtures/`, paths scrubbed. Documented-but-not-observed items are marked **docs only**.

## 1. Test results

| Command | Event | Notes |
|---|---|---|
| `python3 -m unittest test_ok -v` (exit 0) | `PostToolUse` | `tool_response` present |
| `python3 -m unittest test_fail -v` (exit 1) | **`PostToolUseFailure`** | no `tool_response`; has `error` |
| `python3 -m unittest test_fail 2>&1 \| tail -5` (pipe exit 0) | **`PostToolUse`** | looks like a success |

- **`PostToolUse.tool_response`:** `stdout`, `stderr`, `interrupted`, `isImage`, `noOutputExpected`. **There is no exit code field.** unittest writes to stderr, but the hook showed it all in `stdout` with `stderr` empty, so stderr is merged into stdout.
- **`PostToolUseFailure`** has `tool_name`, `tool_input`, `tool_use_id`, `duration_ms`, `is_interrupt` (bool) and **`error`**, a single string starting `Exit code <N>\n` followed by the combined output. For example `"Exit code 1\ntest_bad (...) ... FAIL\n...FAILED (failures=1)"`. The exit code is therefore parsed from `error` with `^Exit code (\d+)`.
- **The piped case reports success.** The pipeline's exit status is `tail`'s (0), so the failing test arrives as `PostToolUse` with stdout ending `FAILED (failures=1)`. The exit code can't detect this. A test-reaction feature must either accept missing piped failures or also scan `stdout` of test-looking commands for `FAILED` / `failed` / `Error` text (a heuristic).
- Fixtures: `PostToolUse-Bash-testpass.json`, `PostToolUseFailure-Bash-testfail.json`, `PostToolUse-Bash-testfail-piped.json`.
- Turn order for a Bash call: `UserPromptSubmit`, `PreToolUse`, `PostToolUse` or `PostToolUseFailure`, `Stop`, then a late `SubagentStop` (about 1 s later, as in v1). `PostToolUseFailure` is also a settle event for approvals, as already planned.

## 2. Context usage

- **Source:** the session transcript at `transcript_path` (JSONL). Assistant entries have `type:"assistant"`, and `message.usage` holds `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens` (plus `output_tokens_details`, `cache_creation.{ephemeral_1h,ephemeral_5m}_input_tokens`, `iterations[]`, `service_tier`, `speed`). `message.model` is the model ID.
- **One API message is split across several entries** (thinking, tool_use, text blocks each get their own line with the same `message.id`, often an identical `usage`). Read the **last** `type:"assistant"` line and ignore `isSidechain:true` entries (subagents).
- **Context size** = `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` (the formula Claude Code's own status line documents: it excludes `output_tokens`). Observed: first turn 2 + 28928 + 27239 = 56169, growing to about 57.1k over six calls. `input_tokens` is tiny (2) because nearly everything is cache, so it must not be used alone.
- **Window size is not in the transcript.** The status line JSON has `context_window.context_window_size` (200000 in the docs' example), but hooks don't. Nell needs a table keyed on `message.model` (a `[1m]` suffix variant means 1M) or an assumed 200k. This is a concern for Task 2.
- **`/compact`** (manual): `PreCompact` (`trigger:"manual"`, `custom_instructions:null`), a `SubagentStop` (the summariser; `last_assistant_message` is the summary), `SessionStart` with `source:"compact"` (same `session_id`), then `PostCompact` (`trigger`, `compact_summary`). **The transcript's last assistant entry is still the pre-compact one**, so usage reads stale (57k) until the next turn. The transcript gets a `type:"system", subtype:"compact_boundary"` entry with `compactMetadata.{trigger, preTokens, postTokens, cumulativeDroppedTokens, durationMs}` (here 57176 to 15645). Rule: on `PostCompact` or `SessionStart(source=compact)`, take `postTokens` from the last `compact_boundary` (or show "unknown") and ignore older assistant usage until a newer assistant entry appears. The docs say the same of the status line (`current_usage` is `null` after `/compact`).
- **`/clear`:** `SessionEnd` with `reason:"clear"`, then `SessionStart` with `source:"clear"` and a **new `session_id` and new transcript file**. Usage resets to 0 for the new session. No `PreCompact`.
- Fixtures: `transcript-usage.jsonl` (a user entry, three assistant entries, and the `compact_boundary`), `PreCompact-manual.json`, `PostCompact-manual.json`, `SessionStart-compact.json`, `SessionStart-clear.json`, `SessionEnd-clear.json`.
- `SessionStart.source` values seen so far: `startup`, `compact`, `clear`.

## 3. Usage limits (docs only, not triggered)

No real limit was triggered. From code.claude.com docs (hooks, errors, statusline, interactive-mode):

- **`StopFailure`** fires instead of `Stop` when the turn ends on an API error. Fields: `error` (one of `rate_limit`, `overloaded`, `authentication_failed`, `oauth_org_not_allowed`, `account_on_hold`, `billing_error`, `invalid_request`, `model_not_found`, `server_error`, `max_output_tokens`, `cloud_credential_error`, `unknown`), optional `error_details` (e.g. `"429 Too Many Requests"`), optional `last_assistant_message` (the API error text, e.g. `"API Error: Rate limit reached"`). Fixture (from the docs example, not a real capture): `StopFailure-rate_limit.documented-not-observed.json`.
- **Subscription limit text** (errors page): `You've hit your session limit · resets 3:45pm`, `…weekly limit · resets Mon 12:00am`, `…Opus limit…`, `…Sonnet limit…`. Spend limits read `You've hit your monthly spend limit …`. The docs do not say which `error` value these map to (probably `rate_limit`, unverified), so match on `error == "rate_limit"` **or** `last_assistant_message` containing `hit your` and `limit`.
- **Auto-continue wait** (v2.1.234+, interactive claude.ai subscription sessions): Claude waits in the session and resumes after the reset. While waiting, `idle_prompt` is **not** sent. `Notification` types signal the wait ending: `quota_auto_resume_fired` (continuing), `quota_auto_resume_stale` (slept more than about 30 min; waits for Enter), `quota_auto_resume_disabled` (wait ended without continuing). Whether `StopFailure` fires at the start of the wait is **not documented** and was not verified.
- **Status line** JSON has `rate_limits.five_hour` and `seven_day` with `used_percentage` (0-100) and `resets_at` (Unix seconds), for Pro/Max subscribers after the first API response. It is a status line feature, not a hook, so using it would mean taking over the user's `statusLine` setting. Not recommended for Nell.
- **Conclusion for sleeping:** a limit-hit signal exists on paper (`StopFailure` with `error:"rate_limit"`, the `quota_auto_resume_*` notifications). The shape is **unverified against a real limit**, so sleeping should be built on it but treated as best-effort and tested only against the documented fixture.

## Open points for later tasks

- Context window size needs a model-to-size table (not in hooks or transcript).
- Piped test failures arrive as `PostToolUse` success.
- Whether `StopFailure` fires when a usage-limit wait starts is unverified.
