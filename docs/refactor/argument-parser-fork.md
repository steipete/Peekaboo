# ArgumentParser Fork – Approachable Concurrency

## Repository & Branch
- Path: `/Users/steipete/Projects/swift-argument-parser`
- Branch: `approachable-concurrency`
- Upstream: `apple/swift-argument-parser` (tracked via fork)

## Changes Implemented
1. Marked the core protocols as preconcurrency-safe so they can be used from a module compiled with `.defaultIsolation(MainActor.self)`:
   - `ParsableArguments`
   - `ParsableCommand`
   - `AsyncParsableCommand`
2. Dropped the `_SendableMetatype` constraint (and its `ExpressibleByArgument` adoption) so `ParsableArguments` types no longer need to satisfy `Sendable` metatype requirements before the compiler lets them conform under MainActor isolation.
3. Verified `swift test` on the fork to ensure there are no regressions (only existing `customDeprecated` warnings remain).

## Integration in Peekaboo
- Updated all packages that depended on ArgumentParser to point to the local fork via path dependency:
  - `Apps/CLI/Package.swift`
  - `Examples/Package.swift`
  - `Core/AXorcist/Package.swift`
  - `Core/PeekabooExternalDependencies/Package.swift`
  - `Tachikoma/Examples/Agent-CLI/Package.swift`
- Re-enabled `.defaultIsolation(MainActor.self)` for the CLI target so it now shares the same "approachable concurrency" configuration as the rest of the workspace.

## Outstanding Work
- Sweep through every CLI command/utility and add the necessary `@MainActor` annotations or asynchronous hops so the project compiles cleanly under the restored isolation defaults.
- Once the CLI builds, run `swift test` for each package (in tmux, per project rules) to confirm everything is green.
- Consider upstreaming the preconcurrency tweaks once the approach stabilizes.
