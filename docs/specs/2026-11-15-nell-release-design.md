# Nell 1.0 release: design

**Date:** 2026-11-15 · **Status:** approved in conversation. The user's words:
- "MIT for code, CC BY-NC for art"
- "We would need to [make] an icon, additionally the build will need to include an installation for kitty"
- "make sure that the desktop companion can use the users skills, hooks, scripts exactly, exactly like how they'd use claude in terminal"
- "Yes to full Claude Code"
- "Design and Create an icon for the .dmg"
- "Build, Package, test and verify the DMG"
- "Update a stylised readme … in our voice"

The user is away and asked for this to be done autonomously, so anything not quoted above is Claude's call. Each call is marked *(call)*.

## Intent

Anyone with a Mac can download Nell from GitHub as a DMG, install it and use it for free as open source. Inside Nell, Claude behaves exactly as it does in the user's own terminal: their skills, hooks, scripts, MCP servers, PATH and environment all apply. That holds in Code, and now in Chat too.

## Goals

1. **Terminal parity.**
   - Claude runs through the user's own login shell, as an interactive login shell, so it gets exactly their terminal's environment (PATH, exported variables, SSH agent).
   - kitty still starts from a clean base, so nothing leaks in from whatever launched Nell.
   - Nell adds her own hooks alongside the user's. The user's own status line, if they have one, still runs: Nell's status script calls it and prints its output, and also posts usage to Nell.
   - Nell never writes to `~/.claude/settings.json` or `~/.claude.json`. Reading them is allowed.
2. **Chat becomes full Claude Code** ("Yes to full Claude Code").
   - Chat uses the same Claude Code as Code: the user's settings, skills, hooks, MCP servers and tools.
   - It runs in Nell's chat folder.
   - The flags that stripped it down (`--tools ""`, `--strict-mcp-config`, `--no-chrome`, `--setting-sources project`, and the no-tools system prompt) are removed.
   - Chat's approvals and questions go through Nell's bubbles, the same as Code's. "Answer in the console" shows the Chat tab.
   - Chat uses Claude Code's default permission mode *(call)*. Only Code starts in Auto, as the user asked earlier.
3. **Dependencies.**
   - **Finding Claude Code:** first `command -v claude` in the user's login shell, then the usual places (`~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, `~/.claude/local`, npm's global bin).
   - **Finding kitty:** `/Applications/kitty.app`, then `~/Applications/kitty.app`.
   - **If kitty is missing,** Nell offers to install it on first launch:
     - She downloads the official kitty DMG from the kovidgoyal/kitty GitHub release.
     - She checks it is signed by Kovid Goyal's Developer ID (team `NTY7FVCEKP`) and passes Gatekeeper (`spctl`).
     - She installs it to `~/Applications`, which needs no admin password *(call)*.
   - **If Claude Code is missing,** Nell shows a clear message with the official install command and the link. She does not run a remote installer herself *(call: safety)*.
   - Every kitty path that was hard-coded follows wherever kitty was found, including the hook script's fallback.
4. **Packaging.**
   - **Licences:**
     - `LICENSE` (MIT) covers the code.
     - `artwork/LICENSE` (CC BY-NC 4.0) covers the pixel art and design-system art.
     - `THIRD_PARTY.md` lists Departure Mono (SIL OFL 1.1) and notes that kitty (GPL-3.0) is downloaded from its own project, not bundled.
   - **App icon:** pixel-art Nell on a Plum Night tile, designed from her sprite. It is used for the app (`.icns`, `CFBundleIconFile`) and the DMG volume.
   - **Universal binary:** arm64 plus x86_64, built per architecture and joined with `lipo`. This Mac has no Rosetta, so the x86_64 slice can be checked with `lipo`/`file` but not run *(stated limit)*.
   - **Bundle details:** bundle id `io.github.hanamorix.nell`, version 1.0.0 *(call)*. The app is ad-hoc signed; there's no Apple Developer ID.
   - **DMG:**
     - It's built with `hdiutil`, with no third-party tools.
     - It contains Nell.app, an Applications link, and "How to open Nell.txt". That file gives the macOS 15+ "Open Anyway" steps for an app that isn't notarised.
     - The volume icon is the app icon.
     - `scripts/package.sh` builds it into `dist/`.
5. **README:**
   - Restyled for GitHub in the project's voice: warm, plain and first-person plural.
   - Covers what Nell is, why she exists and what she can do.
   - Shows screenshots taken from the sandboxed showcase.
   - Explains install (DMG, Open Anyway, kitty, Claude Code) and privacy (what she never touches).
   - Covers building from source and the licences.

## Non-goals

- **Notarisation, an Apple Developer ID and auto-update:** not part of this release.
- **Homebrew cask:** none.
- **Bundling kitty or Claude Code inside the app:** kitty is installed from its own project instead. Claude Code needs the user's own account.
- **Publishing:** pushing, merging and creating the GitHub release wait for the user.

## Anti-goals

- **Silent behaviour differences:** anything that makes Claude in Nell behave differently from Claude in the user's terminal without saying so.
- **Running unverified downloaded code:** the kitty download must pass its signature and team check before it is opened.
- **Breaking the user's setup:** nothing may break the running Nell, or the user's `~/.claude` files, while testing.

## Approaches considered

| Area | Options | Chosen |
|---|---|---|
| Parity: environment | (a) Keep the allowlist and add more variables. (b) Run Claude through the user's login shell. (c) Copy Nell's own environment. | **(b)**: it's the only exact match. (a) always lags behind. (c) carries launchd's or the parent process's environment, not the terminal's. |
| kitty install | (a) Bundle kitty.app in the DMG. (b) First-run download of the official, signed kitty. (c) Instructions only. | **(b)** *(call)*: no GPL source-redistribution duties, always current, and verified by its own signature. (a) inflates the DMG and goes stale. (c) isn't "an installation". |
| DMG layout | (a) A styled Finder window (background art, icon positions via Finder scripting). (b) A plain `hdiutil` volume with a volume icon. | **(b)** *(call)*: (a) needs Finder automation permission, which can't be granted while the user is away. A styled window can come later. |

## Verification required (done before reporting)

- Every NellCore change is test-first, the suite is green, and `swift build` succeeds.
- **Parity, checked live in a throwaway kitty (never the user's Nell), using Nell's real launch arguments and environment:**
  - Claude's `$PATH` matches the user's terminal.
  - The user's skills are listed in Chat.
  - The user's hooks fire.
- **kitty installer:** checked by downloading and verifying into a temporary folder. The real `/Applications` is never touched.
- **DMG:**
  - `hdiutil verify` passes.
  - It mounts.
  - The app copied out passes `codesign --verify`.
  - `lipo` shows both architectures.
  - The copy launches in `--showcase` mode (sandboxed) without crashing.
  - A copy marked as downloaded shows the expected Gatekeeper rejection, which proves the "How to open" text is needed.
- The README renders correctly, and every claim in it is true of the build.
