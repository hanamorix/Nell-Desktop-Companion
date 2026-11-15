# Nell usage chips build ledger (2026-11-15)

Every decision made while building the usage chips (5-hour and weekly gauges, the status line, the tired face), each review's fixes, and the deferred minor issues. Copied from the build's working ledger. Lines starting `Final:` are the whole-branch review and its fix wave.


Spec: docs/specs/2026-11-15-nell-usage-chips-design.md. Branch nell-usage, base 8784fc7 (design) / b446948 (plan).

## Pre-flight

| Tasks | Produces → consumes | Found |
|---|---|---|
| T1 → T2, T3 | `Fixtures/statusline.json` → `usageDecodesFixture`, `statusRouteRepliesWithLineAndReportsReading` | Consistent. T2 tests both resets_at formats regardless of T1's finding. |
| T2 → T3 | `UsageReading.decode/merged/nextReset`, `statusLineText`, `tired`, `face(…tired:)` | Names match. |
| T2 → T4 | `gauge`, `UsageKind`, `UsageLevel` | **Conflict**: T4's `Visual.gauge(UsageKind, UsageLevel)` sits in a `Hashable` enum, but T2 declares `UsageKind: Sendable` only. |
| T3 → T4 | `NellModel.usage`, `usageUpdated(_:)` | Names match; showcase calls usageUpdated directly (no hook server in sandbox) — fine. |
| T1 self | spike only | Uses its own hidden kitty + claude, never Nell's; consistent with constraints (showcase/stress rule is about those tools). |
| T2 self | tests ↔ code | Consistent: 90 → false, 90.5 → true matches "above 90%"; 50/80 → mid matches "50% to 80% inclusive". |
| T3 self | tests ↔ code | `statusScriptGivesUpQuietly` runs a file under Sources/ — path must not depend on cwd. |
| T4 self | scene ↔ coverage test | Scene steps (none, 20/30, 60/70, 85/81, 95/50, reset-passed 95) cover every kind × level and the tired step. Consistent. |

- Ruling: `UsageKind` (and `UsageLevel`) are `Sendable, Hashable` — T4's Visual enum is Hashable — costs nothing if wrong.
- Ruling: `statusScriptGivesUpQuietly` finds the script via `#filePath`, not cwd — swift test's cwd isn't guaranteed — none if wrong.

