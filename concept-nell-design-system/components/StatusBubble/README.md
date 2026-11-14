# StatusBubble

The one-line summary of what Claude is doing right now, such as "Editing auth.ts", "Running `npm test`" or "Reading 3 files". It is quieter than a reply.

## Rules (from the spec and the plan)
- It comes from `PreToolUse`. Each mode has **one** status bubble, which is replaced and never stacked (`statusBubbleReplacedNotStacked`).
- It has no tail. It reads as Nell muttering, not speaking.
- It disappears on `Stop`, when the reply takes its place.

## Look
A `plum-800` fill, a `plum-600` top edge, and `text-muted` ink. A trailing `pink-400` ellipsis shows that work is ongoing.

## What the consumer provides
The summary text from the per-tool template.
