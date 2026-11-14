# ConsoleFrame

The frame Nell draws around her private kitty window (the Claude Code console) when it is open. kitty sits inside it, so the middle is **hollow**: it is never filled and never takes clicks.

## Rules (from the v2/v3 spec)
- The console opens only on a click: ⌘, the minimised strip, OPEN CONSOLE or ANSWER IN CONSOLE.
- The title strip is the only part of the frame that takes clicks. Its minimise button returns the console to the **MinimisedConsole** strip.
- While Nell is dragged (with ⌥) the console hides, then comes back where she lands.

## Look
- The frame recipe around the whole console: a 1-art-pixel `outline` with notched corners, then a 1-art-pixel `plum-700` ring between the outline and kitty, with a `plum-800` bottom bevel and a hard `drop` underneath. The border is 2 art pixels (4pt) in all.
- **Title strip** (24pt): `plum-700` with a `pink-400` top edge. The code icon, then `CLAUDE CODE · <PROJECT>` uppercase in `cream`, and on the right a small `plum-800` minimise button showing a `cream` bar.
- A **stepped tail** (the bubble tail turned sideways) pokes out of the side nearest Nell, near the bottom, in `plum-700` with an `outline` edge.
- kitty itself uses the Plum Night palette (`kitty.conf`): `plum-900` ground, `cream` text, `pink-400` cursor, `plum-700` selection, at the `console` type size (16.5).

## What the consumer provides
The project name, which side Nell is on, and the minimise action.
