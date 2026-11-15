# Nell colour themes: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five dark colour themes (Plum Night, Moss, Tide, Ember and Slate). The user picks one from a Settings submenu in Nell's right-click menu. A theme recolours her interface and her kitty console instantly, and the choice is saved.

**Architecture:**
- Themes are plain data in NellCore. Each one has the same 21 Plum Night token keys plus 16 ANSI console colours.
- `PN.*` in the app reads the current theme instead of a fixed palette.
- `NellModel` publishes the theme. The root view rebuilds when it changes.
- On a switch, `KittyController` recolours running kitty windows through remote control. On launch, it writes `kitty.conf` with the theme's colours.

**Tech Stack:** Swift 6.4 SwiftPM (Command Line Tools only), SwiftUI/AppKit, Swift Testing via `scripts/test.sh`, kitty remote control.

**Spec:** `docs/specs/2026-11-15-nell-themes-design.md`

## Global Constraints

- **Themes:** exactly five, in this menu order: **Plum Night** (default), **Moss**, **Tide**, **Ember**, **Slate**. All are dark. The hex values are in the spec's table, and Plum Night equals `concept-nell-design-system/tokens.json`.
- **Palette keys:** every theme defines exactly the 21 keys of `PlumNight.palette`, as valid `#rrggbb` values.
- **Meaning colours:** in every theme, `leaf` reads green (allow, low), `gold` amber or yellow (pending, mid) and `berry` red (deny, high).
- **Readability:** for the pairs `cream`/`plum-800`, `muted`/`plum-800`, `muted`/`plum-900`, `outline`/`leaf`, `outline`/`gold` and `snow`/`berry`, every theme's WCAG contrast ratio is at least `min(4.5, Plum Night's ratio for that pair)`.
- **Console colours:**
  - kitty `background` is `plum-900`, `foreground` is `cream`, `cursor` is `pink-400`, `selection_background` is `plum-700` and `selection_foreground` is `cream`.
  - `color0`–`color15` are set per theme by hand. Red stays red, green green, yellow yellow, blue blue, magenta magenta and cyan cyan.
  - Plum Night's `color0`–`color15` equal today's `Sources/Nell/Resources/kitty.conf`.
- **Menu:** right-click on Nell shows `Settings` as a submenu listing the five theme names, with a tick on the current one. It sits between "Choose project folder…" and the divider before "Quit Nell".
- **Saving:** `SavedState.theme: String?`. A missing or unknown name falls back to Plum Night.
- **Nell's sprite** is never recoloured.
- **Idle cost:** a theme switch is one redraw, with no new timers or polling.
- **Kitty not running:** switching never errors or launches anything. It only recolours windows that exist.
- **Project rules:** Command Line Tools only. No SwiftUI `@State`. Tests go through `scripts/test.sh` and packaging through `bash scripts/bundle.sh`.
- **Sandboxing:** the showcase and stress test never touch `build/Nell.app` or `~/Library/Application Support/Nell`, and never start kitty or claude. Never modify `~/.claude/settings.json` or `~/.claude.json`.
- **Docs and commits:** docs are dated, typed, filed under `docs/` and indexed in `docs/README.md` in the same commit. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Views that cache a colour at init or in a static.** A cached colour wouldn't follow a switch, leaving a half-themed window. The `themes` showcase scene screenshots every theme, and its checks log a MISMATCH if `PN.theme` disagrees with the model. This is pinned in Task 3.
2. **An unknown or renamed theme in `state.json`** (from a later version, or hand-edited) must fall back to Plum Night, not crash. Task 1 pins this with `savedStateUnknownThemeFallsBack`.
3. **Switching while kitty's console is open versus hidden versus never started.** It recolours what's running and is silent otherwise. Task 2 pins this with `setColorsCommandShape`, and the `KittyController` guard on a nil socket covers the rest.
4. **A new Nell launch with a non-default saved theme.** The first frame and the console must use the saved theme, with no flash of Plum Night. This is pinned in Task 2 (`kittyConfUsesTheme`) and Task 3 (the model starts from `state.theme`).
5. **Plum Night unchanged for existing users.** Task 1 pins this with `plumNightMatchesTokensJSON` (existing) and `plumNightConsoleMatchesKittyConf`.

---

### Task 1: Theme data and saving

**Files:**
- Create: `Sources/NellCore/Themes.swift`
- Modify: `Sources/NellCore/SavedState.swift` (add `theme`)
- Test: `Tests/NellCoreTests/ThemesTests.swift`, `Tests/NellCoreTests/SavedStateTests.swift`

**Interfaces:**
- Produces:
  - `public struct Theme: Sendable, Equatable, Identifiable`, with `id: String` (the display name), `palette: [String: String]` (the 21 keys) and `ansi: [String]` (16 `#rrggbb`);
  - `public enum Themes`, with `static let all: [Theme]` (in menu order), `static let plumNight: Theme`, and `static func named(_ name: String?) -> Theme` (falls back to `plumNight`);
  - `public func contrastRatio(_ a: String, _ b: String) -> Double` (WCAG 2, hex in);
  - `SavedState.theme: String?`.

