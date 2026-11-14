# Nell project conventions

## Documents
- Name every doc `YYYY-MM-DD-<topic>-<type>.md`, using the date it was written.
- File it by type:
  - `docs/specs/` for approved designs (`-design.md`)
  - `docs/plans/` for implementation plans (`-plan.md`)
  - `docs/notes/` for spike findings and build ledgers (`-findings.md`, `-build-ledger.md`)
  - `docs/research/YYYY-MM-DD-<topic>/` for research, holding `report.md` and `notes/`
- These folders replace the skills' default `docs/superpowers/...` locations.
- Add every new doc to the index in `docs/README.md` in the same change, with a one-line description.
- Art goes in `artwork/`: `concept/` for reference art, and one folder per animation state (for example `artwork/typing/`).

## Build
- There's no Xcode, only the Command Line Tools. Run tests with `scripts/test.sh`, which loads the Swift Testing macro plugin explicitly.
- Don't use SwiftUI `@State`, because its macro plugin ships only with Xcode. Use `@StateObject` or `@Published` instead.
- Package the app with `bash scripts/bundle.sh`.
