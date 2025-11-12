---
summary: 'Record the current lint situation and outline the refactor plan.'
read_when:
  - 'tackling lint regressions or prepping a refactor that crosses many files'
  - 'planning doc changes that need editor or playground upkeep'
---

# Linting & Formatting Roadmap

## Current status (November 12, 2025)

- SwiftLint run from the repo root (`swiftlint --config .swiftlint.yml`) emits ~760 warnings/errors spread across 616 Swift files. The biggest concentrations are huge CLI test suites (type_body_length/file_length), SwiftUI playground views (line_length/cyclomatic_complexity/multiple closures with trailing closures), and some helper/test utilities with force-casts/force-tries.
- Commander now obeys the lint rules—our new DocC work introduced no fresh violations. The remaining noise is entirely inside CLI + Playground targets that pre-date this change.
- Automating the fix must be surgical; the current solution will focus on the playground views first because the warning density there is lower and the necessary changes are localized (remove trailing-closure syntax, shorten long lines, drop stale suppressions).

## Short-term tasks (today)

1. **Document the refactor plan** (this file) so other agents/engineers know where to land the long-standing issues.
2. **Refactor Playground views** to use explicit `label:`/`action:` closures instead of only trailing closures and remove unused `swiftlint:disable` pragmas in `LogViewerWindow`.
3. **Shorten blatantly long view methods** (e.g., chunk `PlaygroundApp` / `ControlsView` if possible) and prepare follow-up issues for the CLI tests that exceed `function_body_length` or `file_length` thresholds.

## Mid/long-term plan (next wave)

- Break `CommanderBinderTests` and similarly oversized suites into smaller files/suites so they fall below `type_body_length`/`file_length` limits while keeping loops of helper functions grouped logically.
- Triage the remaining `function_body_length`/`cyclomatic_complexity` warnings in `PlaygroundApp` by extracting helpers and adopting `#warning` stubs for large but stable blocks; consider permalinks for complexity-critical sections.
- Work through the `force_cast`/`force_try` hotspots in test helpers by wrapping them in safe wrappers or using `XCTUnwrap` style assertions (preferring `fatalError` only when truly unreachable).
- Re-run SwiftLint with `--reporter json` after each batch and capture the residual warnings in a follow-up section of this doc.

## Communication

- Mention the lint count when you reopen CI runs; post-cleanup, future docs should reference this file to track progress.
- If any rule needs temporary relaxation, add it to `.swiftlint.yml` with a clear justification and document it here (use `read_when` to capture when to revisit).
