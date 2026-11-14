# ApprovalBubble

A blocking permission request from Claude Code ("Wants to run `npm test`"), with **ALLOW / DENY / CONSOLE** on one row. It is the most important bubble Nell shows.

## Rules (from the spec; an approval must never get lost)
- It comes from `PermissionRequest`. It **never fades** until it is settled, and Nell stays in the needs-you animation meanwhile.
- Each bubble is tied to its own request. It settles only that request, and closes as soon as the request is settled anywhere, including in kitty.
- Dismissing the bubble or quitting Nell counts as **no decision**, never as Deny.
- After settling it shows a tag: `Allowed` (leaf), `Denied` (berry), or `Answered in console` / `Answer in the console` (gold), then fades normally.
- If the hook deadline passes, it settles to "Answer in the console" and a console-needed bubble offers OPEN CONSOLE. The console only opens on a click.
- A soft sound plays once, unless kitty is already in front.

## Look
It stays at `bubble-max`. The three buttons sit on one row, ALLOW · DENY · CONSOLE (the third is `quiet` with the terminal icon), which fills the 236pt inner width exactly. `surface` with a **`gold`** top edge and a heavier `drop-lg` shadow, so it sits above the stack. The header is a `gold` NEEDS YOU line with the alert icon. A settled bubble drops back to a `plum-600` edge.

## What the consumer provides
The tool summary, the request id, and the settled outcome.
