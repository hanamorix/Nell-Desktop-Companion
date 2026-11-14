# Nell

Nell is a small pixel-art girl in a plum cat-ear hoodie who sits on your Mac desktop and talks to Claude for you. This system is her look: **Plum Night**. It has dark plum panels taken from her hoodie, pink accents from her eyes, cream text from her skin, and one font, **Departure Mono**, on a 2px art-pixel grid. The feel is modern Stardew Valley: cozy, chunky and hand-placed, never glossy.

> Nell must stay **light and out of the way**. If she starts to feel like a second Claude App, she has failed (spec, Anti-goals). Every rule below serves that.

## Content fundamentals

- **Nell speaks in short lines.** Status bubbles read like muttering: "Editing auth.ts…", "Running `npm test`…", "Reading 3 files". Use present tense, no subject, and an ellipsis.
- **Approvals start with what Claude wants:** "Wants to run `npm test`". After settling they say what happened: `Allowed`, `Denied`, `Answer in terminal`.
- **Commands, paths and tool names** always go in a `code` chip (`plum-900` ground). Never put them in quotes.
- **Code replies** are cut to about 3 lines, then "…more in ⌘". **Chat replies** are shown in full.
- **Labels** on buttons and chips are UPPERCASE, one or two words: ALLOW, DENY, TERMINAL, CHAT, CODE.
- **No emoji in Nell's own UI text.** The 💬 and ⌘ from the spec are drawn as pixel icons (`nell-chat.svg`, `nell-code.svg`).

## Visual foundations

### The pixel grid
- **1 art pixel = 2px** (`px` token). Every outline, bevel, gap and tail step is a whole number of art pixels. Nell's sprite is drawn at a whole-number zoom with nearest-neighbour scaling (spec: Character art).
- **No curves.** Corners are *notched*: the corner pixel is simply left empty (`corner-1`). Never use `border-radius`, gradients or blur.
- **No anti-aliasing.** Turn off font smoothing. Images use `image-rendering: pixelated`.

### The frame (every panel, bubble, button, chip)
1. A 1-art-pixel **`outline`** (`#120d0e`, the sprite's own line color) on four sides, with the corners left empty.
2. A **fill**: `surface` (`plum-700`) by default.
3. A 1-art-pixel **top highlight** (`edge-light`, `pink-400`) and **bottom bevel** (`edge-dark`, `plum-800`).
4. A hard **drop** shadow one art pixel down (`drop`), or `drop-lg` for bubbles that need you.

The pink top edge is what makes a plum panel read on a **dark** wallpaper. The near-black outline does the same on a **light** one. Every preview here is drawn on striped light and dark wallpaper to prove it.

### Color roles
| Role | Token | Notes |
|---|---|---|
| Panel | `surface` → `plum-700` | Text: `text` (cream, 8.9:1) or `text-muted` (5.7:1) |
| Sunken well | `surface-sunken` → `plum-900` | The message bar field, code chips |
| Accent and focus | `pink-400` | Highlight edges, the caret, the selected chip, the focus ring. Never use it for a large fill. |
| Your messages | `user-blue` + `snow` text | The spec makes them blue and right-aligned (6.0:1) |
| Allow | `leaf` + `outline` text | 10.4:1. It is lighter than Deny, so the pair differs in lightness as well as hue. |
| Deny and error | `berry`, `wine` + `snow` / `cream` | 4.9:1 and 7.8:1 |
| Needs you and alert | `gold` | The top edge and header of approval, question and alert bubbles |
| Wood | `hair-700`, `hair-500` | Mode chips and badges: Nell's desk and hair browns |

### Type
**Departure Mono** only. It is drawn on an 11px grid, so sizes are multiples of 11: `body` 11/15, `label` 11/11 uppercase, `title` 22, `display` 44. At 11px it renders crisp at every whole-number backing scale. Never use fractional sizes.

### Motion (from the plan)
- At most **4 bubbles** show. Their opacity runs `bubble-age-0` 1 → `bubble-age-1` 0.55 → `bubble-age-2` 0.3 → `bubble-age-3` 0.12.
- A bubble lives **20 s** (**60 s** for a Chat reply), then fades over **2 s**. Done and error bubbles start their clock only once you are active again. Hovering pauses the fade.
- Approval and question bubbles **never fade** until they are settled.
- Nell animates at **6–12 fps** and redraws only when the frame changes. Fades are the only tweened motion. Everything else steps frame by frame.

## Iconography
There are eight 16×16 pixel icons in **Icons**, drawn in `cream` with `shape-rendering: crispEdges`: chat, code (⌘), allow, deny, terminal, alert, more (…), sleepy (zZ). Show them at 16px or 32px only (1× or 2×). On a `leaf` button, darken them to `outline` ink.

## Character
Nell herself is in **Character**: the user's pixel reference (`nell-pixel-reference.png`, 150×150) is the art direction for the sprite sheets, and the original smooth concept strip is from the repo. The state strips (idle, listening, thinking, typing, needs-you, oops, alert, done, sleepy, error) are still to be drawn in Aseprite (spec: Character art). Sample their colors from this palette.

## Layout
The column rises from Nell's head and the newest bubble sits nearest her: **BubbleStack** → Nell → desk → **ModeChip** pair → **MessageBar**. The column is at most `bubble-max` (264px) wide. Gaps: `space-3` between bubbles, `space-5` between the column and Nell, `space-6` from the screen edge. Only the bubbles, Nell and the bar take clicks; everything else passes through.

## Not synced
- **No style code existed** in `hanamorix/Nell-Desktop-Companion@34feb96`; the repo holds a spec, a plan, research notes and one concept image. So nothing was read from CSS or token files.
- **Taken from the repo:** the bubble kinds and their rules, the 4-bubble opacity ladder, the timings, "user bubbles are blue and right-aligned", the 💬/⌘ chips, Allow/Deny/Open terminal, and the concept art.
- **Designed for this system:** the palette (sampled from the user's pixel reference of Nell), the user-blue, leaf and gold hues, the spacing and frame rules, the eight icons and every component. Components are **hand-written CSS and HTML** (`components/bundle.css` plus static previews), not built from code, because the app will be native Swift. Treat them as the visual spec for the SwiftUI views.
- **Departure Mono** (v1.500, MIT) comes from `rektdeckard/departure-mono`; its license is in `licenses/DepartureMono-LICENSE.txt`.
