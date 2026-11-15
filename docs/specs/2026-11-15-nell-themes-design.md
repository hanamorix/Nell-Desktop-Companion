# Nell colour themes: design

**Date:** 2026-11-15 · **Status:** the user asked for "a Settings item on the right click to pick from a different set of colour themes", left the colours to Claude, and then said "Just dive in with your picks". Every choice below is Claude's call unless it's marked as the user's.

## Intent

The user wants to change Nell's look from her right-click menu by picking from a small set of colour themes. Success means each theme looks deliberate rather than tinted, sits well with Nell's dark hoodie art, keeps every meaning colour readable (allow/deny, the usage levels), and switches instantly with no relaunch.

## Goals

- **Themes:** five of them. **Plum Night** (today's, the default), **Moss**, **Tide**, **Ember** and **Slate**. All are dark.
- **Where to pick:** the right-click menu gets **Settings ▸** with the themes listed and a tick next to the current one. *(The user asked for a Settings item; the submenu is Claude's call. It avoids a separate window, and later settings can join it.)*
- **What switches:** all of Nell's interface switches at once. That covers bubbles, the text box, the chips, frames, buttons, the usage meters, the minimised strip and the console frame.
- **The console:** the kitty console switches to the theme's terminal colours too, including any windows that are already open.
- **Saving:** the choice is saved and restored on launch.

## Non-goals

- **Recolouring Nell herself.** Her sprite stays as drawn. Recolouring baked pixel art is a separate art project.
- **Light themes.** Several tokens play two roles. Your own messages, for example, use `cream` as a paper *fill* with `outline` text, while elsewhere `cream` is the text colour. A light theme would need those roles split first, so it isn't part of this change.
- **Following macOS appearance automatically, custom colours, and per-mode themes.**

## Anti-goals

- **Meaning colours:** they must never lose their meaning. In every theme `leaf` reads as green (allow, low), `gold` as amber or yellow (pending, mid) and `berry` as red (deny, high).
- **Readability:** no theme may be harder to read than Plum Night for the same pairs of colours.
- **Idle cost:** switching must not add idle CPU. A theme change is a single redraw.

## Approaches

| Approach | Trade-off | Verdict |
|---|---|---|
| **Swap the palette:** each theme supplies the same 21 Plum Night token names, and `PN.*` reads the current theme | It's small, and every existing view keeps working. It can't do light themes. | **Chosen** |
| Split tokens into roles (`panelFill`, `bodyText`, `userPaper` and so on), then theme those roles | Light themes become possible, but it means rewriting every view's colour use. | Deferred until a light theme is wanted |
| Recolour the sprite per theme | Nell would match the theme, but each theme needs art work and review. | Rejected (non-goal) |

## The themes

Each theme supplies all 21 keys of `PlumNight.palette`. Plum Night stays exactly as it is (`tokens.json`). The roles, as the views use them:
- `outline`: frame lines.
- `plum-900`: wells and the deepest background.
- `plum-800`: panels and bubbles.
- `plum-700`: chip fill and selection.
- `plum-600`: bevel highlight.
- `plum-500`: disabled.
- `hair-700` / `hair-500`: inactive chip and its highlight.
- `cream`: text, plus the paper of your own messages.
- `snow`: brightest text.
- `muted`: secondary text.
- `blush`: soft accent.
- `pink-400` / `pink-600`: the theme accent.
- `berry` / `wine`: deny and error.
- `leaf` / `leaf-700`: allow and low.
- `gold` / `gold-700`: pending and mid.
- `user-blue` / `user-blue-hi`: the terminal's blues.

| Key | Moss (forest, amber accent) | Tide (navy, teal accent) | Ember (charcoal, orange accent) | Slate (neutral grey, soft-blue accent) |
|---|---|---|---|---|
| outline | #0c120e | #0a0f17 | #120c0a | #0d0f12 |
| plum-900 | #121a15 | #0f1622 | #1a1310 | #14171b |
| plum-800 | #1a261e | #172133 | #261c17 | #1d2127 |
| plum-700 | #2c3f31 | #263650 | #3d2d25 | #2e343d |
| plum-600 | #384a3c | #30415c | #4a382e | #39404a |
| plum-500 | #56635a | #4f5d73 | #6a5a50 | #5a616b |
| hair-700 | #2e2a1f | #2a2a3a | #3a2a20 | #2b2b30 |
| hair-500 | #4d4635 | #474a60 | #5e4636 | #4a4a52 |
| cream | #e4ead0 | #d6e4f0 | #f2dcc4 | #dfe3e8 |
| snow | #f6f9ea | #f2f8fd | #fff6ea | #f7f9fb |
| muted | #a9b59f | #9fb1c4 | #c2a891 | #a3abb5 |
| blush | #d9c79a | #a9d8d6 | #f0b98a | #b9c6d6 |
| pink-400 | #c9a85b | #5cc8c0 | #ee8a4a | #8fb3e0 |
| pink-600 | #a8873f | #3fa39c | #c96d33 | #6d93c4 |
| berry | #b0574a | #ac4a5a | #b8483e | #ab4c55 |
| wine | #6a2f28 | #6e2a36 | #6a2620 | #6b2c33 |
| user-blue | #3d6470 | #5a4a9e | #3f5f8c | #3e5c9e |
| user-blue-hi | #6fa3b0 | #9283d6 | #7698c8 | #7f9fd6 |
| leaf | #9fd37a | #7fd49a | #9ccf6e | #8ccf7a |
| leaf-700 | #5a8a3f | #3f8a5a | #5a8a38 | #4f8a46 |
| gold | #e6c15c | #e8c060 | #f0c25a | #e9b45f |
| gold-700 | #a3812c | #a5822c | #aa8228 | #a8762f |

These hex values are Claude's picks. The builder may nudge a value to pass the readability test below. Any change gets recorded in the build ledger and shown at the visual sign-off.

## Console colours

- **From the tokens:** kitty's background (`plum-900`), foreground (`cream`), cursor (`pink-400`), and selection background and foreground (`plum-700` / `cream`) come from the theme's tokens.
- **The 16 ANSI colours** are set per theme by hand. Red stays red, green green, yellow yellow, blue blue, magenta magenta and cyan cyan, each harmonised with the theme. Plum Night's 16 stay exactly as in today's `kitty.conf`.
- **Applying them:**
  - On launch, `kitty.conf` is written with the current theme's colours.
  - On a switch, each running Nell kitty window is recoloured through kitty remote control (`set-colors`).
  - If kitty isn't running, the switch does nothing to the console and never errors.

## Saving

`SavedState` gains `theme: String?`. A missing or unknown name falls back to Plum Night.

## Showcase

A `themes` scene shows a representative state:
- a Chat reply and a message of yours;
- an approval with its buttons;
- the usage chips at mid and high;
- the minimised console strip.

It then steps through every theme. A coverage test checks that the scene visits every theme. The screenshots go to the user for sign-off.

## Checks

- **Complete palettes:** every theme defines exactly the 21 keys, and each value is a valid hex colour.
- **Readability:** for the pairs `cream`/`plum-800`, `muted`/`plum-800`, `muted`/`plum-900`, `outline`/`leaf`, `outline`/`gold` and `snow`/`berry`, every theme's WCAG contrast ratio is at least `min(4.5, Plum Night's ratio for that pair)`.
- **Plum Night unchanged:** Plum Night's palette still equals `tokens.json`, and its console colours equal today's `kitty.conf`.

## Left to the builder

- **How `PN.*` becomes theme-aware:** for example, computed statics reading the current theme, plus a published theme that rebuilds the root view.
- **Menu wiring:** how the menu shows the tick.
- **The theme file layout.**
- **The ANSI values** for the four new themes.
