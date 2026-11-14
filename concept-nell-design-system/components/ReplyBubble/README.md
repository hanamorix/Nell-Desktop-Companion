# ReplyBubble

Claude's reply, shown in a plum speech bubble whose stepped pixel tail points down-left toward Nell.

## Rules (from the spec)
- **Code mode:** `last_assistant_message`, cut to about 3 lines, then a `muted` line reading "…more in ⌘".
- **Chat mode:** the whole reply. Add `nl-bubble--scroll` when it is long (it scrolls past 150px), and let it fade only after that.
- It shows 20 s after you are active again (60 s for a Chat reply), then fades over 2 s. Hovering pauses the fade.
- A bubble from the mode you are not looking at carries an **`nl-badge`** (💬 CHAT or ⌘ CODE) on its top-right edge.

## Look
`surface` fill, `edge-light` top edge, and `text` ink. Commands and paths go in `nl-code` (`plum-900` chips). The bubble is at most `bubble-max` (264px) wide.

## What the consumer provides
The text (already cut to length), the mode, and whether that mode is the selected one.
