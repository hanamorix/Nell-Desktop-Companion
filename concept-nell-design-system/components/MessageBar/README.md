# MessageBar

The single text field under Nell, styled like an iMessage bar in pixel form. It is the only element of Nell that takes keyboard focus.

## Behaviour (from the spec and the plan)
- It takes focus when clicked, or with the summon hotkey (⌥⌘N).
- It sends to the mode selected with **ModeChip**.
- While Claude has a prompt open (a `PermissionRequest`, or a question), what you type is **queued** and sent once the prompt is settled. The bar shows a `gold` `QUEUED` tag.

## Look
- The outer frame is a `plum-700` panel. The inner well is `surface-sunken` (`plum-900`) with a 1-art-pixel `outline` shadow along its top edge.
- When focused, a second ring is drawn: `focus` (`pink-400`), then `outline` outside it.
- The caret is a solid 3×5½ art-pixel `pink-400` block.
- The placeholder uses `text-muted`.

## What the consumer provides
The text, the focus state, and the queued flag.
