# BubbleStack

The single column of bubbles rising from Nell's head (layout A in the spec). The newest is at the bottom, nearest her. User, reply, status, approval and question bubbles all share it.

## Rules (from the plan's BubbleStore)
- At most **4** bubbles are visible. From newest to oldest, their opacity is `bubble-age-0` 1, `bubble-age-1` 0.55, `bubble-age-2` 0.3 and `bubble-age-3` 0.12. A fifth is removed.
- Unsettled approvals and questions keep full opacity wherever they sit.
- The gap between bubbles is `space-3` plus the tail. The column is `bubble-max` wide, and your bubbles align right (tail on the right) while Nell's align left (tail on the left).
- Only visible bubbles, Nell and the bar take clicks; everything else passes through to the desktop.

## What the consumer provides
The ordered list of `(bubble, opacity)` from `BubbleStore.visible`.
