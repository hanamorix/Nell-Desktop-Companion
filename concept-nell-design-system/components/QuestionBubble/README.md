# QuestionBubble

Claude's `AskUserQuestion`. It shows the question text and a single **Answer in terminal** button, never Allow/Deny.

## Rules (from the spec)
- It ranks **above** approval bubbles.
- It never fades until it is answered. While it is open, the message bar queues your input.

## Look
The same frame as ApprovalBubble (a `gold` top edge and `drop-lg`), with a `gold` QUESTION header that uses the ellipsis icon.

## What the consumer provides
The question text.
