# Nell 1.0 release: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Claude in Nell behaves exactly as in the user's terminal, and Chat becomes full Claude Code. Nell finds or installs her dependencies. Nell ships as an MIT-licensed, universal DMG with a pixel-art icon and a stylised README.

**Spec:** `docs/specs/2026-11-15-nell-release-design.md`

**Branch:** `release-v1`

## Global constraints

**The user's machine and settings**
- Never modify `~/.claude/settings.json` or `~/.claude.json`. Reading them is allowed.
- Never touch the user's running Nell (`build/Nell.app`, its process, `~/Library/Application Support/Nell`), or `/Applications/kitty.app`.
- Never open `/Users/me/Claude/private-artwork/private/` or `/private/`.
- Live tests use throwaway kittys on `/tmp` sockets with their own temporary support folders. Kill only their pids.
  - claude may be run only for the stated parity checks, with tiny prompts, in a scratch folder or Nell's chat-folder equivalent under `/tmp`.
  - Only read-only tools may be allowed, for example `--allowedTools "Bash(echo:*)" "Bash(command -v:*)"`.

**How the code is written**
- Command Line Tools only. No SwiftUI `@State`. Tests run with `scripts/test.sh`, and `swift build` must also pass. `bash Tests/hook-script-test.sh` must stay green.
- Root causes only. Test-first wherever NellCore can pin the behaviour. App-target changes need a stated check.
- The spec'd behaviour stays: approvals, Auto mode for Code, the review-fix guarantees (never send bar text while a prompt may be open), themes and usage chips.

**Commits and publishing**
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Docs are dated, typed and indexed in `docs/README.md`.
- No push, no merge into main, no GitHub release.

## Review focus

1. **Claude in Nell must match the terminal.** Its PATH, environment, skills, hooks, MCP and status line must equal the terminal's, in both modes. Nothing from Nell's own process environment may leak in.
2. **A shell that misbehaves at startup must not break the launch.** This covers a login shell that prints output, prompts, is slow, or is fish or bash rather than zsh. The worst case is a visible message in the console, never a hang or a dead tab.
3. **Chat with tools must reuse Code's guarantees.** Its approvals, questions and holds must go through the same paths. "Answer in the console" must show the right tab. A Chat approval must never be sent into while it's open.
4. **The kitty installer must never run anything unverified.** It aborts on any signature mismatch, partial download or wrong team ID, and leaves nothing half-installed.
5. **The DMG must work from a fresh download.** The app copied out of it must run on another Mac (codesign valid, both architectures present). The "How to open" steps must be accurate for macOS 14 and 15+.

---

### Task 1: Terminal parity and Chat as full Claude Code

**Files:** `Sources/NellCore/Launch.swift` (`claudeArgs`, the chat system prompt), `Sources/NellCore/KittyCommands.swift` (launch argv and env), `Sources/Nell/Resources/nell-status.sh`, `Sources/Nell/KittyController.swift` (the launch paths only), `Sources/Nell/NellModel.swift` and `ConsoleState` (Chat approvals and the console tab), the showcase if it's affected, and the tests.

- [ ] **Launch through the login shell.** Claude runs as `<user's login shell> -l -i -c 'exec "$0" "$@"' <claude> <args…>`, inside kitty's clean base environment. The shell comes from the user record (`getpwuid`), not from `$SHELL`.
  - Apply this to both the panel's first window and `launch --type=tab`.
  - Keep `NELL_MODE` and the `nell_mode` var tag.
  - fish needs its own `-c` form. Handle zsh, bash and fish, and test the argv for each.
- [ ] **Chat as full Claude Code.** `claudeArgs(.chat)` drops `--tools ""`, `--strict-mcp-config`, `--no-chrome`, `--setting-sources project` and the system prompt. It keeps `--settings <Nell's hooks>` and its session args. Code keeps `--permission-mode auto`.
  - Update the tests: `LaunchTests`, plus any test that asserts the old Chat flags.
  - Remove `chatSystemPrompt` if nothing else uses it.
