# AlertBubble

It is used for notifications (`nl-bubble--alert`) and for failures (`nl-bubble--error`). One frame covers both, and the color sets the tone.

## Rules (from the spec)
- **Alert:** `Notification` text. An idle-waiting notification shows at most once, and a permission notification that arrives while an approval is pending is dropped.
- **Error:** `PostToolUseFailure` ("`npm test` failed", during the short oops beat) or `StopFailure` (the error, briefly). Error bubbles start fading only once you are active again.

## Look
- Alert: `surface` with a `gold` top edge and a `gold` HEADS UP header.
- Error: a `wine` fill with a `berry` top edge and a `blush` FAILED header. The body is cream on wine (7.8:1).

## What the consumer provides
The text and the kind.
