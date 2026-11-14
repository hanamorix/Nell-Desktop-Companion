# PixelButton

A chunky, beveled pixel button with a 1-art-pixel outline and notched corners. It is used for every action in a bubble.

## Variants
- **`nl-btn--allow`**: `leaf` fill with `outline` ink. It is only for **Allow** on an approval bubble.
- **`nl-btn--deny`**: `berry` fill with `snow` ink. It is only for **Deny**.
- **`nl-btn--quiet`**: `plum-800`. Used for **OPEN CONSOLE**, **ANSWER IN CONSOLE** and every other secondary action.
- default: `plum-600` with a `pink-400` top edge.

Allow is lighter than Deny, so the pair can be told apart without relying on hue. Always keep the icon and the label together.

## States
- hover lifts the fill one step.
- pressed (`:active` / `.is-pressed`): the top bevel turns `plum-800` and the label drops one art pixel (2px). The button never moves as a whole.
- disabled: flat `plum-800` with a `plum-500` label.

## What the consumer provides
The label (uppercase, one or two words) and an optional 16px icon from **Icons**. Buttons never take keyboard focus in Nell; only the message bar does (spec: Focus).

## Markup
`<button class="nl-frame nl-btn nl-btn--allow"><img class="nl-icon" src="…allow.svg">Allow</button>`