- [ ] **Step 1: Write the failing tests.**
  - `themesAreTheFiveInOrder`: the names are `["Plum Night", "Moss", "Tide", "Ember", "Slate"]`.
  - `everyThemeHasTheFullPalette`: each palette's key set equals `PlumNight.palette`'s, every value matches `^#[0-9a-f]{6}$`, and `ansi.count == 16` with the same format.
  - `plumNightIsTheTokens`: `Themes.plumNight.palette == PlumNight.palette`.
  - `plumNightConsoleMatchesKittyConf`: Plum Night's `ansi` equals the `color0`–`color15` lines of `Sources/Nell/Resources/kitty.conf` (read via `#filePath`).
  - `everyThemeIsAsReadableAsPlumNight`: for the six pairs in Global Constraints, `contrastRatio(t[a], t[b]) >= min(4.5, contrastRatio(plum[a], plum[b]))` for every theme.
  - `meaningColoursKeepTheirHue`: in every theme, the hue of `leaf` is in 75°–150°, `gold` in 30°–60° and `berry` in 340°–20° (wrapping).
  - `contrastRatioKnownValues`: black against white gives 21 (±0.01), and a colour against itself gives 1.
  - `themesNamedFallsBack`: `named(nil)`, `named("Neon")` and `named("")` all return Plum Night, and `named("Tide").id == "Tide"`.
  - In SavedStateTests:
    - `savedStateKeepsTheme`: it round-trips `theme = "Ember"`;
    - `savedStateUnknownThemeFallsBack`: a `state.json` with `"theme": "Neon"` loads, and `Themes.named(state.theme)` is Plum Night;
    - an old `state.json` with no `theme` key still loads.
- [ ] **Step 2:** Run `scripts/test.sh`. Expect these tests to fail to compile.
- [ ] **Step 3:** Implement.
  - Use the spec's table values verbatim, and the four new themes' ANSI colours by the rule in Global Constraints.
  - If a spec value fails `everyThemeIsAsReadableAsPlumNight`, nudge only that value. Note it in the report: the old value, the new value and why.
  - Add `theme` to `SavedState` as an optional, decoded tolerantly (absent means nil).
- [ ] **Step 4:** Run `scripts/test.sh`. Expect everything to pass.
- [ ] **Step 5:** Commit `feat: colour theme data`.

### Task 2: Console colours follow the theme

