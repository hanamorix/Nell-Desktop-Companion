# Nell: a desktop companion for Claude

Nell is a small animated character who sits on your Mac desktop and stands in for the Claude App. You chat with Claude through her, or drive Claude Code. She shows what Claude is doing with animations and speech bubbles that fade away, and you can approve or deny Claude's actions from her bubbles.

- **💬 Chat:** full Claude Code in Nell's chat folder, with your own settings, skills, hooks and MCP servers. Its approvals come to Nell's bubbles too.
- **⌘ Code:** Claude Code in your project. The full session lives in a kitty window that Nell owns.

## Requirements

- macOS 14 or later.
- [kitty](https://sw.kovidgoyal.net/kitty/) in `/Applications/kitty.app`.
- The Claude Code CLI at `~/.local/bin/claude`, already logged in.
- The Swift toolchain. The Command Line Tools are enough; Xcode is optional.

## Build and run

```bash
scripts/test.sh            # unit tests (Swift Testing)
bash Tests/hook-script-test.sh
bash scripts/bundle.sh     # builds build/Nell.app
open build/Nell.app
```

Nell's runtime files live in `~/Library/Application Support/Nell/`, including `nell.log`, which has one line per Claude event. She never changes `~/.claude/settings.json`.

## Layout

| Path | What's there |
|---|---|
| `Sources/NellCore/` | All logic, with tests: hook events, state machine, bubbles, approvals, hook server, kitty commands |
| `Sources/Nell/` | The macOS app: overlay panel, views, kitty controller. `Resources/` holds the hook script, `kitty.conf` and sprites |
| `Tests/` | Unit tests and the hook-script test |
| `scripts/` | Test runner, app bundler, `Info.plist` |
| `artwork/` | Character art, with concept art in `concept/` and one folder per animation state |
| `docs/` | Specs, plans, notes and research. Start at [docs/README.md](docs/README.md) |
