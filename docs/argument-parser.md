---
summary: 'Refactor plan to simplify ArgumentParser usage'
read_when:
  - Planning CLI architecture work
  - Touching the vendored ArgumentParser fork
---

# ArgumentParser Refactor Plan

Peekaboo’s CLI is effectively single-threaded but must satisfy Swift’s strict concurrency rules. The current workaround (per-command MainActor bridges and `CommandConfigurationBridge`) makes new commands error-prone. This plan consolidates the fixes so ArgumentParser feels as ergonomic as Commander.js while retaining our MainActor guarantees.

## Objectives

1. Remove per-command boilerplate for `configuration` and logging.
2. Treat the CLI as a declarative registry that tools/tests can inspect.
3. Share the same command metadata with docs, agents, and potential codegen.

## Phases

### Phase 1 – Vendored Fork Enhancements

- Extend `Vendor/swift-argument-parser` so `ParsableCommand.configuration` is `@MainActor` by default when compiled with our MainActor support.
- Ship a safe `MainActorCommandConfiguration.build { … }` helper inside the fork that handles `DispatchQueue.main.sync` fallback internally.
- Update `Apps/CLI/Sources/PeekabooCLI/Commands/Base/CommandProtocols.swift` to remove `CommandConfigurationBridge` and switch commands back to plain `static var configuration`.

### Phase 2 – Command Runtime Injection

- Introduce `CommandRuntime` (logger, permission checker, PeekabooServices access, JSON formatter).
- Provide a `@OptionGroup` for global flags (`--verbose`, `--json-output`, capture targets, etc.) so commands compose behaviors instead of duplicating stored properties.
- Update key commands (`SeeCommand`, `ClickCommand`, etc.) to depend on the runtime/context instead of touching singletons directly.

### Phase 3 – Declarative Registry

- Define a `CommandRegistry` that lists every command type, metadata, and option groups. The root command (`Peekaboo`) should iterate over the registry rather than enumerating subcommands manually.
- Expose the registry as structured data (e.g., `PeekabooCommands.json`) so the `learn` command, MCP metadata, and agent prompts stay in sync automatically.
- Mirror the registry format with `mcporter`’s generator so future Commander-based tooling (or docs) can be emitted from the same source of truth.

### Phase 4 – Testing & Tooling

- Build Swift Testing suites that instantiate registry entries with fake `CommandRuntime` instances, enabling coverage without invoking ArgumentParser end-to-end.
- Add smoke generators that serialize the registry and ensure every command’s help output includes the global sections (permissions, config, etc.).

## Exit Criteria

- No command references `CommandConfigurationBridge`.
- New commands only implement their handler and reusable option groups; `configuration` is boilerplate-free.
- Docs, MCP metadata, and `peekaboo learn` leverage the same registry payload.
- Swift Testing targets cover command behavior without compiler crashes.

## Current Status (Nov 2025)

- Reapplied runtime plumbing to the “core feel” commands the agents hit most often:
  - Interaction commands `sleep`, `click`, `scroll`, `type`, `press`, `hotkey`, **and now `move`, `drag`, `swipe`** read logger/services from `CommandRuntimeOptions` and conform via `@MainActor extension CommandName: AsyncRuntimeCommand {}`.
- Dock subcommands `launch`, `right-click`, `hide`, `show`, and `list` now conform directly to `AsyncParsableCommand & AsyncRuntimeCommand`, cache their runtime via `@RuntimeStorage`, and feed every JSON/error helper through their injected logger.
  - Menu subcommands `click` and `click-extra` were converted to the fully qualified extension style.
