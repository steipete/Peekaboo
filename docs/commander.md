---
summary: 'Commander CLI parsing redesign for Peekaboo'
read_when:
  - Replacing ArgumentParser in the CLI
  - Touching Peekaboo command-line parsing/runtime code
---

# Commander Migration Plan

## 1. Objectives
- Eliminate the vendored Apple ArgumentParser fork and its maintenance burden.
- Keep the ergonomics of property-wrapper-based command definitions while ensuring every command executes inside our `CommandRuntime` flow.
- Centralize command metadata so docs, CLI help, agents, and regression tests share one source of truth.
- Add end-to-end CLI regression tests that shell out to the `peekaboo` binary via `swift-subprocess`.

## 2. Target Architecture
1. **Commander module** (new Swift target shared by PeekabooCLI, AXorcist, and Tachikoma examples):
   - `CommandDescriptor` tree representing commands, options, flags, and arguments.
   - Property wrappers (`@Option`, `@Argument`, `@Flag`, `@OptionGroup`) that simply register metadata with a local `CommandSignature` rather than parsing on their own.
   - Lightweight `ExpressibleFromArgument` protocol (replacing Apple’s `ExpressibleByArgument`) with conformances for primitives, enums, and Peekaboo types like `CaptureMode`/`CaptureFocus`.
   - `CommandRouter` inspired by Commander.js: tokenizes argv, traverses the descriptor tree, populates property wrappers, and dispatches to the appropriate command type.
2. **Runtime integration**:
   - Each command continues to conform to `AsyncRuntimeCommand`; the router constructs the command, injects parsed values, creates `CommandRuntime`, and calls `run(using:)` on the main actor.
   - Errors flow through existing `outputError` helpers; Commander emits `CommanderError` cases (missing argument, unknown flag, etc.) that we map to `PeekabooError` IDs for consistent JSON output.
   - Help text uses the existing `CommandConfiguration` builders already embedded in every command file, plus metadata from `CommandSignature` to display options/flags in Commander’s help output.
3. **Shared metadata**:
   - `CommandRegistry` (already in `CLI/Configuration`) feeds Commander so subcommand lists stay synchronized between CLI, docs, and agents.
   - Commander exposes a `describe()` API so `peekaboo tools`/`peekaboo learn` and MCP metadata reuse the same structured definitions.

## 3. Parsing Features & API Surface
- **Options/flags**: retain existing DSL (e.g., `@Option(name: .customShort("v"), parsing: .upToNextOption)`) and support the handful of strategies we actually use (`singleValue`, `upToNextOption`, `remaining`, `postTerminator`).
- **Negated flags**: replicate ArgumentParser’s `inversion` behavior by allowing `.prefixedNo`/`.prefixedEnableDisable` naming; Commander auto-generates `--no-foo` aliases when requested.
- **Option groups**: Commander honors nested `@OptionGroup` declarations, merging grouped options into help output exactly like Commander.js’ `.addOption(new Command())` pattern.
- **Validation**: property wrappers can throw `CommanderValidationError(message:)` from their `load` hooks; router surfaces that as a user-facing error (with JSON code `INVALID_INPUT`).
- **Custom parsing**: `@Argument(transform:)` keeps working by invoking the supplied closure once Commander has the raw string.

## 4. Execution Flow
1. `runPeekabooCLI()` builds the root `Commander.Program` using `CommandRegistry.entries` and hands it `CommandRuntime.Factory` for runtime injection.
2. Commander parses `ProcessInfo.processName`/`CommandLine.arguments` (minus the executable path) and resolves the command chain.
3. Parsed values hydrate the command instance via reflection (mirroring how Commander.js assigns option results).
4. Commander constructs `CommandRuntime` from `CommandRuntimeOptions` and calls `run(using:)`.
5. On failure, Commander prints Peekaboo-formatted errors; on `--help`, it renders the curated help text while skipping execution.

## 5. Implementation Steps
1. **Bootstrap Commander module**
   - Create `Sources/Commander` with descriptors, parser, tokenizer, and property wrappers.
   - Provide adapters for `@Option`, `@Flag`, `@Argument`, `@OptionGroup`, `@OptionGroup(title:)`, and `@OptionGroup(help:)`.
   - Port the small helper protocols/types we rely on (`ExpressibleByArgument`, `MainActorCommandConfiguration`) into Commander.
2. **Wire PeekabooCLI**
   - Swap `import ArgumentParser` -> `import Commander` across CLI sources.
   - Update `Peekaboo` root command to register subcommands via CommandRegistry instead of Apple’s `CommandConfiguration` array.
   - Replace uses of `ArgumentParser.ValidationError`/`CleanExit` with Commander equivalents.
   - Remove Apple-specific extensions such as `MainActorParsableCommand` since Commander handles main-actor dispatch natively.
