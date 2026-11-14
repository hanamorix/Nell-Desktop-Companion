# ConsoleNeededBubble

Shown when Claude needs you in the console and Nell can't answer for you: an approval whose hook deadline passed, the folder-trust dialog, or Chat's one-time OK. It never opens the console by itself; it offers it.

## Rules
- Text such as "Answer in the console", "Claude needs you in the console" or "Chat needs a one-time OK".
- It never fades until settled. Opening the console on that tab settles it.

## Look
The same frame as **ApprovalBubble**: `surface` with a **`gold`** top edge, `drop-lg`, and a `gold` NEEDS YOU header with the alert icon. One `quiet` **OPEN CONSOLE** button with the terminal icon. Settled, the edge drops back to `plum-600` and the button goes.

## What the consumer provides
The text and the mode whose console tab it opens.
