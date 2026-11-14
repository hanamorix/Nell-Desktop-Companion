# Nell v3 art and interface review log (2026-11-14)

Each round of the user's visual review: what was shown, what they said, and whether it was accepted.

## Interface: Plum Night (Task 5)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | Plum Night interface live on the desktop: cream user bubbles on the right, plum Nell bubbles on the left, pixel buttons and icon chips, the QUEUED tag, the console frame and the minimised strip | "The 'Ask Claude Code' message box and border need to be bigger in width; the height is good." Nothing else needed changing. | Changes requested: widen the bar (Nell's block goes from 230 to 320 pt wide, height unchanged) |
| 2 | Wider message bar: Nell's block 320 pt, field 240 pt, height unchanged | "Yes, accept it" | **Accepted.** The Plum Night interface is signed off |

## Master sprite (Task 6)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | 128 px master at 2× on light and dark, beside the concept and the Nell-PixelArt reference | Remove the fang so the mouth looks right. Show the table's rounded edges. Connect the laptop hinge. Clean up the black outlines. Simplify the hands so they're nicer to look at; the left hand must not overlap the laptop screen and both hands go on the keyboard. | Changes requested |
| 2 | Round 2: fang removed, rounded desk corners, connected hinge, cleaned outlines, simplified hands on the keyboard | "Revert the hands back, the simplified ones are pretty bad." Everything else is accepted by omission. | Changes requested: restore round 1's hands, keeping them on the keyboard and clear of the screen |
| 3 | Round 3: round 1's hands restored and moved onto the keyboard, clear of the screen; round 2 fixes kept | "Accept" | **Accepted.** The master sprite is signed off |

## Faces and blink transition (Task 7)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | 8 faces (idle, intent, exhausted, happy, smile, sad, scared, awe) plus shared closed eyes at 2× on light and dark, and a blink-swap GIF cycling through the faces | "With sad lets make the crying more extreme like a river line coming from her eyes, which is easy to see." Other faces accepted by omission. Scared vs awe for approvals not answered; scared kept as the default until round 2 review. | Changes requested: sad gets heavier, easy-to-see streams of tears running down from both eyes |
| 2 | Sad face with a 4 px tear stream from each eye, through the bottom of the glasses rims, down to the jaw; all other faces unchanged | "Make the 'tear rivers' wider" | Changes requested: widen both tear streams |
| 3 | Sad face with 6 px tear streams (covering most of each cheek, breaking both glasses rims) | "Lets back track slightly and make them big tears that come from her eyes." | Changes requested: replace the rivers with big individual teardrops coming from her eyes |
| 4 | Sad face with tears welling on the lower lids and one big teardrop (about 5×6 px) per eye on the cheek; glasses rims whole | "Accept, use scared" | **Accepted.** Faces and blink transition signed off; scared is the approval-needed face (awe stays on the sheet, unused) |

## Body loops and in-betweens (Task 8)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | `body:idle` (two 2.5 s breaths, head follows chest by 1 px) and `body:typing` (hands alternate 1 px lifts, 1.33 s breath), GIFs at 2× on a dark background, plus a frame sheet | "Lets make sure there are some effects when typing." "Lets move the left hand slightly to the left, but so it's slightly hidden by the laptop screen." "We have to make sure that all backgrounds are transparent." | Changes requested: typing effects, left hand moved left and partly behind the laptop screen, transparent backgrounds everywhere |
| 2 | Round 2: tap sparks on typing beats, left hand 3 px left with 9 px hidden behind the laptop lid (also on the master and face frames), transparent backgrounds everywhere, shown on a checkerboard | "Accept both" | **Accepted.** `body:idle` and `body:typing` signed off |
| 3 | `body:yawning` (sleepy slumped breath, then a yawn with her left hand over her mouth, about 4.7 s per cycle) and `between:typing-yawning` / `between:yawning-typing`, face drawn into the frames | "Accept yawning" | **Accepted.** Yawning loop and its in-betweens signed off |
