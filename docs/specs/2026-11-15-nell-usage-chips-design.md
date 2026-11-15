# Nell usage chips: design

**Date:** 2026-11-15 · **Status:** approved by the user in conversation ("A, gauge chips", "With tired face").

## Intent

The user wants to see, at a glance, how much of their Claude usage is left: the **5-hour session** limit and the **weekly** limit. The chips should be quick visuals rather than numbers to read, and they're **always shown, kept small** (the user's words: "Always, small"). Today Nell only reacts once a limit has already been hit, with a 🔌 and a nap. The chips give warning before that happens.

## Goals

- Two gauge chips, **7D** (weekly) on top and **5H** (session) below it, stacked in the chip column directly above Chat and Code. *(User picked option A.)*
- Each chip has a short label and a small meter. The fill is **leaf** below 50%, **gold** from 50% to 80%, and **berry** above 80%. These are Plum Night tokens, as in the mockup.
- Hovering shows the exact figure and the reset time, for example `Session 42% · resets 3:45pm` and `Weekly 81% · resets Thu 9:00am`.
- **Tired face** *(the user's choice)*: when either limit is above 90% and Nell's body is idle, her face is `exhausted` instead of `idle`. Typing keeps `intent`, and the reaction faces (happy, smile, sad, scared) still win over it.

## Non-goals

- No alerts, bubbles or sounds about usage. The chips and the tired face are the only signals.
- No history and no charts.
- No other limit types (Opus-only and similar). The status line only gives these two.

## Anti-goals

- Nell must never modify `~/.claude/settings.json` or `~/.claude.json`, and must never read or handle the user's login token.
- The status line must never slow Claude down. If Nell is unreachable, it gives up within a fraction of a second.
- Idle CPU must stay near zero. The chips redraw only when a value changes.

## Constraints

- The data comes only from Claude Code's **status line** input: `rate_limits.five_hour` and `rate_limits.seven_day`, each with `used_percentage` and `resets_at`. These are present for Claude.ai subscribers after the first reply of a session.
- Claude runs the status line only while it's active (on each reply update), so the values go stale while Claude is idle.
- The project rules apply: Command Line Tools only, no SwiftUI `@State`, tests via `scripts/test.sh`, and the showcase and stress test must not touch the user's running Nell.

## Approaches

| Approach | Trade-off | Verdict |
|---|---|---|
| **Status line in Nell's own `--settings` file**, forwarding the JSON to Nell's socket | It uses data Claude Code already computes and leaves the user's settings untouched. It only updates while Claude is replying. | **Chosen**: it's the only sensible way. |
| Ask Anthropic's usage endpoint directly | It always has fresh numbers, but it means reading and using the user's OAuth token. | Rejected (anti-goal) |
| Parse the session transcripts | Easy to read, but they don't contain rate-limit figures. | Rejected (no data) |

## Decided behaviour

- **Source:** `hooksSettingsJSON` also writes a `statusLine` (type `command`) into Nell's generated `hooks-chat.json` and `hooks-code.json`. The command posts the stdin JSON to Nell's socket on a separate path from `/hook`, so status updates never go through the hook reactions. It prints one short line for Claude's own status bar, `5h 42% · 7d 81%`, or nothing when there's no data. *(My call, accepted with the design.)*
- **Merging:** Chat and Code both send updates. Nell keeps the most recent reading for each window, since both report the same account.
- **Staleness:** once a window's `resets_at` has passed, that chip shows empty (0%) until the next reading. Before the first reading, a chip shows a dimmed `–` and its tooltip says `No reading yet`.
- **Persistence:** none. A relaunched Nell starts at `–` and fills in on Claude's next reply. *(My call: it avoids showing old numbers as current.)*
- **Showcase:** the scenes add chip states for none, low, mid, high and over 90% with the tired face, and a reset that has passed. The coverage test includes them.

## Left to the builder

- The exact pixel geometry, using the existing chip size and `NellBlock.chips` and mirroring with her. The two new chips go above Chat and Code in the same column.
- Whether the status command is a new resource script or a mode of `nell-hook.sh`.
- How the tooltip formats the reset time beyond the examples above.

## Verify first (spike, first task)

1. Capture one real status-line JSON from Code to confirm the field names and the `resets_at` format (epoch seconds or ISO string).
2. Confirm the status line still runs while Code's kitty window is hidden, and in Chat's kitty window.
