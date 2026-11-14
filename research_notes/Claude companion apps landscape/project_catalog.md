# Desktop companion / pet / mascot / notch apps for AI coding agents: project catalog

All star counts, fork counts, release counts, contributor counts and last-commit dates were pulled from the GitHub REST API (`gh api repos/...`) on **2026-11-14**, unless marked otherwise. "Contrib" counts include anonymous contributors and cap at 100 (shown as 100+). Nothing was installed or run. Feature claims come from each project's README or docs, not from testing.

**Inclusion rule:** a project is in if it has >100 stars OR a last commit on or after about **2026-08-14** (3 months before checking). Entries marked **[lead]** fail both criteria; they are kept only because they were a starting lead or show a notable design. "Last commit" is the default-branch commit date. It can differ from GitHub `pushed_at`: for zzp1221 `pushed_at` is 2026-10-21 but the last commit is 2026-05-26, and for AgentBro it is 2026-10-01 vs 2026-08-03. The last-commit date is the one used here.

## Which projects are actually established (stars, contributors, releases) vs abandoned toy repos?

### Takeaway
Two tiers are clearly established. In the **floating desktop pet** tier, clawd-on-desk leads by a wide margin: 6.7k stars, 100+ contributors, 43 releases, cross-platform Electron, a commit 2 days before checking. In the **notch / Dynamic Island** tier, Open Island (open-vibe-island, 2.1k stars, 60 contributors, 57 releases), Vibe Notch / Claude Island (2.5k stars but quiet since April 2026), Notchi (1k stars) and the paid closed-source Vibe Island lead. Petdex (4.4k stars) is mainly a sprite gallery and CLI built on the Codex Pets format, and it also ships a desktop floater. Most other "claude pet" repos have fewer than 50 stars, one contributor and no recent commits.

### Cited Findings

#### Tier A: established (≥500 stars, multiple contributors, regular releases)

