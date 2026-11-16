# Nell 1.0 release: build ledger (2026-11-16)

Every ruling, review result, live verification and deferred minor from building the 1.0 release: terminal parity and Chat as full Claude Code, finding and installing kitty and Claude Code, licences, icon, universal build, DMG and README. Copied from the working ledger with agent ids removed.


Spec docs/specs/2026-11-15-nell-release-design.md (user approved direction; away — every unquoted choice is Claude's call). Branch release-v1 from main@50bd8c7.

## Pre-flight
| Tasks | Shared | Found |
|---|---|---|
| T1 ↔ T2 | KittyCommands.swift, KittyController.swift, nell-hook.sh | Sequential: T2 after T1. |
| T1 ↔ T3 | none (T3 owns scripts/, licences, icon, Info.plist) | Parallel. |
| T3 → T4 | package.sh, icon | T4 after merge. |
- Ruling: T1 and T3 run in parallel (T1 in the main checkout, T3 in an isolated worktree); T2 after T1 — cost if wrong: a merge conflict.

## Tasks
T1: dispatched (main checkout), BASE 41ef2b9. T3: dispatched (isolated worktree), BASE 41ef2b9.
T1: implementer DONE 472c2c4 (298 tests, hook-script 12/12). Open risks: >8 s rc startup → false nudge; rc files that cd; LANG hard-coded; only user-level statusLine chained; fish untested.
T3: implementer DONE ce739ee (universal x86_64+arm64 via per-arch build dirs + lipo; DMG 1.4 MB verify VALID; icon 128 native ×8 with hand-pixelled 16/32; moon disc added so ears read). Merged into release-v1 (DMG must be rebuilt after T1/T2).
T3 review: Needs fixes — Important: LICENSE/artwork LICENSE/THIRD_PARTY.md don't ship in the app or DMG (MIT and CC BY-NC notices must travel with binaries/art). Minor: CC BY-NC scope claims concept-nell-design-system/ code files (tokens.css, components/, design-system.json) — conflicts with MIT; README should say Apple silicon + Intel and the Open Anyway steps (→ T5).
Ruling: T3 fix round takes the Important plus the scope minor (licence correctness for an open-source release) — cost: none.
T3: fix round 1/5 (2 addressed — licences ship before signing in the app and at the DMG root; art scope narrowed to art, rest MIT; controller verified: copies precede codesign in bundle.sh, scope text; commits 9fabe85..d928678)
T3: complete (commits 41ef2b9..d928678, review clean)
T1 review: Needs fixes. Important: (1) an rc that cd's moves Claude out of --cwd (breaks resume/trust); (2) precmd/chpwd never run under -c → direnv/mise envs missing; (3) statusLine refreshInterval/hideVimModeIndicator dropped; (4) LANG forced en_US (machine is en_GB; kitty sets it itself); (5) slow user status command orphaned when Claude kills the script.
Ruling: T1 fix round takes 1–5 plus Minor 7 (SHLVL), 8 (read the user's statusLine on each run), 12 (long comment) — parity is the user's explicit requirement — cost: small.
T1: minor (deferred → README/open risks): rc that execs tmux etc. takes over the tab (README line: guard with NELL_MODE); project-level statusLine probably replaced by Nell's --settings; CLAUDE_CONFIG_DIR in rc breaks resume/status chaining; "Chat needs a one-time OK" also shows for a slow rc.
T1: fix round 1 implemented 9315cbc (299 tests).
T1: fix round 1/5 (8 addressed, 0 open; commits d928678..9315cbc)
Ruling: keep `;` after the cd (not `|| exit 1`) — kitty already starts the shell in the folder (Process currentDirectoryURL / launch --cwd, which fail visibly and fall back to the chat folder if it's gone), so `cd` only fails in a race after that check; the user's explicit goal is that a misbehaving shell never kills the launch — cost if wrong: in that race Claude starts in the rc's folder.
T1: minor (deferred → README known limits): rc with `set -e` + unenterable folder exits before claude; zsh precmd-only setups (mise's default activation) don't run before Claude starts (direnv does, via chpwd); per-run statusLine re-read ignores `type`; project/local statusLine not chained.
T1: complete (commits 41ef2b9..9315cbc, review clean)
T2: dispatched (main checkout), BASE 9315cbc.
T2: implementer DONE d653479 (315 tests, hook-script 14/14; real installer run into a temp folder: kitty-0.50.0.dmg sha256+size verified, codesign/spctl/team NTY7FVCEKP, staging copy re-verified, cleanup clean).
PARITY LIVE: PATH identical to a terminal login shell (+kitty's own dir appended, as in any kitty window); SSH_AUTH_SOCK passed; LANG=en_GB.UTF-8 set by kitty; user skills/plugins listed in Chat; a --settings hook fired; Chat started in auto mode (user's default).
T2 review: Needs fixes. Important: (1) team check spoofable (codesign --verify accepts ad-hoc; -dv's first TeamIdentifier= line can be injected via the identifier) and relies on spctl alone (assessments may be disabled on developer Macs) → add a designated-requirement -R anchored to Apple Developer ID + leaf OU NTY7FVCEKP (tested on the real kitty); (2) missing digest skips the checksum → must abort.
Ruling: T2 fix round takes 1, 2 and Minors 3 (whole-URL regex), 4 (Cancel button + clean a leftover staging copy), 5 (next step in the "already exists" message), 6 (kill the process group on timeout) — installer safety is review focus 4 — cost: small.
T2: minor (deferred): `-o env=NELL_KITTEN=<path>` with `$` in the path (kitty expands $VAR in env values) — only for a home folder containing `$`.
T5 (README): dispatched in an isolated worktree.
T2: fix round 1 implemented 4298563 (319 tests, hook-script 14/14, live installer passed into scratch).
T2: fix round 1/5 (6 addressed; new Important: cancel can kill hdiutil attach mid-way → possible stray hidden mount; commits d653479..4298563). Pinned -R verified: kitty 0, Spotify/Discord/Calculator 3, spoofed ad-hoc 3.
T2: fix round 2/5 (1 addressed — attach runs uncancellable, no step starts after Cancel; spoof test asserts exit 3; controller verified the diff and reran 321 tests; commits 4298563..0e771b4)
T2: complete (commits 9315cbc..0e771b4, review clean)
T5: README DONE 486d162 (merged). Screens reused (screen locked). Flags: README says checksum only if published (now wrong after 4298563); login item re-registered every launch (may override the user's choice).
DMG E2E: package OK (1.5 MB, verify VALID); mounted volume has Nell.app, Applications link, How to open Nell.txt, LICENSE.txt, LICENSE-artwork.txt, THIRD_PARTY.md, .VolumeIcon.icns; copy to a spaced path: codesign --verify --deep --strict OK, lipo x86_64 arm64, minos 14.0, id io.github.hanamorix.nell 1.0.0, AppIcon, scripts 755; DMG copy ran --showcase crowded: 0 MISMATCH, no crash; quarantined copy → spctl rejected (confirms the How-to-open steps are needed). macOS 27.3 here; macOS 14/15 not available to test.
Final: whole-branch review and red team dispatched in parallel (base 50bd8c7, head 75a7df0).
Final review: With fixes — Important: login item re-registered every launch (overrides the user's choice, can register a /Volumes copy); no kitty version floor (old kitty → "couldn't start kitty" with no install offer); README checksum line stale; private paths (user's private artwork folder names, home path, fixture session ids) in public docs/fixtures (already on main — history rewrite is the owner's call).
Red team: Holds broadly (hostile folder names, rc files, locator, parser, digests, status/hook scripts, DMG from a spaced unicode path). Breaks: Important — a cd wrapper function/alias in rc sends Claude to $HOME (cd goes through user functions); Important — a `claude` alias/function is silently bypassed (README must say so); minor README gaps (CLAUDE_CONFIG_DIR, slow rc >10 s lookup).
Final: Ruling: one fix wave — builtin cd per shell; login item once (not from /Volumes or translocation, flag in SavedState); kitty version floor from kitty's changelog; NELL_MODE in the lookup env; scrub private paths from the current tree; README fixes (checksum, your default permission mode, log in to Claude first, alias/function, CLAUDE_CONFIG_DIR, slow rc) — cost: small. History rewrite left to the user.
Final: minor (deferred): compound status command leaves a stray child after SIGTERM (parity with Claude's own kill unverified); `alias exec` in rc; disableAllHooks in user settings also disables Nell's hooks; hdiutil deprecation warning.
LIVE: user's own (project) hook and Nell's --settings hook both fired on the same prompt in a throwaway kitty with Nell's launch argv; test hook file removed.
Final wave: DONE 7 commits (328 tests, hook-script 14/14). kitty floor 0.50.0 (changelog proves ≥0.48.1 only; 0.50.0 is the one verified version).
Final DMG (rebuilt from final code): verify VALID; contents complete; copy to a spaced unicode path: codesign OK, x86_64 arm64; showcase crowded from the copy: running, 0 MISMATCH; sha256 da4d24b0…3cb5, 1,583,518 bytes. 328 tests, hook-script 14/14.
Final wave re-review: 1–6 ADDRESSED. New Important: builtin cd skips the user's well-formed cd wrapper (nvm cdnvm, autoenv, rvm) that a terminal would run on entering the folder — parity trade-off. Minor: sh→dash has no `builtin`; empty version string → "Your kitty  is too old"; README:133 Chat nudge wording; v3 spec still says "mature-themed expression folders".
Final: Ruling: last narrow round — run the user's cd first, then guarantee the folder: `cd "$0"; [ "$PWD" -ef "$0" ] || <builtin|command \cd> -- "$0"` (reviewer-tested), sh uses `command \cd`; plus the three wording minors — cost: small.
Last narrow round: 12a0e23 6461f75 1dcf254 (328 tests, hook-script 14/14).
Last narrow round re-review: 2–5 ADDRESSED; 1 PARTLY (errexit + failing user cd stops the launch) → one-token fix dispatched.
Errexit fix ab2bd22 — controller verified with a real zsh (ERR_EXIT + failing cd wrapper → exec still runs in the folder); 328 tests, hook-script 14/14.
FINAL: DMG rebuilt from ab2bd22: verify VALID; contents complete; copy to a spaced unicode path: codesign OK, x86_64 arm64; showcase crowded from the copy: running, 0 MISMATCH; sha256 c4f93fa4…e224be, 1,585,908 bytes.

## Release day (2026-11-16)

- History purge (user's request): the user's private art-folder names and home path were in two v3 docs and two test fixtures on the public main, nell-v1 and nell-v2. They were rewritten in every commit with git-filter-repo `--replace-text`, using the same scrubbed wording the current tree already had. The tip tree is byte-identical and there are still 128 commits. A fresh mirror clone from GitHub has 0 hits in contents and messages. Authors were already the GitHub noreply address. There are no forks or PRs. GitHub still serves the old commits by exact SHA until its own clean-up.
- Ruling: strip the shipped binary. The DMG's binary held absolute build paths: 42 debug-map object paths plus Swift source paths. bundle.sh now builds with `-file-prefix-map <checkout>=.`, runs `strip -S` after lipo, and fails if the checkout path is still in the binary. Cost if wrong: crash logs from users lose local symbol names; our own symbols are still in the exported symbol table.
- DMG rebuilt from main: verify VALID; 0 private-string hits across the whole volume; 0 OSO stabs; codesign strict OK; x86_64 arm64; a copy at a spaced unicode path ran showcase crowded with 0 MISMATCH.