**Files:**
- Modify:
  - `Sources/NellCore/KittyCommands.swift` (add `setColors`)
  - `Sources/NellCore/Launch.swift` or `Themes.swift` (add `kittyColorsConf`)
  - `Sources/Nell/KittyController.swift` (write `kitty.conf` with the theme's colours, add `applyTheme(_:)`)
  - `Sources/Nell/Resources/kitty.conf` (move the colour block out of the template)
- Test: `Tests/NellCoreTests/KittyCommandsTests.swift`, `Tests/NellCoreTests/ThemesTests.swift`

**Interfaces:**
- Consumes: Task 1's `Theme` and `Themes`.
- Produces:
  - `public func kittyColorsConf(_ t: Theme) -> String`, the colour lines (`background`, `foreground`, `cursor`, `selection_background`, `selection_foreground`, `color0`–`color15`), each `name #rrggbb`, newline-separated;
  - `KittyCommands.setColors(socket: String, conf: String) -> [String]`, which recolours every window in Nell's kitty (`kitten @ --to <socket> set-colors --all --configured <conf path>`);
  - `KittyController.applyTheme(_ t: Theme)`.

- [ ] **Step 1: Write the failing tests:**
  - `kittyConfUsesTheme`: for Tide, the output contains `background #0f1622`, `foreground #d6e4f0`, `cursor #5cc8c0`, `selection_background #263650`, `selection_foreground #d6e4f0`, and `color0`…`color15` equal to Tide's `ansi`.
  - `plumNightKittyConfUnchanged`: the Plum Night output equals the colour lines of today's `kitty.conf`, ignoring comments.
  - `setColorsCommandShape`: `setColors(socket: "unix:/x", conf: "/A/colors.conf")` equals `[kitten, "@", "--to", "unix:/x", "set-colors", "--all", "--configured", "/A/colors.conf"]`.
- [ ] **Step 2:** Run `scripts/test.sh`. Expect these to fail.
- [ ] **Step 3:** Implement.
  - `installSupportFiles` takes the theme and writes `kitty.conf` as the template plus `kittyColorsConf(theme)`.
  - `applyTheme` writes `<support>/kitty-colors.conf` and runs `setColors` only when `socket` is non-nil. It ignores the result: kitty may be gone.
  - Keep the template's non-colour lines unchanged.
- [ ] **Step 4:** Run `scripts/test.sh`. Expect everything to pass.
- [ ] **Step 5:** Commit `feat: console colours follow the theme`.

### Task 3: Theme-aware interface, menu and showcase

**Files:**
- Modify:
  - `Sources/Nell/PlumNight.swift` (`PN` reads the current theme)
  - `Sources/Nell/NellModel.swift` (`theme`, `setTheme`)
  - `Sources/Nell/CompanionView.swift` (Settings submenu, rebuild on theme change)
  - `Sources/Nell/AppDelegate.swift` (start from the saved theme, pass it to `installSupportFiles`)
  - `Sources/NellCore/Showcase.swift` (`.theme` action and visual, `themes` scene)
  - `Sources/Nell/ShowcaseRunner.swift`
- Test: `Tests/NellCoreTests/ShowcaseTests.swift`

**Interfaces:**
- Consumes: Task 1's `Themes` and `SavedState.theme`, and Task 2's `KittyController.applyTheme`.
- Produces:
  - `NellModel.theme: Theme` (`@Published private(set)`, initialised from `Themes.named(state.theme)`);
  - `NellModel.setTheme(_ name: String)`, which sets `PN.theme`, publishes, saves `state.theme` and calls `kitty.applyTheme`;
  - `Showcase.Action.theme(String)` and `Showcase.Visual.theme(String)`.

- [ ] **Step 1: Write the failing test** `showcaseVisitsEveryTheme`. Some scene named `themes` has a step with `.theme(name)` and shows `.theme(name)` for every name in `Themes.all`. The same scene shows `.bubble` of at least the user and Chat kinds, and `.gauge(.session, .high)`.
- [ ] **Step 2:** Run `scripts/test.sh`. Expect it to fail.
- [ ] **Step 3:** Implement.
  - **`PN`:** its colours become computed statics reading `@MainActor static var theme: Theme` (default Plum Night). The `color(_:)` helper reads `theme.palette`. The cached `Icon` images must still tint correctly; check how `Icon` applies `ink` and don't cache a colour.
  - **Redraw:** the root `CompanionView` content takes `.id(model.theme.id)`, so every view rebuilds with the new colours on a switch.
  - **Menu:** in the existing `.contextMenu`, add `Menu("Settings") { ForEach(Themes.all) { t in Button { model.setTheme(t.id) } label: { … a checkmark when current … } } }` in the Global Constraints position.
  - **Launch:** `AppDelegate` sets `PN.theme` from `state.theme` before the first view is built, and passes the theme to `installSupportFiles`.
  - **Showcase:** the `themes` scene first sets up a Chat reply, a user message, an approval and the usage chips (5H 85, 7D 60). Then it takes one step per theme. The runner's `.theme` action calls `model.setTheme`, which is safe because the sandbox has no kitty socket. The check compares `model.theme.id`.
- [ ] **Step 4:** Run `scripts/test.sh`, then `bash scripts/showcase.sh themes`. Expect all tests to pass and no MISMATCH lines. Screenshot each theme step to `.superpowers/brainstorm/30670-1794742755/content/t-<theme>.png` (lowercase, hyphenated), using `screencapture -x -o -l <windowID>` on the showcase pid. Look at every screenshot for any element still in Plum Night colours in a non-Plum theme. That is Review Focus 1, and a cached colour is the cause to fix.
- [ ] **Step 5:** Commit `feat: colour themes in the right-click Settings menu`.
- [ ] **Step 6 (controller, user gate):** Show the user the five screenshots. Record the round in `docs/notes/2026-11-14-nell-v3-art-review-log.md`. After acceptance, merge as the user directs and relaunch their Nell.