**1. Clawd on Desk** (floating pixel desktop pet) — https://github.com/rullerzhou-afk/clawd-on-desk
- Stats (2026-11-14): 6,741 stars, 714 forks, 100+ contributors, 43 releases (latest v1.6.0, 2026-11-08), last commit 2026-11-12, created 2026-03-18. JavaScript/Electron. Code is AGPL-3.0, but the artwork is "all rights reserved" and separately licensed. — [repo](https://github.com/rullerzhou-afk/clawd-on-desk)
- Platforms: Windows x64/ARM64, macOS (.dmg or `brew install --cask clawd-on-desk`), Linux (.AppImage/.deb), plus Remote SSH and WSL. UI in 7 languages. — [README](https://github.com/rullerzhou-afk/clawd-on-desk)
- Agents: Claude Code, Codex CLI, Copilot CLI, Gemini CLI, Cursor Agent, opencode, Kiro, Qwen, Kimi, Grok Build, DeepSeek Harness and others (29 listed). There is also a "custom HTTP agent" endpoint for anything else. Claude Code and Codex hooks are auto-registered on first launch, and other agents are "one click" in Settings → AI Coding Tools. — [README](https://github.com/rullerzhou-afk/clawd-on-desk)
- How it gets state: agent hooks plus log polling. Codex uses JSONL monitoring as a fallback. Claude Code and CodeBuddy use **HTTP hooks** to a local server on ports 23333–23337, with a dynamic-port fallback discovered via `~/.clawd/runtime.json`. Permission requests go to a `/permission` endpoint. — [state-mapping](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/state-mapping.md), [known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md)
- States: "12 animated states" (idle, thinking, typing, building, subagent groove, multi-subagent juggling, error, happy, notification, sweeping, carrying, sleeping), plus an optional `executing` state for Claude Code's tool-call phase. Other behaviors: eye tracking of the cursor with body lean, a yawn → doze → collapse → sleep sequence after 60 s idle with a startled wake on mouse move, double-click poke and 4-click flail, and a "mini mode" that peeks from the screen edge. — [features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [theme guide](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/guide-theme-creation.md)
- Approvals: yes. Floating Allow/Deny bubble cards, plus agent-native "Always"/rules where the agent supports them. Global hotkeys Ctrl+Shift+Y / Ctrl+Shift+N, registered only while bubbles are visible. Bubbles stack bottom-right and auto-dismiss if you answer in the terminal first. Modes: Ask every time / Question prompts only / Auto-approve (auto-approve downgrades after restart). Each agent can be switched to keep its prompts in its own terminal. — [features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
- Remote: Telegram and Feishu/Lark can Allow/Deny. Slack is notification-only. A read-only LAN mobile PWA is token-gated. — [features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
- Interact back: a Sessions dashboard and a HUD next to the pet, with one-click jump to a session's terminal. "Telegram Direct Send" sends replies into sessions, using Codex's thread queue where available and otherwise falling back to the clipboard without injecting Enter. — [features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md)
- Polish: click-through on transparent pixels, position memory, single-instance lock, auto-start from Claude's SessionStart hook, DND mode, sounds with a 10 s cooldown, quota "Orbit rings" (taken from Claude Code's official status-line `rate_limits` payload, off by default), a private local "Recap", multi-monitor sizing, and a sanitizer for third-party SVGs. — [features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
- Weaknesses: the integration surface is huge, and the known-limitations doc is about 52 KB of per-agent caveats. A dynamic port can break HTTP hooks in CLI sessions that were already running. WSL sessions get no process-exit cleanup. Several agents are state-only. Top open issues on 2026-11-14 include HUD lifecycle bugs (#655, 31 comments), a request for Wayland tiling support (#752), and a request to split "model generating" from "executing tool" (#1018). — [known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md), [issues](https://github.com/rullerzhou-afk/clawd-on-desk/issues)

**2. Open Island (open-vibe-island)** (notch / top-bar control center) — https://github.com/Octane0411/open-vibe-island
- Stats: 2,078 stars, 365 forks, 60 contributors, 57 releases (latest v1.3.2, 2026-11-02), last commit 2026-11-02. Swift (SwiftUI + AppKit), GPL-3.0. It positions itself as an open-source alternative to the paid Vibe Island. — [repo](https://github.com/Octane0411/open-vibe-island)
- Agents and terminals: 15 agents (Claude Code CLI and Desktop, Codex CLI and Desktop, Cursor, Gemini CLI, OpenCode, Kimi, Grok, Hermes, Pi, Qwen, Qoder, Factory, CodeBuddy, ZCode). Jump-back targets the exact terminal tab or pane in Terminal.app, iTerm2, Ghostty, WezTerm, Warp, tmux, Zellij and cmux; VS Code, Cursor, Zed and JetBrains get workspace-level jump. — [README](https://github.com/Octane0411/open-vibe-island)
- State source: hook → `OpenIslandHooks` CLI → Unix socket (JSON line protocol) → in-app BridgeServer. Claude Code also gets "JSONL session discovery" and a status-line bridge for usage. Codex Desktop uses an app-server JSON-RPC connection. Hooks **fail open**: if the app isn't running, agents carry on unaffected. — [README](https://github.com/Octane0411/open-vibe-island), [architecture](https://github.com/Octane0411/open-vibe-island/blob/HEAD/docs/architecture.md)
- Shows: session status, permission requests, questions, completion, usage dashboard, notification sounds. No character or pet; it is a status UI. — [README](https://github.com/Octane0411/open-vibe-island)
- Install: signed and notarized DMG, `brew install --cask open-island`, Sparkle auto-update, hooks managed from Settings. Requires macOS 14+. — [README](https://github.com/Octane0411/open-vibe-island)
- Weaknesses: macOS only, and no mascot or character layer. There are 227 open issues and PRs (GitHub `open_issues_count`). — [repo](https://github.com/Octane0411/open-vibe-island)

**3. Vibe Notch (formerly "Claude Island")** — https://github.com/farouqaldori/vibe-notch (redirects from farouqaldori/claude-island)
- Stats: 2,537 stars, 361 forks, 8 contributors, 6 releases (latest v1.3.2, 2026-04-20), last commit 2026-04-20, created 2025-12-09. Swift, Apache-2.0. — [repo](https://github.com/farouqaldori/vibe-notch)
- It is the **ancestor of much of the notch category**. Buddi credits it for its session monitoring, hooks, buddy characters and chat UI. MioIsland says it is "Forked from Claude Island". Notchi credits it as design inspiration. — [Buddi README](https://github.com/talkvalue/Buddi), [MioIsland README](https://github.com/MioMioOS/MioIsland), [Notchi README](https://github.com/sk-ruban/notchi)
- Features: notch overlay, multi-session monitoring, Allow/Deny from the notch, full chat history with markdown rendering, and auto-installed hooks in `~/.claude/hooks/` that talk over a Unix socket. Claude Code only. macOS 15.6+. — [README](https://github.com/farouqaldori/vibe-notch)
- The README says it is "Actively maintained" and that v1.3 in April 2026 followed a 4-month break, yet no commits have landed since 2026-04-20. It collects anonymous Mixpanel analytics. Open issues include "No session detected" (#11) and the notch getting stuck on "Processing..." after a background Bash command, a PostToolUse-after-Stop race (#98). — [README](https://github.com/farouqaldori/vibe-notch), [issues](https://github.com/farouqaldori/vibe-notch/issues)

**4. Notchi** (notch mascot) — https://github.com/sk-ruban/notchi
- Stats: 1,048 stars, 78 forks, 11 contributors, 19 releases (latest v1.2.7, 2026-09-19), last commit 2026-10-04. Swift, GPL-3.0. — [repo](https://github.com/sk-ruban/notchi)
- State source: shell or Python hook scripts write to a Unix socket at `~/Library/Application Support/Notchi/notchi.sock`, feeding an event parser and a state machine. In the Claude hook (`notchi-hook.sh`), `PermissionRequest` maps to the state `waiting_for_input`. The script uses `timeout=0.5` and exits silently if the socket is absent. That makes it fire-and-forget, so **no Allow/Deny round-trip**: permission requests are shown, not answered. — [README](https://github.com/sk-ruban/notchi), [claude hook script](https://github.com/sk-ruban/notchi/blob/HEAD/notchi/notchi/Resources/notchi-hook.sh)
- Strengths: the most "alive" mascot among the notch apps (emotions, a per-session sprite island), signed builds, and a real community (11 contributors, Windows ports). Weaknesses: needs a MacBook with a notch and macOS 15+; watch-only; sentiment requires your own API key and sends prompts to Anthropic or OpenAI; no custom sprite import found.
- States: thinking, working, permission requests, compaction, errors, completions; sprite states idle, working, sleeping, compacting, waiting. Its unique feature is **prompt sentiment analysis** through an Anthropic or OpenAI API key, which drives the mascot's emotions (happy, elated, sad, neutral, sob). — [README](https://github.com/sk-ruban/notchi)
- Multi-session: "each [session] with its own mascot" on a grass island, drawn from a Claude or Codex sprite family. Open issue #9 ("Only seeing a single sprite even with multiple sessions") suggests this does not always work. — [README](https://github.com/sk-ruban/notchi), [issue #9](https://github.com/sk-ruban/notchi/issues/9)
- Other features: sounds (importable custom sounds, auto-muted when the terminal is focused), 30-day cost and token tracking, Sparkle updates, 6 languages. Requires macOS 15+ and a MacBook with a notch. The sprites were made in Aseprite. Community Windows ports exist (notchi-for-windows, pixel-companion). — [README](https://github.com/sk-ruban/notchi)

**5. MioIsland** (notch, fork of Claude Island) — https://github.com/MioMioOS/MioIsland
- Stats: 544 stars, 67 forks, 12 contributors, 55 releases (latest v3.1.3, 2026-08-13), last commit 2026-10-13. Swift. License shows as NOASSERTION; the README images say CC BY-NC 4.0 (no commercial use). — [repo](https://github.com/MioMioOS/MioIsland)
- The README is image-only. Alt text describes status monitoring, a session list, Allow/Deny permissions, "Buddies", a pixel cat, and 8-bit sounds. Architecture: hook events go to a Unix socket at `/tmp/codeisland.sock`, then `cmux send` handles remote launch. A companion iPhone app, "Code Light", syncs session state both ways with the Mac and supports remote launch. Install via `brew install xmqywx/codeisland/codeisland`. — [README](https://github.com/MioMioOS/MioIsland)
- The Chinese README adds:
  - The collapsed notch shows a pixel cat whose **color encodes state**: purple thinking, cyan tool, amber approval, green done, red error.
  - Approvals show a **code diff preview** with one-click allow/deny.
  - AskUserQuestion options appear as clickable chips, with multi-select and custom input.
  - Integrates with the `/buddy` system (18 species, 5 stats, rarity, rendered as ASCII pixel art).
  - Per-event 8-bit sounds, each toggleable.
  - Live Edit theming (color, font, width, position).
  - A **plugin marketplace** at miomio.chat.
  - The Code Light iPhone app (App Store) can **send messages and slash commands to a specific terminal** and start new sessions that the Mac launches. — [README.zh-CN](https://github.com/MioMioOS/MioIsland/blob/HEAD/README.zh-CN.md)
- Strengths: the richest interactive notch app found (diff approvals, answer chips, phone remote with send). Weaknesses: non-commercial license; the English README is all images; Claude Code + Codex only; Code Light is unavailable in mainland China, per the README.

**6. Petdex** (pet gallery + CLI + desktop floater) — https://github.com/crafter-station/petdex
- Stats: 4,364 stars, 217 forks, 42 contributors, 39 releases (latest desktop-v0.9.2, 2026-09-28), last commit 2026-10-10. TypeScript (web, CLI); the desktop app uses the Zig-based "Native SDK" from vercel-labs. — [repo](https://github.com/crafter-station/petdex), [desktop package](https://github.com/crafter-station/petdex/tree/HEAD/packages/petdex-desktop-native)
- What it is: a web gallery at petdex.dev, an `npx petdex install <slug>` CLI, and a desktop app for macOS, Linux and Windows. The desktop app's hook server runs in-process on `127.0.0.1:7777`, with no WebView or Node sidecar. It also recovers sessions from Codex rollouts, Claude transcripts and Gemini chats, using directory watches plus polling. — [README](https://github.com/crafter-station/petdex), [desktop package](https://github.com/crafter-station/petdex/tree/HEAD/packages/petdex-desktop-native)
- The desktop app has 9 animation states and scans both `~/.petdex/pets` and `~/.codex/pets`. Agents connect with one click in Settings. — [desktop package](https://github.com/crafter-station/petdex/tree/HEAD/packages/petdex-desktop-native), [README](https://github.com/crafter-station/petdex)
- It runs the de facto **sprite ecosystem**: a public `petdex.dev/api/manifest` API, and "21 open-source and source-available projects already build on these" formats. petdex-cc's badge claims more than 1,569 pets. — [README](https://github.com/crafter-station/petdex), [petdex-cc](https://github.com/devnomad-byte/petdex-cc)
- I found no evidence in the README that the desktop app handles approvals. — [README](https://github.com/crafter-station/petdex)
- Strengths: the biggest art catalog and a stable public manifest API, so other apps build on it; cross-platform native desktop app; transcript-based recovery of sessions it didn't see start. Weaknesses: the desktop app is secondary to the gallery; watch-only as far as documented; the native desktop is described as "Rewrite slice 1" (early).

**7. Vibe Island** (commercial, closed source) — https://vibeisland.app, community repo https://github.com/vibeislandapp/vibe-island
- Community repo: 163 stars, no releases, 1 contributor (issues and discussions only). The update feed repo edwluo/vibe-island-updates has 92 stars and was pushed 2026-11-14. — [repo](https://github.com/vibeislandapp/vibe-island), [gh search](https://github.com/edwluo/vibe-island-updates)
- Claims: 25 agents and 20 terminals, approvals from the notch, one-click answers to questions, Markdown plan review with feedback, usage limits, SSH remote, zero-config, native Swift using under 50 MB RAM. Install with `brew install --cask vibe-island`. — [README](https://github.com/vibeislandapp/vibe-island)
- Price: about $19.99 per Mac as a one-time purchase, with a 2-day trial (per search summaries of the official license page and reviews; I did not check the official page directly). — [vibeisland.app](https://vibeisland.app/), [vibecoding.app review](https://vibecoding.app/blog/vibe-island-review)
- Strengths: the broadest agent and terminal coverage claimed, plan review, the benchmark several open-source clones position against. Weaknesses: paid, closed, macOS-only, no character layer; claims can't be audited.

#### Tier B: active, smaller (100–500 stars, or clearly active)

| Project | Stars / last commit / releases / contrib | Form factor & tech | State source | Approvals | Notes |
|---|---|---|---|---|---|
| [agent-notch](https://github.com/realfishsam/agent-notch) | 313 / 2026-07-21 / 0 / 1. **One-day drop**: created and last committed the same day, so stars do not mean maintenance. | macOS notch, single `main.swift`, MIT | **No hooks**: polls every 3 s, using `ps` + `lsof` to map processes to transcripts and reading `~/.claude/projects/*/*.jsonl` and `~/.codex/sessions/**` | No | A mascot walks beside the notch, using official Codex Pets sheets for Codex. Its own README admits a "~30 s afterglow" (busy is inferred from transcript write times). Swap pets with `echo dewey > ~/.config/agent-notch/pet`. — [README](https://github.com/realfishsam/agent-notch) |
| [AgentBro](https://github.com/shirenchuang/agentbro) | 166 / 2026-08-03 / 35 / 9 | Floating "island" console, Rust (Tauri), macOS + Windows MVP, Apache-2.0 | Hooks to a local Unix socket (TCP on Windows); Hook Doctor | Yes, plus answers, plan confirm and quick reply | Also manages Skills, MCP, plugins, API provider switching and SSH hosts. Has a "pet market" (宠物市场) and multi-theme support. Can forward to DingTalk/Feishu webhooks. — [README](https://github.com/shirenchuang/agentbro) |
| [Codex Pacer](https://github.com/RyanZhangNTU/codex-pacer) | 154 / 2026-11-14 / 43 / 4 | Dynamic Island, Swift, Mac + Windows, MIT, notarized | "Reads the logs your agents already write" | Turns amber when approval is needed; jump to the app | Per-task progress rings, quota pace forecasts, SSH/WSL/cloud tasks. — [README](https://github.com/RyanZhangNTU/codex-pacer) |
| [OpenPets](https://github.com/alterhq/openpets) | 109 / 2026-05-14 / 11 / 1 | macOS desktop pet + menu bar, Swift, MIT | **MCP server** at `http://127.0.0.1:3001/mcp`, plus CLI and the OpenPetsKit Swift SDK; agents call `notify` / `play_pet_animation` | No (planned: "action buttons") | Agent-driven, not hook-driven. Threaded message bubbles keyed by `threadId`; Codex Pets 8×9 atlas support; quota "clouds". Strength: one shared pet for many tools, with an embeddable SDK. Weakness: relies on the agent choosing to call the tools; stale since May. — [README](https://github.com/alterhq/openpets) |
| [claude-pets (alvinunreal)](https://github.com/alvinunreal/claude-pets) | 105 / pushed 2026-05-10 / created 2026-05-04 | TypeScript | "Claude Code integration for OpenPets: automatic desktop pet status updates with one-command setup" | Not read | Not read | An add-on that drives OpenPets from Claude Code hooks; stale. README not read. — [repo](https://github.com/alvinunreal/claude-pets) |

#### Tier C: small but notable or recently active (<100 stars)

| Project | Stars / last commit / releases / contrib | Tech | State source | Approvals | Chat / send | Notes |
|---|---|---|---|---|---|---|
| [Buddi](https://github.com/talkvalue/Buddi) | 92 / 2026-08-22 / 7 (v0.1.6) / 8 (meets the activity cutoff narrowly) | macOS notch, Swift, GPL-3.0, built on boring.notch + Claude Island | Hooks → Unix socket | Yes | **Yes**: "View full conversation history … send messages back" | Revives Claude Code's `/buddy` (which, per the README, Anthropic removed in v2.1.97) with 18 species and procedural eyes, hats, rarity and stats. Also does music player, calendar, HUD, file shelf. `brew install --cask talkvalue/buddi/buddi`. — [README](https://github.com/talkvalue/Buddi) |
| [Hopet](https://github.com/BinaryFroggy/Hopet) **[lead]** | 63 / 2026-07-22 / 4 (v0.2.0) / 1 | macOS floating NSPanel + notch bar, Swift, MIT | Hooks → `hopet-emit` CLI → Unix socket with length-prefixed JSON | **Yes**: Allow / Deny / "hand to terminal", plus AskUserQuestion answer cards and plan approval, answered back through the held hook socket | Structured answers only | 8-state machine with an explicit priority order. **Imports Codex Pets** (v1 8×9 and v2 8×11) or 8 GIFs. Ad-hoc signed DMG (Gatekeeper workaround needed), Apple Silicon only. — [README](https://github.com/BinaryFroggy/Hopet), [hooks doc](https://github.com/BinaryFroggy/Hopet/blob/HEAD/DevDocs/hooks-and-priority.md) |
| [claudlet](https://github.com/YeeDochi/Claudlet) (PyPI `claudlet`) | 17 / 2026-11-03 / 34 (v2.7.0) / 4 | Python + Qt (PyQt6), best on KDE Plasma; also Windows and macOS | Hooks in `~/.claude/settings.json` and `~/.codex/hooks.json`, plus a `/claudlet` skill | Shows a "waiting" pose; I found no Allow/Deny in the README | **Yes**: a chat window types into the session (KDE via Konsole DBus; macOS "notes only"). Optional "Creature answers first" mode makes a one-shot side call | Pet perches on window titlebars. A hatted companion appears per subagent (up to 3). A VR visor appears in bypass mode. Creatures are Python packages; `/claudlet make <description>` generates one. Can fetch buried windows. `pipx install claudlet && claudlet-install`. — [README](https://github.com/YeeDochi/Claudlet) |
| [EchoIsland](https://github.com/FunplayAI/EchoIsland) **[lead]** | 78 / 2026-06-18 / 5 / 1 | Tauri + Rust, Windows-first, macOS experimental, MIT | TCP IPC + HTTP receiver | Yes (approvals + questions) | Shows latest prompt and reply | Session snapshot and recovery. — [README](https://github.com/FunplayAI/EchoIsland) |
| [QuotaView](https://github.com/Duoasa/QuotaView) | 62 / 2026-11-13 / 38 / 2 | Swift Dynamic Island + Windows edition | "local APIs, session records, hooks, or plugins" | **Yes** for Codex, Claude Code and DSH; shows command, cwd, reason and scope before deciding | Lists "replies" for some agents | Quota plus approvals; Cursor has no permission reminders. Strength: a very active release cadence. — [README](https://github.com/Duoasa/QuotaView) |
| [clawd-stickers](https://github.com/alwinecor/clawd-stickers) | 61 / 2026-11-12 / 0 / 2 | Python/Pillow-generated GIFs | n/a | n/a | n/a | 40 Clawd stickers, also packaged as the "Clawd Dev Life" **clawd-on-desk community theme**, with variants for 1, 2 and 3+ sessions, light and dark assets, and mini mode. Shows clawd-on-desk's theme ecosystem is real. — [README](https://github.com/alwinecor/clawd-stickers) |
| [agent-isle](https://github.com/DevLab-Technologies/agent-isle) | 45 / 2026-11-01 / 10 / 2 | Swift notch | **Hook-free** monitoring from each tool's own history (`~/.claude/projects/`, `~/.cursor/chats`); approvals need an opt-in hook | **Yes**: inline diff with Deny ⌘N / Allow ⌘Y for Claude Code and Cursor | No | Monitor / Approve / Ask filter tabs. Strength: the hook-free default lowers install friction. — [README](https://github.com/DevLab-Technologies/agent-isle) |
| [Claude Pet Companion (zzp1221)](https://github.com/zzp1221/claude-code-pet) **[lead]** | 44 / 2026-05-26 / 1 / 1 | Tauri + React, Windows | Hooks run `exe --hook`, which writes `~/.claude/pet-companion/runtime/state.json`; the overlay polls the file | Visible prompt bubble only | `/pet` slash command launches it; `/pet <desc>` runs a pet-creation workflow | Auto-syncs `~/.codex/pets`; backs up settings.json before writing. — [README](https://github.com/zzp1221/claude-code-pet) |
| [VibeHub](https://github.com/mtunique/VibeHub) **[lead]** | 38 / 2026-04-18 / 3 / 6 | Swift Dynamic Island | Hooks (Claude Island lineage) | Yes | Chat history view | Claude Code + OpenCode; stale. — [README](https://github.com/mtunique/VibeHub) |
| [ClawdGotchi](https://github.com/stevysmith/clawdgotchi) **[lead]** | 37 / 2026-01-15 / 1 / 1 | Electron + React menu bar | Python hook → Unix socket | No | No | One crab per session, with a repo-hashed accessory. Tamagotchi stats come from **git health** (commit recency, uncommitted files, presence of CLAUDE.md and tests). **Abandoned**: a single commit day. — [README](https://github.com/stevysmith/clawdgotchi) |
| [notchify](https://github.com/kikudjira/notchify) **[lead]** | 24 / 2026-07-23 / 36 / 1 | Swift notch, Homebrew tap | Hooks (`UserPromptSubmit`, `PostToolUse`, `Stop`, `Notification`, `PermissionRequest`) plus a shell `claude()` wrapper for start/bye animations | No (waiting animation) | No | Sounds per state in JSON; supports multiple `CLAUDE_CONFIG_DIR` targets. — [README](https://github.com/kikudjira/notchify) |
| [Claude Petty](https://github.com/caigee-cmd/claude-petty) **[lead]** | 17 / 2026-05-19 / 15 / 1 | Swift menu bar | **Passive**: reads `~/.claude/projects/`, no hooks | No | No | 25+ mascots in 8 sizes; CSV/JSON export. — [README](https://github.com/caigee-cmd/claude-petty) |
| [petdex-cc](https://github.com/devnomad-byte/petdex-cc) **[lead]** | 16 / 2026-05-14 / 0 / 2 | Electron via npm | Claude Code hooks | No | No | Gamified 8-level progression with HMAC-signed state; Claude-generated speech bubbles; uses Petdex pets. — [README](https://github.com/devnomad-byte/petdex-cc) |
| Agentic-Desktop-Pet | 343 / 2026-01-10 / 6 (last 2025-02) / 1 | Python | Not read | Not read | Not read | An LLM pet with memory and emotion that predates this category; **stale**. — [repo](https://github.com/jihe520/Agentic-Desktop-Pet) |
| [nom-pet](https://github.com/dylan-labs/nom-pet) **[lead]** | 58 / pushed 2026-05-26 | TypeScript desktop pet | **Tails JSONL** (`~/.claude/projects/*.jsonl`, `~/.codex/sessions/**`) for token usage only | No | Click-to-talk bubbles (local templates, optional LLM) | Gamified: the pet "eats the tokens you burn". Uses Petdex skins (`npx petdex install`). Wanders, sleeps after 30 min idle, `⌘⌥N` summons it to the current screen. — [README](https://github.com/dylan-labs/nom-pet) |
| [Agent-desktop-pet (shicheng5589-oss)](https://github.com/shicheng5589-oss/Agent-desktop-pet) | 30 / pushed 2026-10-25 | Python, Windows, **Live2D** | Local read-only, no network (per description) | Not read | Not read | Expressions follow 12 agents' states. README not read. — [repo](https://github.com/shicheng5589-oss/Agent-desktop-pet) |
| [petpack](https://github.com/MingfengHong/petpack) **[lead]** | 45 / pushed 2026-07-13 | Rust | n/a | n/a | n/a | Turns Codex/Petdex pet packs into standalone desktop pet apps. — [repo](https://github.com/MingfengHong/petpack) |
| [clawd-on-mobile](https://github.com/Bynlk/clawd-on-mobile) **[lead]** | 37 / pushed 2026-07-15 | JavaScript | — | — | — | clawd-on-desk sister fork with a native Android app. — [repo](https://github.com/Bynlk/clawd-on-mobile) |

#### Leads that could not be verified
- **ClaudePet (qaz61328/claudepet)**: `gh api repos/qaz61328/claudepet` returns 404 on 2026-11-14, and the owner lookup also returned nothing. The repo appears deleted, renamed or private. A search summary of an ecosyste.ms mirror describes it as a macOS Swift pet (macOS 13+, needs `jq`) that **replaces Claude Code permission prompts with clickable speech bubbles**, chatters through an LLM when idle, and uses a shell wrapper to launch with every `claude` call. The ecosyste.ms page returned 403 to direct fetch, so this is unconfirmed. — [ecosyste.ms entry](https://awesome.ecosyste.ms/projects/github.com%2Fqaz61328%2Fclaudepet)
- Other small repos seen in search but below the bar, not read: xtrimsystems/claude-pet (1 star, Shimeji-style), IMMINJU/claude-pet (12), receyuki/live2pet (1, Live2D/Spine → clawd-on-desk and Codex themes), AptatoX/notchi-for-windows (4), Emi-Dz/pixel-companion (1). — [gh api lookups, 2026-11-14](https://github.com/receyuki/live2pet)

#### Adjacent categories (out of scope, but they show where the energy is)
- **Official Codex Pets**: OpenAI shipped "Codex pets" in the Codex app on about 2026-05-01. Pets float on the desktop showing work status even when the app is minimized; enable via Settings > Appearance > Pets or `/pet`. They are app-only, not CLI. — [gihyo.jp](https://gihyo.jp/article/2026/05/codex-pets), [newsletter mirror](https://kill-the-newsletter.com/feeds/mjugybkg2v01fvex5x9b/entries/ep1hd08nd36g9icwtpu0.html)
- The Codex pet galleries are large: awesome-codex-pet has 1,279 stars, and single-character pet packs reach 100–450 stars (e.g. remielle-codex-pet 449). — [gh search](https://github.com/legeling/awesome-codex-pet)
- **Status-line pets** (inside the terminal, not desktop): e.g. TeXmeijin/claude-code-mascot-statusline, 31 stars. — [repo](https://github.com/TeXmeijin/claude-code-mascot-statusline)
- **Hardware desk companions**: HermannBjorgvin/Clawdmeter (2,349 stars, ESP32 usage display, pushed 2026-11-14) and yousifamanuel/clawd-mochi (794 stars). — [Clawdmeter](https://github.com/HermannBjorgvin/Clawdmeter), [clawd-mochi](https://github.com/yousifamanuel/clawd-mochi)

### Inferences
- The category exploded between December 2025 and April 2026: Claude Island was created 2025-12-09, and clawd-on-desk, Open Island, MioIsland, Buddi, Hopet and EchoIsland were all created between March and April 2026. Since then it has consolidated around about 5 leaders. Most of the long tail (dozens of 0–20 star "claude-code-desktop-pet" repos) are weekend projects with a single contributor.
- Among the projects surveyed, only clawd-on-desk combines a **character-first floating pet** with deep approval and session plumbing. Petdex's desktop app is also a large-star floating pet, but its stars come mostly from the gallery, and it is watch-only as far as documented. The notch apps are far more numerous, but their characters are secondary or absent (Open Island has none; Notchi and Buddi have them).
- A large share of the authors and communities are Chinese-speaking (LINUX DO, WeChat groups, Feishu/DingTalk integrations). clawd-on-desk's reach is partly driven by that community.
- Vibe Notch's star count overstates how healthy it is: commits stopped 7 months ago, and its derivatives (MioIsland, Buddi) now carry its ideas forward.

### Gaps
- Download and install counts (Homebrew analytics, release download totals) were not collected.
- **Search coverage was partly lost.** Eight GitHub repo-search queries hit the rate limit on the first pass: "claude code buddy desktop", "claude code sprite", "claude code hooks pet", "claude code notifier macos", "opencode pet", "claude code widget", "claude code avatar", "pixel pet claude". All eight were re-run later and returned no repos with ≥20 stars, but a project named outside these keywords could still be missing. Product Hunt, Hacker News and X/Twitter launches were not searched.
- Strengths and weaknesses for the smaller table rows are limited to what their READMEs state; their issue trackers were not reviewed.
- Vibe Island's paying user base, and its pricing on the official page, were not verified directly.
- I could not confirm whether Petdex desktop or OpenPets ever added approvals after their README dates.
- The ClaudePet repo's status (deleted or renamed) is unknown.

## What feature set has become the "baseline" across them (states, approvals, notifications, sounds)?

### Takeaway
The baseline is now: Claude Code **hooks** (auto-installed on first launch, merged without overwriting existing hooks) feeding a local **Unix socket or localhost HTTP** server, and a state machine of roughly 7–12 states (idle, thinking, working/tool, waiting/permission, done, error, sleep). On top of that: **Allow/Deny from the companion**, multi-session aggregation, **jump to the terminal**, sounds, usage/quota display, and Codex support. Approvals and jump-back are table stakes for notch apps. Usage/quota rings are the newest near-universal add-on.

### Cited Findings
- Hook → socket is the dominant architecture:
  - Open Island: hook CLI → Unix socket → BridgeServer. — [Open Island](https://github.com/Octane0411/open-vibe-island)
  - Notchi: shell hooks → Unix socket → state machine. — [Notchi](https://github.com/sk-ruban/notchi)
  - Buddi: hooks → Unix socket. — [Buddi](https://github.com/talkvalue/Buddi)
  - Hopet: hooks → `hopet-emit` → Unix socket with length-prefixed JSON. — [Hopet](https://github.com/BinaryFroggy/Hopet)
  - MioIsland: `/tmp/codeisland.sock`. — [MioIsland](https://github.com/MioMioOS/MioIsland)
  - ClawdGotchi: Python hook → Unix socket. — [ClawdGotchi](https://github.com/stevysmith/clawdgotchi)
- The HTTP variant: clawd-on-desk uses localhost ports 23333–23337 with a `/permission` endpoint; Petdex uses `127.0.0.1:7777`; EchoIsland uses TCP IPC plus an HTTP receiver. — [clawd known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md), [Petdex](https://github.com/crafter-station/petdex), [EchoIsland](https://github.com/FunplayAI/EchoIsland)
- The minority approach skips hooks and tails transcripts and processes. agent-notch polls `ps`/`lsof` and JSONL write times every 3 s. Claude Petty reads `~/.claude/projects/`. Codex Pacer reads agent logs. — [agent-notch](https://github.com/realfishsam/agent-notch), [Claude Petty](https://github.com/caigee-cmd/claude-petty), [Codex Pacer](https://github.com/RyanZhangNTU/codex-pacer)
- Typical state sets:
  - Hopet's 8 states: idle, responding, thinking, tool-use, permission-prompt, ask-user, completed, error-interrupted. — [Hopet](https://github.com/BinaryFroggy/Hopet)
  - notchify: start, working, waiting, done, error, bye, idle. — [notchify](https://github.com/kikudjira/notchify)
  - clawd-on-desk's 12 states add subagent states (headphones for 1 subagent, juggling for 2+), sweeping (compaction), carrying and sleeping. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - Notchi adds compacting plus emotions driven by sentiment. — [Notchi](https://github.com/sk-ruban/notchi)
- Approvals from the companion are claimed by clawd-on-desk, Vibe Notch, Buddi, Hopet, Open Island, Vibe Island, AgentBro, EchoIsland, MioIsland, QuotaView and agent-isle. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [Vibe Notch](https://github.com/farouqaldori/vibe-notch), [Buddi](https://github.com/talkvalue/Buddi), [Hopet](https://github.com/BinaryFroggy/Hopet), [Open Island](https://github.com/Octane0411/open-vibe-island), [Vibe Island](https://github.com/vibeislandapp/vibe-island), [AgentBro](https://github.com/shirenchuang/agentbro), [EchoIsland](https://github.com/FunplayAI/EchoIsland), [MioIsland zh](https://github.com/MioMioOS/MioIsland/blob/HEAD/README.zh-CN.md), [QuotaView](https://github.com/Duoasa/QuotaView), [agent-isle](https://github.com/DevLab-Technologies/agent-isle)
- Sounds:
  - clawd-on-desk: completion and permission cues, 10 s cooldown, muted in DND. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - Notchi: auto-mutes when the terminal is focused, supports importable sounds. — [Notchi](https://github.com/sk-ruban/notchi)
  - notchify: per-state macOS system sounds or custom files in JSON. — [notchify](https://github.com/kikudjira/notchify)
  - Open Island: configurable system sounds. — [Open Island](https://github.com/Octane0411/open-vibe-island)
  - MioIsland: "8-bit" sounds. — [MioIsland](https://github.com/MioMioOS/MioIsland)
- Usage and quota display: Notchi, Buddi, Open Island, Vibe Island, Codex Pacer, OpenPets, and clawd-on-desk's Orbit rings. clawd-on-desk explicitly reads Claude Code's official status-line `rate_limits` payload rather than scraping. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [Notchi](https://github.com/sk-ruban/notchi), [Codex Pacer](https://github.com/RyanZhangNTU/codex-pacer)
- Safe hook installation is now expected:
  - Hopet: "safe JSON merge, never overwrites existing hooks". — [Hopet](https://github.com/BinaryFroggy/Hopet)
  - zzp1221: backs up `settings.json`; the uninstaller only removes its own handlers. — [zzp1221](https://github.com/zzp1221/claude-code-pet)
  - claudlet: "only ever touches its own entries", but warns that you must unhook before uninstalling or Claude Code keeps calling a missing `claudlet-hook`. — [claudlet](https://github.com/YeeDochi/Claudlet)
- Codex support (via `~/.codex/hooks.json`, with JSONL as a fallback) is nearly universal among the active projects. Codex hooks need user approval through `/hooks` before they run. — [Notchi](https://github.com/sk-ruban/notchi), [clawd known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md), [claudlet](https://github.com/YeeDochi/Claudlet)
- Pet-specific polish common among desktop pets: drag with position memory, click-through transparency, always-on-top without stealing focus, a sleep sequence, and click reactions. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [Hopet](https://github.com/BinaryFroggy/Hopet)
- Distribution is mostly a DMG plus a Homebrew cask, with Sparkle auto-update on macOS. Python (pipx) and npm installs are the exception. — [Open Island](https://github.com/Octane0411/open-vibe-island), [Notchi](https://github.com/sk-ruban/notchi), [claudlet](https://github.com/YeeDochi/Claudlet)

### Inferences
- A new entrant without auto-installed hooks, Allow/Deny, jump-to-terminal and Codex support would look behind the baseline. A character-first app's differentiation has to come from personality, animation quality and customization, since the plumbing is commoditized.
- Subagent visualization (clawd-on-desk's juggling, claudlet's hatted followers, agent-notch's fold-out list) is becoming a second-wave baseline.

### Gaps
- No project published latency or overhead benchmarks for its hooks. Vibe Island's "under 50 MB RAM" claim is unverified.

## Which ones let users interact back (send prompts, approve, open terminal), not just watch?

### Takeaway
Approve/deny and jump-to-terminal are common. **Sending prompts or chat** back into a session is rare. Only Buddi, inheriting Claude Island's chat view, claudlet (chat window that types into the session), clawd-on-desk (Telegram "Direct Send") and AgentBro (quick reply) clearly offer it. Answering AskUserQuestion and reviewing plans is the next frontier: Hopet, Vibe Island and AgentBro do it.

### Cited Findings
- Send prompts or chat:
  - **Buddi**: "View full conversation history with markdown rendering, send messages back". — [Buddi](https://github.com/talkvalue/Buddi)
  - **claudlet**: "Enter types your line straight into the session" on KDE via Konsole DBus; "macOS: notes only for now". It can attach a dragged-over window's content to your next line, and an optional side-call mode lets the pet answer small talk itself. — [claudlet](https://github.com/YeeDochi/Claudlet)
  - **clawd-on-desk**: Telegram Direct Send uses the Codex thread queue when available, otherwise falls back to the clipboard (no Enter injected). — [clawd known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md)
  - **AgentBro**: "supported agents can quick-reply directly". — [AgentBro](https://github.com/shirenchuang/agentbro)
  - **MioIsland**: remote launch through `cmux send`, and the iPhone "Code Light" app. — [MioIsland](https://github.com/MioMioOS/MioIsland)
- Structured answers:
  - Hopet expands AskUserQuestion into paged answer cards with option buttons and a free-text fallback, returned via `updatedInput.answers` through the held PermissionRequest hook. It also handles plan approval. — [Hopet](https://github.com/BinaryFroggy/Hopet), [Hopet hooks doc](https://github.com/BinaryFroggy/Hopet/blob/HEAD/DevDocs/hooks-and-priority.md)
  - Vibe Island: "Answer questions in one click" and "Plan review … send feedback". — [Vibe Island](https://github.com/vibeislandapp/vibe-island)
  - clawd-on-desk: a "Question prompts only" mode. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
- Approve from a phone: clawd-on-desk via Telegram and Feishu (Slack is notify-only). — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
- Open the terminal:
  - Open Island has the deepest per-terminal pane targeting: TTY, Ghostty ID, cmux socket, tmux pane, Warp via SQLite plus an AX menu click. — [Open Island](https://github.com/Octane0411/open-vibe-island)
  - clawd-on-desk jumps from the dashboard or HUD and auto-focuses on attention. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - claudlet: "Click it to bring the terminal back to the front". — [claudlet](https://github.com/YeeDochi/Claudlet)
  - Codex Pacer: opens the conversation in its app. — [Codex Pacer](https://github.com/RyanZhangNTU/codex-pacer)
- Watch-only (no approvals): Notchi (its Claude hook maps PermissionRequest to `waiting_for_input` and is fire-and-forget with `timeout=0.5`), agent-notch, Claude Petty, notchify, ClawdGotchi, petdex-cc, and OpenPets (agent pushes status via MCP). — [Notchi hook](https://github.com/sk-ruban/notchi/blob/HEAD/notchi/notchi/Resources/notchi-hook.sh), [agent-notch](https://github.com/realfishsam/agent-notch), [OpenPets](https://github.com/alterhq/openpets)
- A different interaction model: OpenPets is an **MCP server**, so the agent itself decides to call `notify` or `play_pet_animation`. That requires adding assistant instructions so the agent uses it consistently. — [OpenPets](https://github.com/alterhq/openpets)

### Inferences
- Among projects surveyed, a character pet that can both approve and take a typed prompt is uncommon. Buddi and MioIsland (via its iPhone app) do it in a notch, and claudlet does it on Linux. No floating desktop pet found does it locally on macOS (claudlet is notes-only on macOS; clawd-on-desk sends via Telegram, not from the pet itself). That looks like an open niche, but the search was not exhaustive.
- Injecting text into a running Claude Code terminal is platform-fragile, which is why the projects fall back to Konsole DBus, cmux send, the Codex queue, or the clipboard. Only Claude Code's hook return channel (PermissionRequest / AskUserQuestion) is reliable everywhere.

### Gaps
- How Buddi sends messages back to Claude Code (terminal injection or something else) is not documented in its README.

## How do they handle multiple concurrent sessions, sessions they didn't start, and crash/approval fallbacks?

### Takeaway
There are two multi-session models: one pet showing the **highest-priority state** (clawd-on-desk, Hopet), or **one sprite or row per session** (Notchi, ClawdGotchi, agent-notch, notch-app lists). Sessions the app didn't start are picked up by global user-level hooks (any terminal), by JSONL transcript discovery at launch (Open Island, Petdex, clawd-on-desk's Codex), or by process scanning (agent-notch). Mature projects **fail open**: if the app is down, times out or is in DND, the hook returns nothing and the agent's native terminal prompt takes over. Crashed sessions are cleaned up through process-liveness checks plus idle timeouts.

### Cited Findings
- Priority aggregation:
  - clawd-on-desk: "sessions across all agents resolve to the highest-priority state". — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - Hopet: one pet with priority AskUser > Permission > Error > Tool > Thinking > Responding > Completed > Idle, plus a "Leader" highlight showing which session drives the pet. Its rationale: AskUserQuestion outranks permission because a user can quickly "allow all" a permission from the terminal. — [Hopet](https://github.com/BinaryFroggy/Hopet), [Hopet hooks doc](https://github.com/BinaryFroggy/Hopet/blob/HEAD/DevDocs/hooks-and-priority.md)
- Per-session visuals:
  - Notchi: one sprite per session (but see issue #9). — [Notchi](https://github.com/sk-ruban/notchi)
  - ClawdGotchi: one crab per session with a repo-hashed accessory. — [ClawdGotchi](https://github.com/stevysmith/clawdgotchi)
  - agent-notch: one row per session, led by your latest prompt, with subagents folded under "▸ N subagents". — [agent-notch](https://github.com/realfishsam/agent-notch)
  - clawd-on-desk themes can define `workingTiers` / `jugglingTiers` (different art by session or subagent count); the Dev Life theme uses this for 1, 2 and 3+ sessions. — [clawd theme guide](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/guide-theme-creation.md), [clawd-stickers](https://github.com/alwinecor/clawd-stickers)
- Discovering sessions the app didn't start:
  - Open Island: "auto-discovers your active agent sessions" from `~/.claude/projects/` JSONL at launch and persists them across launches. — [Open Island architecture](https://github.com/Octane0411/open-vibe-island/blob/HEAD/docs/architecture.md)
  - Petdex: "durable recovery" from Codex rollouts, Claude transcripts, Gemini chats and others; fails closed for stores without a stable contract. — [Petdex desktop](https://github.com/crafter-station/petdex/tree/HEAD/packages/petdex-desktop-native)
  - claudlet: hook changes only apply to new sessions ("restart sessions that were already running"). — [claudlet](https://github.com/YeeDochi/Claudlet)
  - clawd-on-desk warns that an already-running CLI may need a new session if its HTTP port changes. — [clawd known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md)
  - Open Island notes that Claude Desktop runs Claude Code as a TTY-less subprocess invisible to process discovery, so liveness follows the desktop app instead. — [Open Island](https://github.com/Octane0411/open-vibe-island)
- Crash cleanup:
  - clawd-on-desk "detects crashed/exited supported agent processes and cleans up orphan sessions". Startup recovery keeps the pet awake if agents are still running when it restarts. For WSL (where PIDs can't be trusted) it falls back to a 5 min working timeout and then a 10 min session timeout. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [clawd known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md)
  - agent-notch: process gone for 2 polls = done. — [agent-notch](https://github.com/realfishsam/agent-notch)
  - EchoIsland: "blocking request cleanup" plus auto-snapshot recovery. — [EchoIsland](https://github.com/FunplayAI/EchoIsland)
- Approval fallbacks:
  - Open Island: "Hooks fail open — if Open Island isn't running, your agents continue unaffected." — [Open Island](https://github.com/Octane0411/open-vibe-island)
  - clawd-on-desk: "When Clawd yields no decision (timeout, disconnect, DND, bubbles off), the hook prints `{}` and [the agent's] own permission flow takes over". If you answer in the terminal first, the bubble auto-dismisses. A remote-channel failure "never" produces a denial. — [clawd state-mapping](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/state-mapping.md), [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - Hopet offers "hand to terminal" as a third button, and dropped the `Notification` hook as a permission fallback because it double-fired alongside `PermissionRequest`. — [Hopet](https://github.com/BinaryFroggy/Hopet), [Hopet hooks doc](https://github.com/BinaryFroggy/Hopet/blob/HEAD/DevDocs/hooks-and-priority.md)
  - Notchi's hook exits 0 if the socket is missing. — [Notchi hook](https://github.com/sk-ruban/notchi/blob/HEAD/notchi/notchi/Resources/notchi-codex-hook.sh)
- Known race and edge bugs:
  - Vibe Notch gets stuck on "Processing..." because PostToolUse fires after Stop for background Bash (#98). — [vibe-notch issues](https://github.com/farouqaldori/vibe-notch/issues)
  - agent-notch's inferred busy state lags turn end by up to ~33 s. — [agent-notch](https://github.com/realfishsam/agent-notch)
  - clawd-on-desk documents very detailed turn correlation for Claude Code (`PostToolBatch`, `prompt_id`) to avoid state flicker. — [clawd state-mapping](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/state-mapping.md)

### Inferences
- Fail-open approval handling is how mature projects keep the agent from hanging on a crashed companion, and it is the expected behavior.
- Claude Code's PermissionRequest hook blocking until the app answers is the mechanism behind every Allow/Deny implementation. Agents whose hook runners cap handler time (clawd-on-desk notes MiniMax's 1–10 s cap) can't support approvals at all. — [clawd known-limitations](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/known-limitations.md)

### Gaps
- Exact PermissionRequest timeout values per project were not collected.
- Behavior with headless or `claude -p` sessions is only mentioned by agent-notch, which ignores sessions without a TTY.

## How do they let users swap/customize the character art (sprite sheet format, skins)?

### Takeaway
The **Codex Pets format** (`pet.json` plus `spritesheet.webp/png`, an 8×9 grid of 192×208 frames, or v2 8×11) has become the de facto interchange standard. It is imported by clawd-on-desk, Hopet, OpenPets, Petdex, agent-notch and zzp1221's pet, and fed by petdex.dev's 1.5k+ pets and by OpenAI's `hatch-pet` skill. clawd-on-desk also has the richest native theme system (`theme.json` with SVG, GIF, APNG or WebP per state, eye tracking, tiers, mini mode, plus a validator). Other approaches: a set of 8 GIFs (Hopet), code-drawn creatures as Python packages (claudlet), procedural buddies (Buddi), and fixed bundled sets (Notchi, Claude Petty).

### Cited Findings
- Codex Pets format:
  - Petdex: every pet is "a `pet.json` plus a `spritesheet.{webp,png}` rendered as an 8x9 grid of 192x208 frames, or the v2 8x11 grid". Install with `npx petdex install <slug>` into `~/.petdex/pets/`. — [Petdex](https://github.com/crafter-station/petdex)
  - OpenAI's `hatch-pet` skill creates and validates pets; packages live in `~/.codex/pets/<name>/`. These details come from third-party write-ups and should be checked against openai/skills. — [hongkiat](https://www.hongkiat.com/blog/?p=74409), [penchan.co](https://penchan.co/en/ai/coding/codex-pets/)
- Importers:
  - clawd-on-desk: "import Codex Pet zip packages … Clawd adapts their atlas animations into managed themes". — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - Hopet: imports a Codex pet folder or ZIP, supports v1 (8×9) and v2 (8×11), validates and auto-maps to Hopet states, installs atomically to `~/.hopet/themes/` with rollback on failure. It alternatively accepts 8 GIFs, one per state. — [Hopet](https://github.com/BinaryFroggy/Hopet)
  - OpenPets: "install custom Codex Pets using an 8x9 sprite atlas". — [OpenPets](https://github.com/alterhq/openpets)
  - zzp1221's pet auto-syncs `~/.codex/pets`. — [zzp1221](https://github.com/zzp1221/claude-code-pet)
  - agent-notch bundles official Codex pet sheets ("© OpenAI, from their public pets CDN"). — [agent-notch](https://github.com/realfishsam/agent-notch)
- clawd-on-desk native themes:
  - A theme is a folder with `theme.json`, scaffolded by `npm run create-theme`. Minimum viable theme: 1 SVG (idle with eye tracking via `#eyes-js`) plus 7 GIF/APNG files (thinking, working, error, happy, notification, sleeping, waking). — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md)
  - Optional fields: `fallbackTo`, `idleAnimations` pool, `workingTiers` / `jugglingTiers`, reactions, hit boxes, mini mode, accessory attachments, and `rendering.discreteSampling`, which snaps CSS animations to a frame grid to save CPU on high-refresh displays. — [clawd theme guide](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/guide-theme-creation.md)
  - A `validate-theme.js` CLI, capability badges on theme cards, a sanitizer for third-party SVGs, an official theme repo (clawd-themes), and a community tool (Live2Pet) that converts Live2D models into themes. — [clawd features](https://github.com/rullerzhou-afk/clawd-on-desk/blob/HEAD/docs/guides/features.md), [README](https://github.com/rullerzhou-afk/clawd-on-desk)
- claudlet: creatures are "a small Python package", drawn with rectangles or blitted from a sprite sheet. `/claudlet make a grumpy little robot` has the agent write one. Creatures export and import as zips, and an import shows its contents before installing "since it runs their code". — [claudlet](https://github.com/YeeDochi/Claudlet)
- Buddi: 18 species with eyes, hats and rarity generated from your system identity (revives the removed `/buddy`), so customization is procedural rather than user-drawn. — [Buddi](https://github.com/talkvalue/Buddi)
- Notchi: separate Claude and Codex sprite families made in Aseprite; custom sounds can be imported, but I found no custom-sprite import in its README. Open issue #3 "Let him move!" asks for more animation. — [Notchi](https://github.com/sk-ruban/notchi), [issues](https://github.com/sk-ruban/notchi/issues)
- Licensing: clawd-on-desk's code is AGPL but its art is "all rights reserved", and it notes that "Clawd character is the property of Anthropic … unofficial fan project". clawd-stickers' art is CC BY-NC-SA. MioIsland is CC BY-NC 4.0 overall. — [clawd README](https://github.com/rullerzhou-afk/clawd-on-desk), [clawd-stickers](https://github.com/alwinecor/clawd-stickers), [MioIsland](https://github.com/MioMioOS/MioIsland)

### Inferences
- A new companion that wants a large art catalog should be able to read Codex Pets atlases (v1 and v2) and map the atlas rows to its own states, the way Hopet and clawd-on-desk do. A per-state GIF/APNG/WebP mapping file in the style of clawd-on-desk's `theme.json` serves hand-made, higher-fidelity characters.
- Using the Clawd mascot itself carries IP risk (Anthropic property). Leading projects ship original characters (Calico, Cloudling, Hopi seal, Starcorn) next to it or instead of it.

### Gaps
- The exact row-to-state mapping of the Codex Pets 8×9 and 8×11 atlases was not pulled from a primary OpenAI source; only the dimensions were confirmed, via Petdex and Hopet.
- No project documents a skin format for notch apps beyond fixed sprite families. Whether Open Island or Vibe Island support any character art at all was not found.
