# ModeChip

The two mode switches under Nell's desk: 💬 **Chat** and ⌘ **Code**. They are drawn as small wooden chips.

## Behaviour (from the spec)
- The first click selects the mode, and the message bar then sends to that mode.
- A second click on the chip that is already selected shows or hides that mode's kitty window.

## Look
- At rest: a `hair-700` "wood" fill with a `hair-500` top edge and a `muted` label.
- Selected: a `plum-700` fill with a `pink-400` top edge and a `cream` label, plus a 3×1 art-pixel `pink-400` underline below the chip.
- `nl-chip__dot`: a 2×2 `gold` pixel that shows when the other mode has an unseen bubble.

## What the consumer provides
The selected state and the unseen-activity flag. The icons are `nell-chat.svg` and `nell-code.svg`.
