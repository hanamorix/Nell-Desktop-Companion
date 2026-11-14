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
