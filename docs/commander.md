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
   - Help text uses the existing `CommandDescription` builders already embedded in every command file, plus metadata from `CommandSignature` to display options/flags in Commander’s help output.
3. **Shared metadata**:
   - `CommandRegistry` (already in `CLI/Configuration`) feeds Commander so subcommand lists stay synchronized between CLI, docs, and agents.
   - Commander exposes a `describe()` API so `peekaboo tools`/`peekaboo learn` and MCP metadata reuse the same structured definitions.

## 3. Parsing Features & API Surface
- **Options/flags**: retain existing DSL (e.g., `@Option(name: .customShort("v"), parsing: .upToNextOption)`) and support the handful of strategies we actually use (`singleValue`, `upToNextOption`, `remaining`, `postTerminator`).
- **Negated flags**: replicate ArgumentParser’s `inversion` behavior by allowing `.prefixedNo`/`.prefixedEnableDisable` naming; Commander auto-generates `--no-foo` aliases when requested.
- **Option groups**: Commander honors nested `@OptionGroup` declarations, merging grouped options into help output exactly like Commander.js’ `.addOption(new Command())` pattern.
- **Validation**: property wrappers can throw `CommanderValidationError(message:)` from their `load` hooks; router surfaces that as a user-facing error (with JSON code `INVALID_INPUT`).
- **Custom parsing**: `@Argument(transform:)` keeps working by invoking the supplied closure once Commander has the raw string.
- **Standard runtime options**: `CommandSignature.withStandardRuntimeFlags()` injects `-v/--verbose`, `--json-output`, and `--log-level <trace|verbose|debug|info|warning|error|critical>` for every command so tooling can toggle logging consistently.

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
   - Port the small helper protocols/types we rely on (`ExpressibleFromArgument`, `MainActorCommandDescription`) directly into Commander and delete the last traces of the ArgumentParser compatibility shim.
2. **Wire PeekabooCLI**
   - Swap `import ArgumentParser` -> `import Commander` across CLI sources.
   - Update `Peekaboo` root command to register subcommands via CommandRegistry instead of Apple’s `CommandDescription` array.
   - Replace uses of `ArgumentParser.ValidationError`/`CleanExit` with Commander equivalents.
   - Remove Apple-specific extensions such as `MainActorParsableCommand` since Commander handles main-actor dispatch natively.
3. **Update other packages**
   - Point AXorcist CLI (`AXorcist/Sources/axorc/AXORCMain.swift`) and Tachikoma example CLIs at Commander; ensure they keep their current UX.
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
   - 🔄 *In progress (Nov 11, 2025): `CommanderRegistryBuilder` now emits both descriptors and normalized summaries so `learn`/`commander` no longer import Commander (no more `@OptionGroup` collisions), the diagnostics command prints those summaries, CommanderPilot runs `peekaboo learn`, `peekaboo sleep`, `peekaboo clean`, and `peekaboo run` via Commander, and the entire CLI builds cleanly again (`./runner swift build --package-path Apps/CLI`) after tagging every `AsyncRuntimeCommand` conformance with inline `@MainActor` and moving the protocol’s `run(using:)` requirement under `@MainActor`. `CommanderCLIBinder` exposes `CommanderBindableCommand`; `SleepCommand`, `CleanCommand`, `RunCommand`, `ImageCommand`, `SeeCommand`, `ToolsCommand`, `list windows`, `list menubar`, and `permissions` (status + grant) all conform so Commander hydrates positional arguments plus their `@Flag`/`@Option` inputs automatically, the `CommanderBinderTests` target covers success/error paths for each, and a new `CLIRuntimeTests` target (swift-subprocess) now runs the `peekaboo commander` and `peekaboo list windows` flows as an end-to-end binary smoke test. Next focus: keep rolling the binder helpers across CLI commands and extend the subprocess regression suite.*
   - 🔄 *Update (Nov 11, 2025 PM): `CommandDescriptor` now tracks nested subcommand metadata (including default subcommands) and `Program.resolve` returns the full command path so `CommanderRuntimeRouter` can hydrate the correct `ParsableCommand` type even for chains like `peekaboo list windows`. `CommandParser` learned proper `--` terminator semantics plus a catch-all `.remaining` sink so tail arguments no longer get swallowed by the preceding option. Commander summaries/diagnostics now emit hierarchical trees, and we have tmux-gated `swift test --package-path Apps/CLI --filter ParserTests` + `--filter CLIRuntimeSmokeTests` logs to prove both the Commander unit suite and the subprocess smoke tests pass with the new behavior.*
   - 🔄 *Update (Nov 11, 2025 evening): Every `window` subcommand (close/minimize/maximize/move/resize/set-bounds/focus/list) plus the `click`, `type`, `press`, `scroll`, `drag`, `hotkey`, and `swipe` interaction commands now conform to `CommanderBindableCommand`. The binder seeds fresh `WindowIdentificationOptions`/`FocusCommandOptions` instances so the OptionGroup wrappers stay happy, and the `CommanderBinderTests` suite gained coverage + regression errors for those bindings. tmux logs: `/tmp/commander-binder.log` for binder tests, `/tmp/commander-tests.log` for Commander.Parser tests.*
   - 🔄 *Update (Nov 11, 2025 late PM): Added `CommanderSignatureProviding` so commands can describe their option/flag metadata without relying on Apple’s wrappers. `image`, `see`, every `list` subcommand, `click`, `type`, `press`, `scroll`, `hotkey`, `move`, `drag`, `swipe`, `menu` (click/click-extra/list/list-all), `app` (launch/quit/hide/unhide/switch/list/relaunch), `permissions`, `tools`, `space` (list/switch/move-window), `dialog` (click/input/file/dismiss/list), `window` (close/min/max/move/resize/set-bounds/focus/list), and the shared option groups (`FocusCommandOptions`, `WindowIdentificationOptions`) now publish full Commander signatures. `CommanderRegistryBuilder` flattens these option groups before emitting descriptors, and new binder tests assert that `Program.resolve()` understands real-world invocations across screenshot/vision/list/system/interaction workflows (`peekaboo window focus --app Safari …`, `peekaboo dialog input --text …`, `peekaboo space move-window …`, etc.). Commander is effectively parsing the entire CLI surface; remaining work is wiring MCP/agent-specific commands before removing the ArgumentParser fallback.*