- `SeeCommand` now participates in the runtime flow: the command declares `@OptionGroup CommandRuntimeOptions`, switches to `run(using runtime: CommandRuntime)`, and routes all service + logging calls through injected helpers (`self.logger`/`self.services`). Smart label generation follows suit—`SmartLabelPlacer` accepts an injected `Logger`, and `SeeCommand` passes the runtime logger so annotation debug output no longer talks to the singleton.
- `ImageCommand` joined the runtime world: it exposes `CommandRuntimeOptions`, runs via `run(using runtime:)`, and every capture/logging path (including multi-window capture + AI analysis) now calls `self.logger`/`self.services` instead of the singletons. Shared permission helpers made this trivial since the command can forward its runtime services into `requireScreenRecordingPermission`.
- ConfigCommand’s housekeeping subcommands (`init`, `show`, `edit`, `validate`) and every provider/credential operation (`set-credential`, `add-provider`, `list-providers`, `test-provider`, `remove-provider`, `models-provider`) now share the runtime plumbing—each exposes `CommandRuntimeOptions`, uses `run(using runtime:)`, and reads the JSON flag from the runtime instead of bespoke switches. Every subcommand caches its runtime via `@RuntimeStorage`, threads `runtime.logger` into the config-only `outputJSON` helper, and that helper now requires a `Logger`, so we never fall back to `Logger.shared` when emitting config output.
- `WindowServiceBridge` now calls `runtime.services.windows` directly and the old `WindowManagementActor` wrapper was deleted, so window subcommands no longer inherit synthetic `@MainActor` isolation just to reach the window service (and we eliminated the recursion bug in the process).
- `CleanCommand` no longer relies on `@MainActor MainActorAsyncParsableCommand`; it now conforms directly to `AsyncParsableCommand & AsyncRuntimeCommand` and consumes the shared runtime options like the other system commands.
- `DockCommand` and `DialogCommand` shed their `@MainActor` wrappers entirely; all dialog/dock subcommands now adopt the same runtime pattern and no longer require the trailing conformance extensions.
- `AppCommand` and the entire `mcp` command surface are now plain `ParsableCommand`s—every subcommand conforms directly to `AsyncRuntimeCommand`, uses `CommandRuntimeOptions`, and we deleted the old file-level `@MainActor` scaffolding plus the bridging extensions.
- `ToolsCommand` now uses `CommandRuntimeOptions` as well; the runtime `--verbose/-v` flag doubles as the “show descriptions” toggle, so the command’s formatted output and JSON output both flow through the shared runtime config.
- `permissions` + `list` subcommands were migrated last pass, and the latest batch adds `space list/switch/move-window`, `learn`, `app {launch,quit,relaunch,hide,unhide,switch,list}`, the full window surface, **all dialog + menu subcommands**, and now the CLI-facing agent (`agent ...`). Everything listed now exposes `CommandRuntimeOptions`, uses `run(using runtime:)`, and sources `jsonOutput` + services from the shared runtime helpers.
- All `peekaboo mcp` entrypoints (`serve`, `call`, `list`, `add`, `remove`, `test`, `info`, `enable`, `disable`, `inspect`) now adopt `CommandRuntimeOptions` + `AsyncRuntimeCommand`; JSON/verbose toggles come from the shared option group, argument validation errors route through the runtime logger, and the CLI no longer pokes `Logger.shared` directly inside those commands.
- Shared permission helpers were nudged in the same direction: `requireScreenRecordingPermission`/`requireAccessibilityPermission` now accept a `PeekabooServices` parameter (defaulting to `.shared`), so future callers can opt into runtime-provided services without new wrappers.
- `SmartLabelPlacer` and `AcceleratedTextDetector` share the injected runtime logger, so verbose annotation traces follow the CLI’s logging mode instead of `Logger.shared`.
- `FocusCommandUtilities.ensureFocused` now requires an explicit `PeekabooServices`, and every caller (interaction, menu, window commands) threads `runtime.services` through so auto-focus never falls back to the singletons mid-command.
- `ApplicationResolver` no longer defaults to `PeekabooServices.shared`; the app CLI subcommands (`quit`, `hide`, `unhide`, `switch`, `relaunch`) now pass their injected `runtime.services` into `resolveApplication` so app targeting honors the command-scoped context.
- JSON output helpers (`outputSuccessCodable`, `outputJSON`, `outputError`) now accept an injected `Logger`, and `OutputFormattable` exposes an `outputLogger` hook so commands can route success/error serialization through their runtime logger (AppCommand subcommands already override it).
- ScrollCommand now stores its runtime so JSON summaries use the injected logger, and all menu subcommands override `outputLogger` to forward their runtime loggers to the shared output helpers.
- Dialog subcommands (`click`, `input`, `file`, `dismiss`, `list`) now mirror the same `outputLogger` override so permission + dialog JSON payloads respect the runtime logger instead of `Logger.shared`.
- Window subcommands (close/minimize/maximize/focus/move/resize/set-bounds/window-list) now correctly source services + loggers from the runtime (the recursive fallback is gone) and expose `outputLogger`, so every JSON payload honors command-level logging. Space commands (`list`, `switch`, `move-window`) and interaction swipes/moves/scrolls/press/type/hotkey do the same.
- Space command subcommands now initialize their runtime logger inside `run(using:)` instead of relying on the legacy `@MainActor extension AsyncRuntimeCommand` shim, so tmux logs and JSON payloads always reflect the injected context.
- `permissions check` / `permissions request` switched from trailing `@MainActor extension … AsyncRuntimeCommand` conformances to inline `AsyncRuntimeCommand` adoption with `@MainActor`-scoped `run()` wrappers, removing another source of `#ConformanceIsolation` diagnostics.
- Agent-facing `permission status/request-*` now expose `CommandRuntimeOptions`, thread runtime services/loggers through, and emit JSON payloads when `--json-output` is set, so MCP + agent workflows stay consistent with the rest of the CLI runtime.
- `WindowIdentificationOptions` and `FocusCommandOptions` have been de-isolated (plain `ParsableArguments`), and the `window`/`space` parent commands were converted to plain `ParsableCommand` shells with `@MainActor` extension conformances, reducing the amount of implicit actor isolation per subcommand.
- JSON output for image captures, list views, tool inventory, permission checks, sleep timers, click actions, and `see` now goes through runtime loggers: ImageCommand, every ListCommand subcommand, ToolsCommand, `permissions check/request`, `sleep`, `click`, and `see` cache their runtime, override `outputLogger`, and send structured output via the injected logger. `OutputFormattable` no longer defaults to `Logger.shared`, and the old `VerboseCommand` helper was removed to prevent regressions.
- `scripts/tmux-build.sh` ran via `tmux new-session` (`cli-build-1762684307`, Nov 9) and now gets past App/MCP/Dock/Dialog/Clean, but still dies on the remaining `WindowCommand` subcommands (`resize`, `set-bounds`, `window list`) and the `@MainActor`-annotated `AgentCommand`. Visualizer crash is still out of reach.
- MenuBar, Menu, Dialog, Run, and Clean commands now expose `CommandRuntimeOptions`, store their runtime via `@RuntimeStorage`, and route every JSON/error helper through their injected loggers. Shared helpers (`handleGenericError`, `handleDialogServiceError`, `handleFileServiceError`, `handleDockServiceError`) were updated to require explicit `Logger` parameters so tmux logs reflect the correct command context.
- Normalized `@RuntimeStorage` usage (`@RuntimeStorage private var runtime`) and moved every ConfigCommand subcommand to inline `AsyncRuntimeCommand` conformances; the trailing extension block was removed so the compiler no longer fights redundant conformances.
- Latest tmux build (`cli-build-1762684307`, Nov 9) now dies on the lingering window subcommands plus `AgentCommand`; once those conformances lose their implicit `@MainActor`, we should finally land back on the Visualizer failure.
- Remaining migrations: helper utilities (`ApplicationResolver`, `FocusCommandUtilities`, dialog/menu + JSON output helpers) and a few AI capture surfaces that still reach for `Logger.shared`/`PeekabooServices.shared`).