3. **Update other packages**
   - Point AXorcist CLI (`Core/AXorcist/Sources/axorc/AXORCMain.swift`) and Tachikoma example CLIs at Commander; ensure they keep their current UX.
   - Delete `Vendor/swift-argument-parser` and remove the dependency from every affected `Package.swift` (Peekaboo, AXorcist, Tachikoma, Examples).
4. **Testing**
   - Add Swift Testing target `CommanderTests` for the module itself (unit tests for option parsing, error cases, help rendering).
   - Add CLI regression tests under `Apps/CLI/Tests/CLIRuntimeTests` that invoke the built binary via `swift-subprocess`. Cover:
     - `peekaboo list apps --json-output`
     - `peekaboo see --mode screen --path /tmp/test.png --json-output`
     - Failure (unknown flag) and `--help` output snapshot checks.
   - Ensure tests run in CI via tmux wrapper per AGENTS.md instructions.
5. **Cleanup & documentation**
   - Remove the vendored folder, stale docs (`docs/argument-parser.md`, `docs/swift-argument-parser.md` already deleted), and update any README/learn outputs referencing Apple’s parser.
   - Update `CommandRegistry`/`learn` command to mention Commander as the parsing layer.

## 6. Rollout & Verification
1. Build + run targeted CLI commands locally to confirm output matches current behavior (including JSON formatting and verbose logging).
2. Re-run long tmux suites (`./runner swift build`, targeted `swift test` subsets) to catch concurrency regressions.
3. Monitor the new CLI subprocess tests in CI; they become the primary guardrail against future “help-only” regressions.
4. Document Commander’s API in-code (`Sources/Commander/README.md` or inline doc comments) so future commands know how to declare options.

## 7. Open Questions / Follow-Ups
- Do we need compatibility shims for third-party tools that still import Apple’s `ArgumentParser`? If yes, expose a tiny transitional module that re-exports Commander types under the old names until everything migrates.
- Should Commander expose a programmatic API for MCP/agents to request command metadata? (Likely yes; we can extend `CommandRegistry.definitions()` to serialize Commander descriptors.)
- Investigate reusing Commander for other binaries (e.g., `axorc`, `tachikoma`) once PeekabooCLI migration is stable.

With this plan, we fully control CLI parsing, remove the Swift 6 actor headaches, and finally have end-to-end tests that ensure the CLI actually executes commands instead of falling back to help text.

## 8. Implementation Stages

1. **Module Scaffolding**
   - Create `Sources/Commander` target with the foundational types: tokeniser, command descriptors, property wrappers, minimal dispatcher, and `ExpressibleFromArgument`.
   - Wire Commander into `Package.swift` files (PeekabooCLI, AXorcist, Tachikoma) alongside existing dependencies while still leaving ArgumentParser in place so the old commands keep compiling.
   - Add placeholder unit tests (`CommanderTests`) that exercise the tokenizer and descriptor builder.
   - ✅ *Status (Nov 11, 2025): target, property wrappers, and initial signature tests are in place; Commander builds independently.*

2. **Dual-Wire PeekabooCLI**
   - Introduce an adapter layer that lets existing commands register with Commander (via `CommandRegistry`) while still compiling against ArgumentParser property wrappers.
   - Update the CLI entry point (`runPeekabooCLI`) to invoke Commander first; if parsing succeeds, run the command via CommandRuntime; otherwise temporarily fall back to ArgumentParser for unported commands.
   - Build the first concrete subcommand (e.g., `RunCommand`) purely on Commander to validate the flow end-to-end.
   - 🔄 *In progress: `CommanderRegistryBuilder` now exports descriptors/signatures, Commander’s `Program.resolve(argv:)` can parse argv, `CommanderRuntimeRouter` maps back to Swift command types, and `CommanderPreview` logs resolved commands inside `runPeekabooCLI` without changing execution yet.*

3. **Full Command Migration**
   - Convert every command in `Apps/CLI` to use Commander wrappers exclusively; remove the fallback path once parity is confirmed.
   - Port AXorcist CLI and Tachikoma examples to Commander.
   - Delete the vendor `swift-argument-parser` folder and scrub all imports/retroactive conformances referencing Apple’s APIs.

4. **Regression Testing & Cleanup**
   - Add `swift-subprocess`-based CLI regression tests that run the built binary to cover happy-path and failure-path scenarios.
   - Expand Commander unit tests to include error cases, help rendering, and option-group behaviors.
   - Run tmux-gated `swift build`/`swift test` suites, fix any stragglers, and document the migration status in AGENTS.md / release notes.