3. **Full Command Migration**
   - Convert every command in `Apps/CLI` to use Commander wrappers exclusively; remove the fallback path once parity is confirmed.
   - Port AXorcist CLI and Tachikoma examples to Commander.
   - Delete the vendor `swift-argument-parser` folder and scrub all imports/retroactive conformances referencing Apple’s APIs.

4. **Regression Testing & Cleanup**
   - Add `swift-subprocess`-based CLI regression tests that run the built binary to cover happy-path and failure-path scenarios. ✅ `CLIRuntimeTests` (Nov 11, 2025) shells out to `peekaboo commander` and `peekaboo list windows` to exercise the installed binary.
   - Expand Commander unit tests to include error cases, help rendering, and option-group behaviors.
   - Run tmux-gated `swift build`/`swift test` suites, fix any stragglers, and document the migration status in AGENTS.md / release notes.

## 9. Progress Snapshot (Nov 11, 2025)

- **Hierarchy-aware descriptors**: Commander now builds a full command tree (root commands + subcommands + default-subcommand pointers). `Program.resolve` walks the tree, records the command path, and surfaces specific `CommanderProgramError` cases for missing/unknown subcommands.
- **Runtime routing**: `CommanderRuntimeRouter` reuses the resolved path to locate the right `ParsableCommand` type, so downstream binders can hydrate nested commands without guessing. The diagnostics JSON mirrors this hierarchy for `peekaboo commander`/`peekaboo learn` consumers.
- **Parser polish**: The tokenizer no longer feeds terminator tails into the preceding `.upToNextOption`, and any signature that declares a `.remaining` option automatically receives the `--` tail (matching how we model “implicit rest” arguments in CLI commands).
- **Binder coverage**: `CommanderCLIBinder` now hydrates `window close/minimize/maximize/move/resize/set-bounds/focus/list` plus the entire interaction/system surface: `click`/`type`/`press`/`scroll`/`drag`/`hotkey`/`swipe`/pointer `move`, menu (`menu click`/`click-extra`/`list`/`list-all`), Dock (`dock launch`/`right-click`/`list`/hide/show), dialog (`dialog click`/`input`/`file`/`dismiss`/`list`), high-level `app` commands (`launch`/`quit`/`hide`/`unhide`/`switch`/`list`/`relaunch`), `space` management (`space list`/`switch`/`move-window`), `permissions` (CLI + agent), and the full `config` suite (`init`/`show`/`edit`/`validate`/`set-credential`/`add-provider`/`list-providers`/`test-provider`/`remove-provider`/`models-provider`). Commander now owns essentially the entire CLI surface; the remaining work is wiring the agent/MCP command trees and flipping the runtime to prefer Commander end-to-end (with tmux logs in `/tmp/commander-binder.log` demonstrating 55 passing binding tests).
- **Signature providers**: `CommanderSignatureProviding` lets commands publish their metadata explicitly. The current adopters span `image`, `see`, all `list` subcommands, interaction verbs (`click`, `type`, `press`, `scroll`, `hotkey`, `move`, `drag`, `swipe`), system controllers (`menu`, `app`, `window`, `dialog`, `space`, `permissions`, `tools`, `dock`), plus the shared option groups (`FocusCommandOptions`, `WindowIdentificationOptions`). Every option/flag (app/pid/window-title/include-details/annotate/query/session/delay/tab/count/hold/direction/amount/modifiers/server filters/focus flags/etc.) now has Commander metadata, and the registry flattens these option groups so flags like `--no-auto-focus` and `--space-switch` parse correctly. Next up: cover MCP + agent entry points and begin routing the CLI through CommanderPilot so we can delete ArgumentParser entirely.
- **Tests executed**: `swift test --package-path Apps/CLI --filter ParserTests` (Commander unit suite, log `/tmp/commander-tests.log`), `swift test --package-path Apps/CLI --filter CommanderBinderTests` (log `/tmp/commander-binder.log`), and `swift test --package-path Apps/CLI --filter CLIRuntimeSmokeTests` (log `/tmp/cli-runtime.log`) all run via the tmux runner.
- **Outstanding**: Map the remaining CLI commands onto `CommanderBindableCommand`, teach CommanderPilot (or the main entry point) to route additional command families through Commander, and start deleting the ArgumentParser vendored tree once parity + subprocess coverage exists for every command.

