---
summary: 'WIP notes for open/app launcher abstraction and test plan'
read_when:
  - 'resuming the open-command test/abstraction refactor'
  - 'continuing work on app launch --open behavior tests'
---

# Open command + app launch test refactor (WIP)

## Current state (Nov 14, 2025)

- Added pure resolution tests (`OpenCommandResolutionTests`, `AppCommandLaunchOpenTargetTests`) covering URL/path parsing.
- Introduced launcher/resolver abstractions (`ApplicationLaunching`, `RunningApplicationHandle`, `ApplicationURLResolving`) and updated both `OpenCommand` + `AppCommand.LaunchSubcommand` to depend on them.
- Added flow tests (`OpenCommandFlowTests`, `AppCommandLaunchFlowTests`) using stub launchers/resolvers to verify command wiring.
- Still missing:
  - **CLI help/doc polish:** Update `help open`, `help app launch`, and CLI docs once behavior is locked.
  - **Runtime-level tests:** Add `InProcessCommandRunner`-style tests to ensure JSON output + logging remain stable around the new options.

## Proposed approach

1. **Introduce abstractions**
   - Create `ApplicationLaunching` protocol + default `NSWorkspace` implementation (probably in `Commands/System/ApplicationLaunching.swift`).
   - Provide a `RunningApplicationHandle` protocol so tests can stub `isFinishedLaunching`, `activate`, etc.
   - Add `ApplicationURLResolving` for name/bundle resolution; default implementation wraps existing logic.
   - Wire `OpenCommand` and `AppCommand.LaunchSubcommand` to reference `ApplicationLaunchEnvironment.launcher`/`resolver` so tests can swap them.

2. **Tests**
   - New test suites in `CoreCLITests` that inject fake launchers/resolvers and assert:
     - Flags/JSON output path.
     - Activation + wait semantics (simulate `isFinishedLaunching` toggles).
   - Extend CLI runtime tests (or add a new `LaunchCommandFlowTests`) that run through `InProcessCommandRunner` using the stubs, ensuring no AppKit calls are made.

3. **Docs/help**
   - Update CLI help strings after the feature stabilizes (app launch discussion block + `open` subcommand doc block).

## Next steps when resuming

1. Update CLI help text (`help open`, `help app launch`) and the command reference doc to mention the new options explicitly.
2. Add runtime-level tests using `InProcessCommandRunner` to verify JSON payloads/outputs for both commands (default vs. overrides).
3. Ensure the helper docs (and possibly README examples) reflect the new `--open` and `peekaboo open` usage once everything is stable.
