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
| 4 | `body:sleeping` (head down on folded forearms behind the lid, 5 s breath, drifting z) with `between:idle-sleeping`, `between:typing-sleeping`, `between:sleeping-idle`, and the plug emoji position | "We have to make the arms looks like baggy sleeves. Instead of just boxes. or we can do her leaning on her hand and sleeping." | Changes requested: either baggy sleeves on the folded arms, or a new pose leaning on her hand; both drawn as variants for the user to pick |
| 5 | Two variants: A, the same head-down pose with baggy hoodie sleeves (creases, drooping cuffs, fingertips peeking) and strays fixed; B, sleeping propped on her hand. Shown side by side | Asked for a recommendation (A: distinct silhouette from the yawn, matches the spec's "head down on the desk", transitions done), then "A, baggy sleeves" | **Accepted.** Variant A sleeping and its in-betweens signed off; B discarded |

## Paper stacks and emoji (Task 9)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | `paper:1`–`paper:5` (small piles about 10 × 13 px at the right end of the desk) and the seven 16 × 16 emoji icons, on idle and sleeping frames, plus an emoji pop GIF | "The paper stacks should look like paper, so wider on the desk, stacking up like a tower." Emoji not commented on. | Changes requested: wider sheets lying on the desk that build up into a tower |
| 2 | Paper towers: about 19 px wide sheets on the desk, growing from an 18 × 10 pile to a 30 px tower with a loose sheet and dog-ear; paper spot moved to (100,74,24,34) | "I think we can make them wider, we just have to make sure that they go infront of Nell." Emoji not commented on. | Changes requested: wider sheets, drawn in front of Nell |
| 3 | Paper sheets widened to 28 px, drawn in front of her right side, paper spot (90,74,34,34); emoji unchanged from round 1 | "The wider paper stack is good, and I like it. The emoji might be to big. we have to keep it similar size to the other emojis" | **Paper stacks accepted.** Emoji: changes requested; read as the larger icons (warning, plug, thumbs-up) outsizing the smaller ones, so all seven get one consistent size, none bigger than the small ones |
| 4 | Emoji resized to one footprint (about 12 × 11 px; "!" and "?" narrower, same height), shared baseline; plug reshaped, "!" a straight stem; shown before and after | "Accept emoji" | **Accepted.** Paper stacks and emoji signed off |

## End-to-end check on the desktop (2026-11-15)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | v3 build running on the desktop (idle, minimised console) | "When a reply from Nell is small or short, the bubble should reflect that." "Additionally the tail of the speech bubble should always face Nell no matter where Nell is placed." "We should be able to 'Right Click' on the Nell Avatar to Minimise, Close/Quit, or assign folder location." "Kitty/Claude Code should always start in Auto mode." "'Claude Code is idle' should be inline with all other icons and Message bar." "The message bar/input bar should be the same width as the Nell Avatar" | Changes requested (Task 12). Also asked for a CPU/RAM stress test (Task 13) and tests that show every icon, emoji and alert (Task 11, showcase) |
| 2 | Three bottom-row mockups on her real sprite: A, bar under her desk with the buttons stacked in the corner; B, the whole row at her width; C, buttons inside the bar | "A, bar under desk". Minimise: "Hide until needed" | **Option A chosen** |
| 3 | All six fixes on her desktop (rebuilt and relaunched): bubbles that fit, tails toward her head from every corner, right-click menu, Auto mode, bar under her desk, idle strip inline; plus clicks on her keep the other app's keyboard, she stays put when she turns, drags need ⌥ from the start | Asked to try a real right-click and a plain left-click with another app focused: "Both work" | **Accepted.** End-to-end fixes signed off |

## Usage chips (2026-11-15)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | The six showcase states of the 7D and 5H gauge chips: no reading (dimmed –), low (green), mid (gold), high (berry), tired (exhausted face over 90%), after a reset (empty meters, normal face). Chips at Chat/Code size with the option A meter. Then the showcase running live, to hover a chip with another app in front | Asked whether the chips look right and whether the hover text appears: "Both work" | **Accepted.** Usage chips and their hover text signed off |

## Colour themes (2026-11-15)

| Round | Shown | User's notes | Result |
|---|---|---|---|
| 1 | The five themes in the showcase (Plum Night, Moss, Tide, Ember, Slate), each with a live approval (Allow, Deny, Console), bubbles, the 7D/5H chips, the text box, the minimised console strip and the open console's title bar; plus the right-click menu with Settings ▸. Colours were Claude's picks ("Just dive in with your picks") | Asked whether the five themes look right: "Looks good" | **Accepted.** Colour themes signed off; the submenu tick and live kitty recolouring to be checked on the desktop |
| 2 | On the desktop after the merge: the Settings submenu's tick on the current theme, and the kitty console recolouring on a switch | "Both work" | **Accepted.** Menu tick and live console recolouring confirmed |