- [ ] **Chat approvals and questions.** Confirm, and fix where needed, that Chat's PermissionRequest and AskUserQuestion go through the same tracker, bubble and hold paths as Code's. "Answer in the console" or Console on a Chat approval must open the console on the Chat tab. Remove or correct every "Chat never holds" or "Chat has no tools" assumption: grep `shortcut:` comments and the `ReturnedText` comment.
- [ ] **Status line chaining.**
  - If the user's `~/.claude/settings.json` has a `statusLine` command, `nell-status.sh` runs it with the same stdin and prints its output, while still posting usage to Nell.
  - With no user status line, it prints Nell's line as today.
  - Read the user's command at launch time, read-only. Pass it to the script, for example as an argument or a file in Nell's support folder.
  - Extend the hook-script test to cover both cases.
- [ ] **Commit:** `feat: Claude runs through your login shell; Chat is full Claude Code; your status line still runs`

### Task 2: Find or install kitty and Claude Code

**Files:** a new `Sources/NellCore/Tools.swift` (locator and installer logic that can be tested), `Sources/NellCore/KittyCommands.swift` (paths become injectable), `Sources/Nell/KittyController.swift`, `Sources/Nell/AppDelegate.swift` (first-run checks), `Sources/Nell/Resources/nell-hook.sh` (the kitten path), and the tests.

- [ ] **Locate claude.** First `command -v claude` in the user's login shell, then `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, `~/.claude/local/claude` and npm's global bin.
  - Missing: show an alert with the official install command, a link and Quit. Never run a remote installer.
- [ ] **Locate kitty.** Check `/Applications/kitty.app`, then `~/Applications/kitty.app`.
  - Every former hard-coded path follows the located one: `KittyCommands`, `isKitty`, `NELL_KITTEN` for the hook script (set it in the generated settings command or the kitty env), and the Fonts install.
- [ ] **Install kitty when it's missing.** Offer it in a first-run alert. Then:
  1. Read the latest release from `https://api.github.com/repos/kovidgoyal/kitty/releases/latest` and pick the `.dmg` asset.
  2. Download it to a temp folder.
  3. Mount it read-only (`hdiutil attach -nobrowse -readonly`).
  4. `codesign --verify --deep --strict` and `spctl --assess --type execute` the kitty.app inside.
  5. Check that `TeamIdentifier=NTY7FVCEKP`.
  6. Copy it to `~/Applications/kitty.app`.
  7. Detach the image and clean up.

  Any failure aborts with a clear message and leaves nothing installed.
  - The parsing and decisions are tested in NellCore: picking the asset from the release JSON, parsing codesign output for the team, and the install-or-abort decisions.
  - Verify the real pipeline once into a temp destination. Never `/Applications`, never `~/Applications`.
- [ ] **Commit:** `feat: Nell finds Claude Code and kitty, and can install kitty safely`

### Task 3: Icon, licences, universal build and DMG (in parallel with Task 1; owns only these files)

**Files:** `LICENSE`, `artwork/LICENSE`, `THIRD_PARTY.md`, `artwork/icon/` (sources and exports), `Sources/Nell/Resources/AppIcon.icns`, `scripts/Info.plist`, `scripts/bundle.sh`, a new `scripts/package.sh`, `.gitignore` (`dist/`).

- [ ] **Licences.**
  - MIT in `LICENSE`, © 2026 hanamorix.
  - CC BY-NC 4.0 in `artwork/LICENSE`, covering `artwork/`, `concept-nell-design-system/` and `Sources/Nell/Resources/sprites` and `icons`.
  - `THIRD_PARTY.md` lists Departure Mono (OFL 1.1, with the licence path) and says kitty is installed from its own project.
