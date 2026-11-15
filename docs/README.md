# Nell docs

Every document is named `YYYY-MM-DD-<topic>-<type>.md` and filed by what it is.

| Folder | What goes here |
|---|---|
| [specs/](specs/) | Approved designs: what to build and why |
| [plans/](plans/) | Implementation plans written from a spec |
| [notes/](notes/) | Findings and records from doing the work: spikes, build ledgers |
| [research/](research/) | One folder per research question, holding `report.md` and its `notes/` |

## Index

### v1: first build (2026-11-14)

| Type | Document | What it is |
|---|---|---|
| Spec | [2026-11-14-nell-v1-design.md](specs/2026-11-14-nell-v1-design.md) | The approved v1 design: floating companion, Chat and Code modes, kitty, hooks, approvals |
| Plan | [2026-11-14-nell-v1-plan.md](plans/2026-11-14-nell-v1-plan.md) | The 9-task build plan for v1 |
| Notes | [2026-11-14-pipeline-spike-findings.md](notes/2026-11-14-pipeline-spike-findings.md) | Tested facts about Claude Code hooks and kitty that the build relies on |
| Notes | [2026-11-14-nell-v1-build-ledger.md](notes/2026-11-14-nell-v1-build-ledger.md) | Every decision made during the build, the review fixes, and deferred minor issues |
| Research | [2026-11-14-companion-landscape/report.md](research/2026-11-14-companion-landscape/report.md) | Survey of existing Claude and agent desktop companions, and what it means for Nell |

### v2: Kitty + Nell console bubble (2026-11-14)

| Type | Document | What it is |
|---|---|---|
| Spec | [2026-11-14-nell-v2-console-design.md](specs/2026-11-14-nell-v2-console-design.md) | Kitty inside Nell's console bubble, placement and no-overlap layout, ⌥ to grab, Departure Mono (approved) |
| Plan | [2026-11-14-nell-v2-console-plan.md](plans/2026-11-14-nell-v2-console-plan.md) | The 7-task build plan for the console bubble |
| Notes | [2026-11-14-kitty-panel-spike-findings.md](notes/2026-11-14-kitty-panel-spike-findings.md) | Tested facts about running kitty as a borderless panel inside Nell's console bubble |
| Notes | [2026-11-14-nell-v2-build-ledger.md](notes/2026-11-14-nell-v2-build-ledger.md) | Every decision made during the v2 build, its checks, and the final review |

### v3: pixel design round (2026-11-14)

| Type | Document | What it is |
|---|---|---|
| Spec | [2026-11-14-nell-v3-pixel-design.md](specs/2026-11-14-nell-v3-pixel-design.md) | v3 design round: Plum Night interface, 128 px master sprite, faces, animations, emoji reactions (approved) |
| Plan | [2026-11-14-nell-v3-pixel-plan.md](plans/2026-11-14-nell-v3-pixel-plan.md) | The 10-task plan: signal spike, logic, Plum Night UI, art (review-gated), compositor |
| Notes | [2026-11-14-nell-v3-art-review-log.md](notes/2026-11-14-nell-v3-art-review-log.md) | Every round of the user's visual review of the interface and sprites, with their notes and acceptance |
| Notes | [2026-11-14-design-system-review-findings.md](notes/2026-11-14-design-system-review-findings.md) | Review of `concept-nell-design-system/` (Plum Night): what's usable, what conflicts with v2, and fixes needed |
| Notes | [2026-11-14-nell-v3-signal-spike-findings.md](notes/2026-11-14-nell-v3-signal-spike-findings.md) | v3 signal spike: test-result events, context usage in the transcript, `/clear` and `/compact` events, documented usage-limit signals |
| Notes | [2026-11-15-nell-v3-build-ledger.md](notes/2026-11-15-nell-v3-build-ledger.md) | Every ruling, review fix and deferred minor from the v3 build, the post-check tasks and the final review |
| Notes | [2026-11-15-nell-v3-performance-findings.md](notes/2026-11-15-nell-v3-performance-findings.md) | CPU and RAM stress test of the v3 build (idle, busy, burst), with the sprite-sheet decode fix |

### Usage chips (2026-11-15)

| Type | Document | What it is |
|---|---|---|
| Spec | [2026-11-15-nell-usage-chips-design.md](specs/2026-11-15-nell-usage-chips-design.md) | 5-hour and weekly usage as two gauge chips above Chat and Code, fed by a status line in Nell's own settings, plus the tired face over 90% (approved) |
| Plan | [2026-11-15-nell-usage-chips-plan.md](plans/2026-11-15-nell-usage-chips-plan.md) | The 4-task plan: status-line spike, usage logic, socket wiring, gauge chips and showcase |
| Notes | [2026-11-15-nell-usage-statusline-findings.md](notes/2026-11-15-nell-usage-statusline-findings.md) | Status-line spike: `rate_limits` shape (`resets_at` is epoch seconds), absent before the first reply, runs in hidden windows and with Chat's args |
| Notes | [2026-11-15-nell-usage-chips-build-ledger.md](notes/2026-11-15-nell-usage-chips-build-ledger.md) | Every ruling, review fix and deferred minor from the usage-chips build, the final review and its fix wave |

### Colour themes (2026-11-15)

| Type | Document | What it is |
|---|---|---|
| Spec | [2026-11-15-nell-themes-design.md](specs/2026-11-15-nell-themes-design.md) | Five dark colour themes (Plum Night, Moss, Tide, Ember, Slate) picked from a Settings submenu on her right-click menu, recolouring the interface and the console |
| Plan | [2026-11-15-nell-themes-plan.md](plans/2026-11-15-nell-themes-plan.md) | The 3-task plan: theme data and saving, console colours, theme-aware interface with the Settings menu and showcase |
| Notes | [2026-11-15-nell-themes-build-ledger.md](notes/2026-11-15-nell-themes-build-ledger.md) | Every ruling, review fix and deferred minor from the colour-themes build, the final review and its fix wave |

### Full codebase review (2026-11-15)

| Type | Document | What it is |
|---|---|---|
| Notes | [2026-11-15-codebase-review-findings.md](notes/2026-11-15-codebase-review-findings.md) | Every red-team-confirmed finding from the four-slice review, its severity and its root fix, plus what's left unfixed and why |
| Plan | [2026-11-15-review-fixes-plan.md](plans/2026-11-15-review-fixes-plan.md) | The 4-package plan to fix them: IPC, kitty and processes, session state, interface |
| Notes | [2026-11-15-review-fixes-build-ledger.md](notes/2026-11-15-review-fixes-build-ledger.md) | Every ruling, review, fix round and deferred minor from fixing the review, including the red team on the fixes |

### 1.0 release (2026-11-15)

| Type | Document | What it is |
|---|---|---|
| Spec | [2026-11-15-nell-release-design.md](specs/2026-11-15-nell-release-design.md) | Terminal parity (login shell, your skills/hooks/status line), Chat as full Claude Code, finding or installing kitty and Claude Code, MIT/CC BY-NC licences, icon, universal DMG, stylised README |
| Plan | [2026-11-15-nell-release-plan.md](plans/2026-11-15-nell-release-plan.md) | The 5-task plan: parity, dependencies, packaging, live verification, README |