## Next Steps

- Finish the helper-layer cleanup (`ApplicationResolver`, `FocusCommandUtilities`, dialog/menu helpers) so no shared utilities depend on `Logger.shared`/`PeekabooServices.shared`.
- Keep pushing the service-injection helpers downward—replace the remaining `PeekabooServices.shared` touches in shared utilities (JSON output helpers, focus utilities, AI analyzers) with parameters or runtime-derived services so commands stay testable.
- Override `outputLogger` across the remaining `OutputFormattable` commands (image-adjacent helpers, ListCommand variants, ToolsCommand) so JSON + error output fully respects runtime-provided loggers.
- After each small batch, rerun `scripts/tmux-build.sh` in tmux—expect the Visualizer failure, but capture the session ID + log paths (latest: `cli-build-1762684307`, Nov 9) so everyone knows which build covered the edits.
- Schedule a dedicated fix for the “see” command’s parser regression (ArgumentParser crashes before we ever hit the runtime). Until that lands, use the `VisualizerSmoke` harness (see docs/visualization.md) or the mac app itself to drive visualizer events.
- Fix the remaining `WindowCommand` actor-isolation errors (`Move/Resize/SetBounds/WindowList`) so they can safely conform to `AsyncRuntimeCommand`—once Swift accepts those conformances the build should reach the Visualizer crash again.
- Re-run `scripts/tmux-build.sh` after the `WindowCommand` fix to confirm we’re back to the known Visualizer failure (capture the new `cli-build-*` ID alongside the log snippets).