## Tasks
Task 1: dispatched, BASE b446948
Task 1: implementer DONE 53142f8 (resets_at = epoch seconds int; used_percentage int; startup call lacks rate_limits; hidden yes; chat yes). Review dispatched.
Task 1: review Approved. ⚠️ trailer checked (Opus 5.5 trailer present); untouched-settings claim accepted from report (no diff evidence possible).
Task 1: minor (deferred): fixture scratchpad_dir keeps uid claude-501.
Task 1: minor (deferred): findings don't state rate_limits may be absent permanently for non-subscribers (T2/T3 decode it as optional anyway).
Task 1: complete (commits b446948..53142f8, review clean)
Task 2: dispatched, BASE 53142f8
Task 2: implementer DONE_WITH_CONCERNS a749f8e (190 tests). Ruling: excluding statusline.json from decodesEveryFixture (HookEventTests) is accepted — Task 1's fixture isn't a hook event and the test already excludes kitty-/sprite- files the same way — cost if wrong: one fixture skipped by a sweep test, still decoded by usageDecodesFixture.
Task 2: review Approved. ⚠️ fixture values verified by controller (46/1794760800, 31/1795226400 in statusline.json).
Task 2: minor (deferred): Int(w.used.rounded()) traps on absurd doubles (1e30) — real payloads 0–100; candidate for the final fix wave (clamp at decode).
Task 2: minor (deferred): text rounds while level/tired use raw value (49.9 shows "50%" but is leaf) — matches spec wording.
Task 2: minor (deferred): negative used shows "-3%" in tooltip.
Task 2: note: statusLineText takes no `now` — fine, the server formats the reading it just received, which is fresh by construction.
Task 2: complete (commits 53142f8..a749f8e, review clean)
Task 3: dispatched, BASE a749f8e
Task 3: 
Ruling: NellModel publishes weeklyGauge/sessionGauge (recomputed in refresh, assigned only on change) in addition to `usage` — the plan's view would read `usage` + Date(), which never redraws when a reset passes with `usage` unchanged — cost if wrong: two extra published properties.
Ruling: one wake timer fires at min(reaction expiry, usage.nextReset) — spec's "reset passed → 0%" must happen without an event — cost if wrong: an extra refresh per reset.
Task 3: implementer DONE 7ec5257 (194 tests; model wiring compile-checked only).
Task 3: review Approved. Ruling (⚠️): Nell's statusLine overriding the user's own in Code sessions is intended — the spec chose it and the user has no statusLine of their own — cost if wrong: they'd lose a custom line they later add (revisit then).
Task 3: minor (deferred): no test for the -m 0.3 cap against a socket that accepts but never replies.
Task 3: minor (deferred): usageUpdated calls refresh() even when merged == usage.
Task 3: minor (deferred): redundant `if let r = request` at HookServer.swift:227.
Task 3: complete (commits a749f8e..7ec5257, review clean)
Task 4: dispatched, BASE 7ec5257
Task 4: Ruling: view and showcase check read model.weeklyGauge/sessionGauge, not usage+Date() — follows the Task 3 ruling — none if wrong. Ruling: Step 6 (user gate) stays with the controller.
Task 4: implementer DONE 5982967 (196 tests, 0 MISMATCH, 6 screenshots). Ruling: usage = nil in resetForShowcase accepted — scenes start fresh per Showcase.Scene contract — none.
Task 4: review Needs fixes: Important 1 = usage chips 38×30 vs ModeChip 32×30.
Ruling: regrade Minor 4 (clicking a gauge makes the panel key, taking the keyboard from the front app) to Important — by effect it is the focus-stealing class the user reported in v3 and had fixed — cost if wrong: one rect added to the existing exception.
Ruling: regrade Minor 1 (meter differs from approved option A: no outline top line, 4 pt fill under 4 pt empty) to Important, with Minor 2 (dead .padding) folded in as the same code — the user approved option A as drawn and signs off at Step 6 — cost if wrong: a few lines of styling.
Task 4: minor (deferred): container .accessibilityLabel without .accessibilityElement(children: .ignore) may let VoiceOver read the inner texts separately.
Task 4: fix round 1/5 (3 addressed, 0 open — chip width, option-A meter, passive click; commits 5982967..7bf97b2)
Task 4: complete (commits 7ec5257..7bf97b2, review clean). Step 6 (user gate) pending with controller.
Final review: With fixes. 0 Critical; Important: (1) tooltip never seen working in an inactive non-activating panel, (2) build ledger must be filed in docs/notes, (3) Step 6 gate open.
Final: Ruling: Important 1 (tooltip) — verified at the user gate by hovering the showcase copy with another app frontmost; if it fails, switching to the house hover-rects mechanism is a gate-feedback change — cost if wrong: one more small change after sign-off.
Final: Ruling: Important 2 — controller files docs/notes/2026-11-15-nell-usage-chips-build-ledger.md at finish, as for v3 — none.
Final: Ruling: fix wave takes Minors 1 (clamp non-finite/huge/negative used at decode; also clears T2 "-3%"), 2 (merge keeps fresher window: same resetsAt → higher used; earlier newer resetsAt → keep old), 3 (cache DateFormatters — permanent 1 Hz idle work against the idle-CPU constraint), 4 (delete the redundant reset wake timer: the 1 Hz tick already refreshes; supersedes Task 3 wake ruling), 5 (accessibilityElement(children: .ignore)) — all small, each user-visible or constraint-related — cost if wrong: a few lines.
Final: minor (deferred): T1 fixture uid claude-501; T1 non-subscriber note; T2 rounding vs level; T3 no slow-socket test; T3 redundant `if let r`.
Final fix wave: DONE 539971e (202 tests).
Final fix wave re-review: Clean (5/5 addressed).
Final: minor (deferred): UsageReading.nextReset(after:) now has no production caller (only its test) after removing the reset wake.
Final: minor (deferred): clock still builds a Calendar per call (formatters cached).
Final: minor (deferred): a malformed far-future resetsAt pins a window until a later one arrives (cost of the monotonic merge).
Showcase copy launched for the user gate (pid 3927, scene usage).
Task 4 Step 6: user signed off ("Both work": look and hover tooltip); art review log round recorded.
