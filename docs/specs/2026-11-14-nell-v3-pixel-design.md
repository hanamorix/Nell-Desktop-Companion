# Nell v3: the pixel design round

Date: 2026-11-14 · Status: draft for approval · Builds on:
- [v1 design](2026-11-14-nell-v1-design.md)
- [v2 console design](2026-11-14-nell-v2-console-design.md)
- [design system review](../notes/2026-11-14-design-system-review-findings.md)

## Intent

v2 made Nell work as intended. v3 gives her her real look:
- a Plum Night pixel-art interface;
- Nell herself as animated pixel art at her desk, whose face and little emoji reactions follow what Claude is doing.

She must still feel like one cosy character on the desktop, not a second Claude App. The user and Claude make the sprites **together in Aseprite**, expecting many rounds of revision.

## Goals

1. **The interface uses Plum Night** (`concept-nell-design-system/`): its palette, the pixel frame (outline, notched corners, pink top edge, bevel, hard shadow), PixelButtons, ModeChips, the MessageBar, the bubble kinds, the 8 pixel icons and its voice rules. Emoji in the interface are replaced by pixel icons.
2. **Your own messages are cream paper bubbles**, right-aligned against Nell's plum replies *(user's choice)*.
3. **The console takes Plum Night styling** *(user saw the proposal and didn't object)*:
   - **Frame:** the pixel frame around kitty, an uppercase title strip with minimise, and a stepped tail.
   - **Minimised:** a quiet `plum-800` status strip.
   - **Needs the console:** the gold "NEEDS YOU" bubble with OPEN CONSOLE.
   - kitty's colours are set to match.
4. **Nell is a 128 × 128 art-pixel sprite drawn at 2×** (256 pt on screen), at her desk with laptop and chair *(user's choice)*.
5. **Body animations:** idle, typing, yawning and sleeping. Each loop has breathing drawn in.
6. **Blinking** in every state.
7. **Paper stacks** on her desk, one for each 100K tokens of conversation context.
8. **Seven emoji reactions** beside her, drawn as pixel icons: ❤️ 👍 😢 ⚠️ ❓ ❗ 🔌.
9. **Her face changes with each reaction**, and every change of expression is **smooth and clean** *(user's requirement)*.

## Non-goals

- New companion features beyond the reactions and animations listed here.
- More than one display (unchanged from v2).
- Animating every expression in the user's library. Only the expressions mapped below are used.
- A settings screen for themes.

## Anti-goals

- A visible jump or pop when her expression or pose changes.
- Blur, anti-aliasing, fractional scaling or smoothed sprites anywhere.
- Emoji or reactions so frequent or large that Nell becomes noisy. That's the Clippy failure.
- Animation that wakes the CPU when nothing is changing. The v1 rule stays: redraw only on a frame change, at 6–12 fps.

## Decisions, and the approaches considered

| Decision | Options considered | Picked | Why |
|---|---|---|---|
| Sprite size | 64 px at 3×; 96 px at 2×; 128 px at 2× | **128 px at 2×** (user) | Closest to the detail of the user's 150 px reference; the most expressive |
| How sprites are made | Convert each state from illustrations; draw everything from scratch; one master sprite edited per state | **Master sprite, edited per state** (user) | One consistent style, the least redrawing, one big review up front |
| Your bubble colour | User blue; raised plum; cream paper | **Cream paper** (user) | Clear who is speaking; least like iMessage; cosy |
| Reactions | Emoji only; emoji and a matching face change | **Emoji and a face change** (user) | Makes her feel alive |
| Animations | v1's 12 states | **4 body loops, blinking, paper stacks, 7 emoji** (user's list; mapping confirmed) | Much less to draw at 128 px, and every one has a clear trigger |

## The sprite system

### Sources

- **Faces:** kept outside the repo.
  - The user's expression library: 1024 px RGBA illustrations, four frames each.
  - `Nell-PixelArt/`: the user's own pixel pipeline output (150 px idle and smile, with 96-frame idle and talk loops at 40 ms, blink included).
  - Expressions are converted with the **hana-pixel** skill (`hana-pixel:image-to-animated-pixel-art`) at the head size the 128 px scene needs, to match `Nell-PixelArt`'s style.
  - The mature-themed expression folders are **out of scope** and won't be used.
- **Desk, laptop, chair and hands:** no art exists. They're drawn new in Aseprite, using the concept strips (`artwork/concept`, `artwork/idle`) for pose and the Plum Night palette for colour (hair browns for the desk).
- **Style guide:** `concept-nell-design-system/assets/Character/nell-pixel-reference.png`.

### The master sprite (one Aseprite file)

Canvas: 128 × 128, transparent. **Layers**, from back to front:
1. chair
2. body and arms
3. desk
4. laptop
5. head (hood and hair)
6. **face** (swappable)
7. **eyes** (blink overlay)
8. props (paper stacks)

**Slices** mark where the app places things: `face`, `eyes`, `emoji` (the anchor beside her head) and `paper` (the anchor on the desk). They carry per-frame keys, so the anchors follow her breathing.

### States (body loops)

Each is a tag in the export, with breathing drawn in:

| State | When | Body |
|---|---|---|
| `idle` | Claude is idle | Resting at the desk |
| `typing` | A turn is running, from your prompt until Claude finishes, tools included | Hands typing |
| `yawning` | A test command is running | A yawn, with a hand to her mouth |
| `sleeping` | An hourly or weekly usage limit is hit | Head down on the desk |

### Faces

A face is a small sprite placed at the `face` slice. Faces can be short loops.

| Moment | Face (from the library) | How long |
|---|---|---|
| idle | `idle` or `content` | While idle |
| typing | `intent` | While typing |
| yawning, sleeping | `exhausted` (sleeping adds closed eyes) | While in that state |
| tests pass ❤️ | `happy` | Brief beat |
| approval accepted 👍 | `smile` | Brief beat |
| tests fail 😢 | `sad` | Brief beat |
| approval needed ⚠️ | `scared` or `awe` (choose while iterating) | Until answered |
| question ❓, alert or other failure ❗, can't hear Claude 🔌 | The current state's face | — |

The mapping was confirmed by the user ("change her face with each reaction").

### Smooth transitions *(my proposal, made to meet the user's "smooth and clean" requirement)*

- **Change the face during a blink.** The eyes close using shared closed-eye frames, the face swaps while they're shut, and they open on the new face.
- One in-between mouth frame where the two mouths differ a lot.
- A body change waits for the current loop's next **resting frame** (each loop marks 2 of them, so the wait is under half a loop), then plays a 1–2 frame in-between drawn for that pair.
- In-betweens are drawn only for pairs that actually happen: idle↔typing, typing→yawning, yawning→typing, idle or typing→sleeping, and sleeping→idle.
- Every face shares one eye position and one closed-eye patch, so the swap always lines up behind the blink. *(my call)*
- The app never jumps mid-frame.

### Overlays

- **Blinking:** a closed-eye patch at the `eyes` slice, shown for about 120 ms at random every 3–6 s. It's also the blink used for transitions.
- **Paper stacks:** 0–5 small stacked-paper sprites at the `paper` slice, one per 100K context tokens and capped at 5. They clear when the context resets (`/clear` or compaction).
- **Emoji:** 16 × 16 pixel icons drawn at 2×, which pop in beside her at the `emoji` slice. Brief reactions show for about 2.5 s. ⚠️, ❓ and 🔌 stay until resolved. Only one emoji shows at a time, with priority ⚠️ > ❓ > 🔌 > ❗ > 😢 > ❤️ > 👍.

### Export and app

- Aseprite "array" JSON plus a PNG sheet, with tags for the states, the faces, the eyes and props, and the slices. It's exported to `Sources/Nell/Resources/sprites/`, which replaces the concept placeholder.
- The source `.aseprite` files live in `artwork/sprites/`.
- The app draws: the body frame for the state, then the face at its slice, then the blink if one is due, then the props, then the emoji. Everything uses nearest-neighbour scaling at exactly 2×.

### Long quiet spells *(my call)*

v3's `sleeping` is only for usage limits, so v2's inactivity `sleepy` state is **removed**. After 10 minutes with no events, the idle loop rests on its resting frame and breathing stops. Blinks continue, slower (every 8–15 s). Any event resumes the loop. When the screen is locked or the display is asleep, everything pauses (v1). This keeps idle CPU near zero without a new pose.

### Which session drives what *(my call)*

- **Body state:** follows v2's `bodyState`. Approvals and questions from either mode come first, then the selected mode's turn (typing or idle). Yawning and sleeping come from either session.
- **Paper stacks** follow **Code's** context only. Chat has no tools and rarely grows that large, and Code-only means the stacks never jump when you switch modes.
- **Test reactions** come from Code only, since only Code runs tools.

### Turn end *(user-confirmed mapping)*

`Stop` returns her to idle with no happy beat. `listening`, `thinking`, `done` and `oops` are dropped, as agreed. The ❤️ for passing tests is the only "well done" signal.

## Triggers (what Nell watches)

| Reaction or state | Signal |
|---|---|
| typing | `UserPromptSubmit` → `Stop` or `StopFailure` (v2's state machine already tracks the turn) |
| yawning | A `PreToolUse` Bash command that matches the test patterns: `npm test`, `npm run test`, `pnpm test`, `yarn test`, `pytest`, `python -m pytest`, `swift test`, `cargo test`, `go test`, `jest`, `vitest`, `rspec`, `mix test`, `gradle test`, `mvn test`, `make test`, `bun test`, `deno test`, plus project scripts such as `scripts/test.sh` *(builder may extend)*. It lasts until that tool's `PostToolUse` or `PostToolUseFailure`. |
| ❤️ / 😢 | **Verify first** how a non-zero exit arrives (`PostToolUseFailure`, or `PostToolUse` with an exit code in `tool_response`). Then also check the test output in `tool_response` for the common runners' summary lines (pytest `N passed/failed`, jest/vitest `Tests: … failed`, Swift Testing `✔ Test run … passed` / `✘`, cargo `test result: ok/FAILED`, go `ok`/`FAIL`). **Rule:** if the command is piped (exit status unreliable) or the result is unclear, show **no reaction**. She must never cheer on a failure. *(my call)* |
| 👍 | An approval settled **Allow**, or answered in kitty and then run (the matching `PostToolUse`) |
| ⚠️ | needs-you (an approval is pending) |
| ❓ | A question is pending |
| ❗ | An alert `Notification`, or a non-test `PostToolUseFailure` or `StopFailure` that isn't a usage limit |
| 🔌 | disconnected (v2) |
| sleeping | An hourly or weekly usage limit. **Spike:** find a reliable signal (the `StopFailure` error text, a `Notification`, or the status-line `rate_limits` payload). It ends when a prompt next succeeds. |
| paper stacks | Context size. **Spike:** derive it from the session transcript's last assistant usage (input plus cache tokens), or from any context field in hook or status-line payloads. Reset on `SessionStart` `source: clear` and on compaction (`PreCompact` / `PostCompact`). |

Both spikes go **before** any art is drawn for sleeping or paper stacks. If a signal can't be found reliably, that animation is deferred and the user is told.

## Interface work (code)

- **Tokens:** Plum Night colours become SwiftUI constants. A `PixelFrame` modifier gives the outline, notched corners, top edge, bevel and hard shadow. There's no `cornerRadius` anywhere.
- **Restyled to match the components:** bubbles (user = cream, reply, status, approval, question, alert/error, console-needed), chips (pixel icons instead of 💬/⌘), the message bar (with the `QUEUED` tag driven by `inputHeld`), buttons, the console frame and the minimised strip.
- **Wording:**
  - "Open terminal" becomes "Open console".
  - "Answer in terminal" becomes "Answer in the console".
  - Labels are uppercase, one or two words.
- **Type:** Departure Mono at 11 pt for the interface (with 22 for titles) and 16.5 pt in the console, all on Departure Mono's 2× pixel grid.
- **kitty colours:** the console's background, foreground, cursor and selection are set from Plum Night in `kitty.conf`.
- **Design system fixes:**
  - Replace its font licence with SIL OFL 1.1.
  - Fill in the `type` tokens.
  - Add the console, minimised strip and console-needed components.
  - Record cream as the user bubble colour.

## Workflow for the art

Each art piece is reviewed as an animated GIF at 2×, on light and dark backgrounds, in the browser. The user accepts it or sends notes, and accepted pieces are recorded in a notes doc.

Order:
1. **The master sprite** (desk, laptop, chair and body), with the idle face.
2. Idle and typing loops.
3. The face set and the blink-swap transition.
4. Yawning.
5. Sleeping (after its spike).
6. Paper stacks (after their spike).
7. The emoji icons.

The art can be iterated on while the interface code is built, since the sprite format is fixed up front.

## Left to the builder

- Exact frame counts and timings, within the 6–12 fps rule.
- The head size for the face conversion.
- Pixel details of the desk, laptop and chair.
- How the face-swap timing is coded, as long as it happens behind a blink.
- Whether `PixelFrame` uses a `Shape` or drawn rectangles.

## Verify during the build

- How a failed test command arrives (`PostToolUseFailure` versus `PostToolUse` with an exit code).
- The usage-limit and context-size signals (the spikes above).
- That composited faces at the `face` slice line up on every body frame.
- Idle CPU stays near zero when the sprite is still.
