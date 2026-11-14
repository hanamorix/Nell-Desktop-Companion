# Design system review: `concept-nell-design-system/` (2026-11-14)

The folder is a pixel-art design system called **Plum Night**, made by a Claude design tool from the repo at commit `34feb96`. That commit predates the v2 console work, so the system describes v1. It was reviewed file by file, every component was rendered (the previews point at the design tool's `/_blob/<hash>` store, so the links were re-mapped through `design-system.json`), and its claims were checked.

## What's in it

| Part | Contents | State |
|---|---|---|
| `README.md` | Content rules (voice, labels, no emoji), the pixel grid, the frame recipe, colour roles, type, motion, layout | Clear and specific; written against the v1 spec |
| `tokens.json` / `tokens.css` | 23 colours (11 base, 12 aliases), 2 px art-pixel spacing scale, notched-corner "radius", hard shadows, the 4-step bubble opacity ladder | Complete apart from **`type`**, which is empty in `tokens.json`; the type scale lives only in the README |
| `components/` | 10 components plus a cover: Alert/Error, Approval, BubbleStack, MessageBar, ModeChip, PixelButton, Question, Reply, Status, UserBubble. Each has a README (rules + look) and an HTML preview; `bundle.css` (70 rules) styles them | All render correctly once the blob links are fixed; no `border-radius` anywhere, consistent with the no-curves rule |
| `assets/Icons/` | 8 pixel icons (16×16, single-ink cream): chat, code, allow, deny, terminal, alert, more, sleepy | Load natively in macOS (`NSImage` reads SVG), so SwiftUI can use them directly |
| `assets/Character/` | `nell-pixel-reference.png` (150×150, real pixel art, transparent) and a copy of the smooth typing concept | The reference is the palette source and the art direction |
| `fonts/`, `licenses/` | Departure Mono v1.500 (woff2) and a licence file | **The licence file is wrong**: it's the repo's MIT licence for site code; the font itself is **SIL OFL 1.1** (see `Sources/Nell/Resources/fonts/OFL.txt`) |

Also in `artwork/` (not part of the design system):
- `idle/nell-desk-idle.png`: four new idle frames, with chin on hand. It's 1672×941, a **smooth illustration on a white background with no alpha**, and the frames are unevenly spaced.
- `typing/nell-desk-type.png`: the same image as the concept typing strip, saved again (same size and content, different bytes).

## Verified claims

- **Contrast:** every ratio in the README is accurate (WCAG):
  - cream on plum-700: 8.94
  - muted on plum-700: 5.68
  - snow on user-blue: 6.01
  - outline on leaf: 10.39
  - snow on berry: 4.95
  - cream on wine: 7.83
  
  Pairs the README doesn't list also pass: muted on plum-800 is 7.67, cream on plum-900 is 13.28, and outline on gold is 10.24. **Every text pairing in the system passes AA.**
- **Palette:** the hoodie plums, hair browns, skin creams and eye pinks match the pixel reference.
- **Font:** the bundled woff2 is the same Departure Mono v1.500 that Nell ships.
- **Icons:** all 8 load in AppKit at 16×16.

## What we can use directly

1. **The palette as SwiftUI colour tokens**, one-to-one: `outline`, `plum-900…500`, `hair-700/500`, `cream`, `snow`, `muted`, `blush`, `pink-400/600`, `berry`, `wine`, `user-blue`, `leaf`, `gold`, and the aliases.
2. **The frame recipe** as one reusable SwiftUI modifier. It replaces today's placeholder rounded rectangles:
   - a 1 art-pixel outline with notched corners;
   - a fill;
   - a pink top highlight and a plum bottom bevel;
   - a hard drop shadow with no blur.
3. **The bubble kinds and their looks**, which map onto Nell's existing `BubbleKind`s: user, reply, status, approval, question, alert, error.
4. **The PixelButton variants** (allow, deny, quiet, default) and their pressed and disabled states.
5. **The ModeChip and MessageBar**, including the "chat has news" dot and the `QUEUED` tag, which Nell already tracks (`inputHeld`).
6. **The 8 icons**, which replace the 💬/⌘ emoji, as the system's "no emoji" rule asks.
7. **The content rules**: uppercase one- or two-word labels, status lines that sound like muttering, commands in code chips.
8. **The motion rules**, which already match the code: the 4-bubble opacity ladder (1, 0.55, 0.3, 0.12) and the 20/60/2 s timings.

## What needs updating for v2 (conflicts)

| Design system says | v2 now does | Decision needed |
|---|---|---|
| User bubbles **blue** and "like iMessage"; MessageBar "styled like an iMessage bar" | The user asked for **speech bubbles, not iMessage**. v2 uses a light-grey user bubble | Keep user-blue as just a colour on a pixel speech bubble, or pick a plum or cream user bubble |
| "Open terminal", "Answer in terminal", "kitty comes forward" | Kitty lives in the **console bubble**. Bubbles say "Open console" and "Answer in the console", and the console only opens on a click | Rename labels and update the Approval and Question rules |
| ModeChip second click "shows or hides that mode's kitty window" | ⌘ toggles the console between **open and minimised**, and the first ⌘ from Chat opens it | Update ModeChip behaviour |
| Type scale 11 / 22 / 44 px | The console runs at **16.5 pt** (3× the pixel grid on a 2× display), which the user asked for after 11 looked small | Add 16.5 to the scale, or note it's console-only. It's crisp at 2× but not at 1× |
| No console | **ConsoleFrame**, a **minimised console** bubble and a **console-needed** bubble now exist, as functional placeholders | Design three new components in the same frame language |
| No ⌥ cue | Clicks pass through Nell; ⌥ makes her grabbable | Optionally add a subtle "grab" cue (a cursor or outline) while ⌥ is held |
| Character: smooth concept as placeholder | Same today | The idle and typing art still has to be drawn as pixel art (the pixel reference is the style guide) |

## Housekeeping fixes

- Replace `licenses/DepartureMono-LICENSE.txt` (MIT) with the font's SIL OFL 1.1 text.
- Fill in `tokens.json` → `type`: body 11/15, label 11/11 uppercase, title 22, display 44, plus a console size.
- The component previews only render inside the design tool. Its `/_blob/` links don't resolve on disk or on GitHub.
- `design-system.json` icon sizes don't match the files: chat is listed at 1341 bytes but the file is 1186. The icons were changed after the manifest was written. This is harmless.
- `typing/nell-desk-type.png` duplicates the concept strip, and `nell-desk-idle.png` needs its background removed and frames cut evenly before it can be a placeholder.

## Verdict

This helps the design round a lot. It's a coherent, verified visual language (palette, frame, buttons, chips, bubbles, icons, voice) that drops onto v2's existing views almost one-to-one, because it was written from the same spec and bubble model. The work left before it fits v2:
- update the v1 wording (terminal → console);
- settle what colour the user bubble is;
- add the three console components and the 16.5 pt console size;
- fix the font licence file.

The character art is still the biggest open item. The pixel reference sets the style, but the per-state sprite strips don't exist yet.