### Progress 2025-11-11 – Build Stabilization & Tests

- Dropped the `Sendable` constraint from Commander’s property wrappers and `CommanderParsable` so `@MainActor` CLI helper structs (e.g., `WindowIdentificationOptions`, `FocusCommandOptions`) can register metadata without tripping `#ConformanceIsolation`. Conditional `Sendable` extensions keep the wrappers sendable when possible.
- Exposed `CommandParser` publicly and pointed `ParsableCommand.parse(_:)` at Commander so legacy unit tests keep working without reviving ArgumentParser. This also unlocked `ToolsCommandTests`, which now read `CommandDescription` directly instead of calling the deleted `helpMessage()` helpers.
- Fixed `SeeCommand`’s capture switch to cover the `.multi` and `.area` cases Commander now parses, preventing fatal fallthroughs, and aligned `WindowIdentificationOptions` bindings with the shared metadata helpers.
- `./runner swift build --package-path Apps/CLI` now succeeds from a clean tree, and `./runner swift test --package-path Apps/CLI --filter CommanderBinderTests` passes (see session log timestamp 20:34 local); CommanderBinder continues to verify ~70 binding scenarios after the refactor.
- Added `executePeekabooCLI(arguments:)` so in-process automation tests can exercise the Commander runtime without resurrecting `parseAsRoot`. `InProcessCommandRunner` now routes through that helper, and the same error-printing path as the shipping CLI is reused for test assertions.
- Reintroduced `helpMessage()` via a lightweight `CommandHelpRenderer` that inspects `CommandSignature` metadata, so the automation suites (List/MCP/Tools) can keep verifying help content purely through Commander descriptors.
- Revived the `peekabooTests` suites (`ClickCommandAdvancedTests`) by removing their `*.disabled` suffixes and updating them to use Commander-era helpers; they now validate command metadata, parsing, and help output without importing ArgumentParser.
- `./runner swift build --package-path Apps/CLI` now succeeds from a clean tree, and `./runner swift test --package-path Apps/CLI --filter CommanderBinderTests` passes (see session log timestamp 20:34–20:41 local); CommanderBinder continues to verify ~70 binding scenarios after the refactor.
- `scripts/run-commander-binder-tests.sh` tees every CommanderBinder test run into `/tmp/commander-binder.log`, adding a UTC-stamped header before appending the fresh output so investigators can diff multiple runs without re-running the suite.
- With those suites green again, MCP/agent coverage now spans: (1) binder-level resolution tests for `serve` plus Commander metadata snapshots via `peekabooTests`, and (2) CLI automation helpers hitting `executePeekabooCLI`. Once we confirm no other modules import ArgumentParser, we can delete `Vendor/swift-argument-parser` and scrub the dependency graph.
- `CLIRuntimeSmokeTests` now shell out via swift-subprocess for `peekaboo list apps --json-output`, `peekaboo list windows --json-output` (error path), `peekaboo sleep`, and `peekaboo mcp --help`. That gives us fast end-to-end coverage that Commander is powering the MCP command surfaces without pinging live MCP servers.
- Commander is now a standalone Swift package under `/Commander`. Apps/CLI, AXorcist, Tachikoma (including Examples and Agent CLI), and PeekabooExternalDependencies all depend on it instead of the vendored swift-argument-parser tree. The vendor folder has been deleted.
- New Commander unit tests (`TokenizerTests`, `CommandDescriptionTests`) cover single-letter options, combined flags, the `--` terminator, and regression coverage for the metadata builders.
- `CLIRuntimeSmokeTests` gained MCP help coverage and agent dry-run scenarios so we exercise Commander on those code paths without real credentials.

**Next up (owner: whoever picks up the baton):**
1. **Harden retroactive conformances.** The CLI emits warnings for the Commander argument conformances (`CaptureMode`, `ImageFormat`, `CaptureFocus`). Either adopt Swift’s `@retroactive` support once it lands or find another way (e.g., intermediate wrapper types) to silence the warnings.
2. **Surface Commander as a documented dependency.** Update AGENTS.md/other guides to call out the new `/Commander` package (partly done) and describe how other repos should depend on it.
3. **Broaden subprocess coverage.** Add additional swift-subprocess scenarios for MCP `serve` (stdio failure) and agent session listing/resume so CI keeps exercising those flows without external credentials.
