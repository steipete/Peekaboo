---
summary: 'Playbook for debugging Swift SILGen compiler crashes during automation tests'
read_when:
  - 'stuck on fatal Swift compiler signals (5/6/11) building CLI tests'
  - 'trying to minimize repros before filing bugs with Apple'
---

# SILGen Crash Debug Notes

Swift 6.x still throws `swift-frontend` signal 5 when certain AST shapes hit SILGen. This doc collects the checklist we followed while chasing the `MenuCommandTests` crash so the next agent doesn’t have to rediscover it.

## Typical Symptoms
- `swift test` dies before any automation test runs, usually while compiling a single `*.swift` file.
- Stack dump points at SILGen key-path handling (`getOrCreateKeyPathGetter`, `emitKeyPathComponentForDecl`).
- Hitting the same file outside the automation suite (`swift build --target …`) reproduces instantly.

## Playbook
1. **Capture Logs**
   - Pipe `swift test` output to `/tmp/automation-tests.log` and save `/tmp/peekaboo-test-all.log` from `pnpm run test:all`.
   - Look for `-primary-file …/MenuCommandTests.swift` (or whichever file crashes) to narrow the scope.
2. **Bypass the Hot File**
   - Temporarily comment out the suspect test and re-run `swift test` with `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true` to confirm the crash disappears.
3. **Minimize the Pattern**
   - Rewrite the crashing construct in the smallest possible way (e.g., replace `subcommands.map(\.commandDescription.commandName)` with an explicit `for` loop). This often dodges the compiler bug without losing coverage.
   - If the crash persists, keep shrinking the test until only the problematic AST remains.
4. **Escalate Upstream**
   - When the repro is minimized, file it at https://bugs.swift.org with the stack dump attached. Mention the Swift version (from `swift --version`) and the minimized code snippet.

## Feature Flags & Test Gating
- `Apps/CLI/Package.swift` defines crash-mitigation flags (`PEEKABOO_DISABLE_IMAGE_AUTOMATION`, `PEEKABOO_DISABLE_DIALOG_AUTOMATION`, `PEEKABOO_DISABLE_DRAG_AUTOMATION`, `PEEKABOO_DISABLE_LIST_AUTOMATION`, and `PEEKABOO_DISABLE_AGENT_MENU_AUTOMATION`). Toggling these lets us bisect crashes without losing the entire automation target.
- Leave a short inline comment referencing this doc whenever you disable/skip a suite so future agents know why it disappeared.
- Use `PEEKABOO_SKIP_AUTOMATION` (or `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true` when enabling) to iterate locally before flipping the main guard back on.

## Lessons Learned
- SILGen hates certain key-path + generic combinations; “unrolling” the code is a surprisingly effective workaround.
- Always keep version control clean before rewriting tests so we can toggle changes on/off quickly.
- Even when we can’t fix the compiler, documenting the repro saves hours the next time.

## 2025-11-15 – WindowsSubcommand Automation Crash Log
- **Symptom**: `swiftpm-testing-helper` trapped while compiling `PIDWindowsSubcommandTests` because `ListCommand.WindowsSubcommand.jsonOutput` forced a `CommandRuntime` before Commander injected it. Crash log: `ListCommand.swift:125 ListCommand.WindowsSubcommand.jsonOutput.getter`.
- **Isolation steps**: Ran `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test --package-path Apps/CLI`, captured `/tmp/automation-test.log`, and pulled the matching `.ips` file (`~/Library/Logs/DiagnosticReports/swiftpm-testing-helper-2025-11-15-163326.ips`). The stack showed the getter being evaluated inside `#expect(command.jsonOutput == true)`.
- **Mitigation**: Made every `ListCommand` subcommand conform to `RuntimeOptionsConfigurable` so parsed CLI flags populate `runtimeOptions` even when tests only instantiate the type. Their `jsonOutput` accessors now fall back to `runtime?.configuration` or `runtimeOptions` which avoids touching the `CommandRuntime` before Commander hands it in.
- **Verification**: `swift test --package-path Apps/CLI -Xswiftc -DPEEKABOO_SKIP_AUTOMATION` and `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test --package-path Apps/CLI` both pass, with automation suites only skipping the RUN_LOCAL_TESTS-gated cases.
- **Takeaway**: Precondition traps can mimic SILGen crashes when they fire during compilation/test discovery. Always double-check `.ips` frames—if they point at our own getters, rewrite the code to avoid forcing runtime state during parsing.
