# Nell colour themes build ledger (2026-11-15)

Every decision made while building the five colour themes (Plum Night, Moss, Tide, Ember, Slate), each review's fixes, and the deferred minor issues. Copied from the build's working ledger. Lines starting `Final:` are the whole-branch review and its fix wave.


Spec: docs/specs/2026-11-15-nell-themes-design.md (user said "Just dive in with your picks": every design choice is Claude's). Branch nell-themes from main@2f28d75.
Note: spec berries for Tide (#c45a6a→#ac4a5a) and Slate (#c25b63→#ab4c55) darkened before commit to pass the snow/berry readability rule (measured 3.91 and 4.00 vs Plum Night 4.95).

## Pre-flight

| Tasks | Produces → consumes | Found |
|---|---|---|
| T1 → T2 | `Theme.ansi`, `palette` → `kittyColorsConf` | Consistent. |
| T1 → T3 | `Themes.all/named`, `SavedState.theme` → model init, menu, showcase | Consistent. |
| T2 → T3 | `KittyController.applyTheme(_:)`, `installSupportFiles(theme)` → `setTheme`, AppDelegate | `installSupportFiles` signature changes in T2 but its caller (AppDelegate) is T3's file. |
| T1 self | tests ↔ data | Hue ranges checked by controller against all five palettes (leaf 92–139°, gold 37–44°, berry 350–7°): pass. |
| T2 self | plumNightKittyConfUnchanged vs moving the colour block | Consistent if the template keeps non-colour lines. |
| T3 self | `.id(theme)` rebuild vs `.passive()/.interactive()` preference rects | Rebuild re-publishes preference rects — fine. |

- Ruling: T2 updates the `installSupportFiles` caller in AppDelegate itself (passing `Themes.named(state.theme)`) so T2 compiles on its own; T3 only adds `PN.theme` setup — none if wrong.

## Tasks
Task 1: dispatched, BASE 21a1ffe
Task 1: implementer DONE e00a53b (214 tests; extra ANSI-readability test added; no spec nudges).
Task 1: review Approved. Ruling (⚠️): the palette has 22 keys, not "21" as the spec/plan say — the tests compare against PlumNight.palette, so the code is right and the docs' count is a typo — none.
Task 1: minor (deferred): lum() parses malformed hex as 0 silently (format test covers it).
Task 1: minor (deferred): no test pins ANSI hues to their slots (reviewer verified by script).
Task 1: minor (deferred): Plum Night exemption in consoleColoursAreReadableOnTheWell has no comment.
Task 1: complete (commits 21a1ffe..e00a53b, review clean)
Task 2: dispatched, BASE e00a53b
Task 2: implementer dispatched.
Ruling: supersedes the pre-flight ruling — installSupportFiles is called inside KittyController (not AppDelegate), so KittyController holds the theme (property or parameter, implementer's smaller choice); Task 3 sets it from saved state — none if wrong.
Ruling: Plum Night's console colours stay pinned to today's exact kitty.conf lines via a verbatim copy in the test once the colour block leaves the template — keeps Review Focus 5 — none.
Task 2: implementer DONE 2c390a0 (216 tests; theme property on KittyController; set-colors untested live).
Task 2: review Approved (set-colors flags confirmed against kitten --help).
Task 2: minor (deferred): the cyan/dim-text/selection rationale comments left kitty.conf and live nowhere now.
Task 2: minor (deferred): applyTheme runs kitten synchronously on main (same as other KittyController commands; stale socket fails fast).
Task 2: complete (commits e00a53b..2c390a0, review clean)
Task 3: dispatched, BASE 2c390a0 — must set KittyController.theme before installSupportFiles.
Task 3: implementer dispatched.
Task 3: implementer DONE b7e120e (217 tests, 0 MISMATCH, 5 screenshots). Concerns: menu checkmark unverified live; theme switch drops bar focus (.id rebuild); approval bubble shows 'answered in console' in scene.
Task 3: review Needs fixes: Important = approval settled before screenshots, so Allow/Deny never shown in any theme.
Ruling: regrade Minor "Allow highlight hard-coded #c6efb7" to Important — it is literally a Plum Night colour left in other themes (Review Focus 1) — cost if wrong: a few lines.
Ruling: regrade Minor "menu tick is a Label icon, not the native tick" to Important — the menu is the feature the user asked for and its tick is unseen — cost if wrong: switching to Toggle.
Ruling: fold the optional .openConsole step into the same scene edit — the console frame is otherwise never seen in another theme (Review Focus 1) — cost: one step.
Task 3: minor (deferred): showcase doc comment now sits above setTheme; resetForShowcase lost its comment.
Task 3: minor (deferred): a switch drops bar focus, bubble scroll and selection (.id rebuild) — mention at the user gate.
Task 3: minor (deferred): startup theme set in two places (PN.theme in model init, kitty.theme in AppDelegate).
Task 3: fix round 1/5 (4 addressed, 0 open — live approval in scene, theme-derived Allow highlight (Plum Night exact), native Toggle ticks, console step; commits b7e120e..8cbf41e)
Task 3: minor (deferred): submenu tick never seen in a screenshot (probe can't open submenus) — user checks it live at the gate.
Task 3: complete (commits 2c390a0..8cbf41e, review clean). Step 6 (user gate) pending with controller.
Final review: With fixes. 0 Critical. Important: Deny highlight is the theme accent (teal/olive edge on red); minimised strip never shown; build ledger must be in docs/.
Final: Ruling: fix wave = Important 1 (berryHi, Plum Night exact pink-600), Important 2 (minimised-strip step per theme), Minor 1 (comment back on resetForShowcase), Minor 2 regraded (FAILED label uses a berry-family tint outside Plum Night — meaning-colour anti-goal), Minor 3 (kitty.conf `include kitty-colors.conf`, written at install and on switch; re-apply on the kitty-reuse branch), Minor 4 (22-key comment), Minor 5 (lighten plum-500 in Moss/Tide to meet "no harder to read than Plum Night"; record the old/new values), T2 rationale comments restored — each small, user-visible or constraint-related — cost if wrong: a few lines.
Final: Ruling: Important 3 (build ledger in docs/notes) — controller files it with the sign-off, as for usage chips — none.
Final fix wave: DONE cb84190 (219 tests, 0 MISMATCH). plum-500 Moss #56635a→#57645b, Tide #4f5d73→#526076. FAILED ink on wine: Moss 5.00, Tide 4.75, Ember 5.10, Slate 4.82 (Plum Night 6.28).
Final fix wave re-review: Clean (8/8 addressed).
Final: minor (deferred): spec/plan lines still say kitty.conf holds the colours and list six readability pairs (now kitty-colors.conf via include, seven pairs) — controller corrects the spec's console lines with the sign-off commit.
Final: minor (deferred): in the open-console screenshots some older bubbles are mid-fade (showcase timing, not themes).
Task 3 Step 6: user signed off ("Looks good"); art review log round recorded; spec console lines corrected.
