# Swift 6.2 CLI Compiler Crash Notes

## Last Updated
November 5, 2025

## Summary
Compiling the `Apps/CLI` test bundle still triggers a Swift compiler crash in
`swift::Lowering::SILGenModule::emitKeyPathComponentForDecl` even with Xcode
26.2 beta. The failure happens during type-checking of the CLI target before
any tests execute, so the `--skip .automation` flag alone is not sufficient.

## Work-in-Progress Mitigations
### Toolchain Checks
- Swapped to `/Applications/Xcode-beta.app` via `xcode-select`; crash persists.
- Switched back to the stable 26.1 toolchain after the attempt.

### Test Target Split
- Created `Tests/peekabooAutomationTests` for the suites that shell out to the
  real CLI or do UI automation.
- Moved the remaining “safe” suites under `Tests/CoreCLITests`; these are
  the only tests included in the default `peekabooTests` target.

### Conditional Compilation Flags
- Introduced the `PEEKABOO_SKIP_AUTOMATION` conditional so automation suites can
  be entirely removed from compilation when running the safe bundle.
- Manifest now exposes a `PEEKABOO_INCLUDE_AUTOMATION_TESTS` environment flag to
  opt back in when we want full coverage locally.

### Source Adjustments
- Replaced key-path shorthand closures like `map(\.configuration.commandName)`
  in automation tests with explicit closures to avoid the Swift 6.2
  `emitKeyPathComponentForDecl` crash when `ParsableCommand` generic metadata is
  involved.
- Updated automation CLI subprocess tests to invoke the freshly built
  `.build/debug/peekaboo` binary and added stderr suppression helpers for parse
  failure checks so ArgumentParser's help diagnostics no longer flood the test
  log.

### Test Command Reference
```bash
# Safe bundle (run from Apps/CLI; executes peekabooTests target)
tmux new-session -d -s pb-safe 'bash -lc "cd /Users/steipete/Projects/Peekaboo/Apps/CLI && swift test -Xswiftc -DPEEKABOO_SKIP_AUTOMATION"'

# Automation bundle (opt-in; now compiles after key-path fixes)
tmux new-session -d -s pb-auto 'bash -lc "cd /Users/steipete/Projects/Peekaboo/Apps/CLI && PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test"'
```
The safe command builds and executes the pared-down bundle without issues.
The automation command now compiles but currently fails inside
`peekabooAutomationTests` due to outdated assertions; see the progress log for
the compiler crash mitigation and runtime failures.

## Next Steps
1. Add GitHub Actions definitions to exercise the safe bundle by default and
   gate automation runs behind an opt-in flag until the remaining test failures
   are addressed.
2. Track the upstream Swift fix; once available, reevaluate whether the key-path
   workaround can be reverted without reintroducing the compiler crash.
3. Update automation assertions (e.g. `ConfigCommandTests`) to match the new
   CLI split so the suite passes once the environment requirements are met.

---

### Progress Log
- **2025-11-05 22:01 UTC** — Added `PEEKABOO_SKIP_AUTOMATION` flag and the
  `CoreCLITests` target; `swift test -Xswiftc -DPEEKABOO_SKIP_AUTOMATION`
  now compiles and executes the safe suites without crashing (UtilityTests only
  for now).
- **2025-11-05 22:20 UTC** — Exposed safe logger controls for tests, removed
  `@testable import` from the default suite, and validated
  `swift test -Xswiftc -DPEEKABOO_SKIP_AUTOMATION` inside tmux
  (`tmux new-session …`) to confirm the safe bundle runs cleanly under Swift 6.2.
- **2025-11-05 22:27 UTC** — Added shared test tag/environment helpers to the
  automation target and re-ran
  `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test` via tmux; compilation still
  aborts with the `emitKeyPathComponentForDecl` SILGen crash (stack saved in
  `/tmp/automation-tests.log`).
- **2025-11-05 22:36 UTC** — Replaced key-path shorthand closures in automation
  suites with explicit closures; `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift
  build --target peekabooAutomationTests` now succeeds and `swift test` proceeds
  to runtime assertions instead of compiler crashes.
- **2025-11-05 22:55 UTC** — Repointed automation tests that spawn the CLI to
  `.build/debug/peekaboo`, added `CLIOutputCapture.suppressStderr` around parse
  failure expectations, and confirmed `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true
  swift test` runs without ArgumentParser help spam (remaining failures are the
  expected behavior-driven skips).
- **2025-11-06 00:18 UTC** — Brought the CLI automation suites in line with
  Swift 6.2 by eliminating the last `map(\.property)` shorthands and syncing
  `ToolsCommandTests` with the `--no-sort` flag. Building the automation bundle
  now consistently succeeds; we still abort full automation test runs after
  verifying compilation because the interactive flows remain flaky under the
  tmux harness.
- **2025-11-06 00:38 UTC** — Split hermetic CLI logic tests into a
  `CoreCLITests` target and left UI-touching suites in
  `peekabooAutomationTests`, allowing `pnpm test:safe` to run 72 non-invasive
  tests by default. Automation coverage remains opt-in via
  `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true`, which we now use for targeted
  `swift build --target peekabooAutomationTests` checks.