- [ ] **App icon.** Design it with the Aseprite MCP from Nell's own sprite (`Sources/Nell/Resources/sprites/`, or `artwork/sprites/nell-master.aseprite`):
  - Her head and hood, front facing, on a Plum Night rounded-square tile, following the macOS icon grid with the safe margin.
  - Pixel-crisp, scaled by integer factors only.
  - Export a 1024 px master and build `AppIcon.iconset` with all ten sizes, then `iconutil -c icns`.
  - Show it at 16, 32, 128 and 512 px in a preview image, and check it reads at 16 px.
- [ ] **Info.plist.** `CFBundleIdentifier io.github.hanamorix.nell`, `CFBundleShortVersionString 1.0.0`, `CFBundleVersion 1`, `CFBundleIconFile AppIcon`, `NSHumanReadableCopyright`. Keep `LSUIElement` and the minimum version of 14.0.
  - Check what changing the bundle id does to existing state. Application Support is path-based, and SMAppService login-item registration may need re-registering. Make sure the showcase id derivation in `showcase.sh` still works.
- [ ] **Universal build.**
  - `swift build -c release --arch arm64` and `--arch x86_64`, joined with `lipo -create`.
  - Check with `lipo -info` / `file`. x86_64 can't be run here, because this Mac has no Rosetta.
  - `bundle.sh` keeps its `*.app` guard and ad-hoc signing.
  - If the CLT can't cross-compile x86_64, say so and ship arm64-only, with the README saying "Apple silicon".
- [ ] **`scripts/package.sh` builds `dist/Nell-1.0.0.dmg`:**
  - Bundle into a staging folder, never `build/Nell.app`.
  - Add an `Applications` symlink and "How to open Nell.txt":
    - macOS 15+: System Settings → Privacy & Security → Open Anyway.
    - macOS 14: right-click → Open.
    - Requirements: kitty (Nell can install it) and Claude Code with a logged-in account.
  - Set the volume icon (`.VolumeIcon.icns` plus `SetFile -a C`).
  - Build with `hdiutil create -format UDZO`, then `hdiutil verify`.
- [ ] **Commit:** `build: MIT/CC BY-NC licences, pixel-art app icon, universal build, DMG packaging`

### Task 4: Live verification (controller, after Tasks 1–3 are merged on the branch)

- [ ] **Parity, in a throwaway kitty with Nell's real argv and env** (built from the code, never the user's Nell):
  - Claude's `$PATH` from `echo` matches `zsh -l -i -c 'echo $PATH'`.
  - Chat lists the user's skills.
  - A user hook would fire. The user has no user-level hooks today, so use a scratch `--settings` hook in the throwaway run.
- [ ] **kitty installer:** the real pipeline into a temp destination.
- [ ] **DMG:**
  - `hdiutil verify` passes, and it attaches.
  - The app copied out passes `codesign --verify` and `lipo -info`.
  - It launches in `--showcase` mode with no MISMATCH lines, then quit by its pid.
  - `xattr -w com.apple.quarantine` on a copy, then `spctl --assess` shows the rejection the "How to open" text covers.

### Task 5: Stylised README

- [ ] Rewrite `README.md` in the project's voice: warm, plain and first-person plural. Cover:
  - **Header:** the icon, a one-line pitch and badges (licence, macOS 14+, release).
  - **What she is and why we made her.**
  - **What she can do:** Chat and Code, skills and hooks just like the terminal, approvals in bubbles, faces and reactions, usage chips, themes, the console.
  - **Screenshots:** take them from the sandboxed showcase and save them to `docs/images/`.
  - **Install:** the DMG, first launch, kitty and Claude Code.
  - **What she never touches.**
  - **Build from source.**
  - **Licences.**

  Every claim must be true of this build.
- [ ] **Commit:** `docs: stylised README for 1.0`

### Final

- [ ] Whole-branch review (Opus), plus a red team against the review focus. One fix wave. Re-verify.
- [ ] A build ledger in `docs/notes/`.
- [ ] A morning summary for the user. Merging, pushing and the GitHub release stay with them.
