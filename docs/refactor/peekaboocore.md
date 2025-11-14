---
summary: 'Stage the PeekabooCore refactor to tighten dependency injection, concurrency, and modularization.'
read_when:
  - 'Planning structural changes to PeekabooCore services or agent pipeline'
  - 'Coordinating with Tachikoma updates that affect PeekabooCore interfaces'
---

# PeekabooCore Refactor Plan

PeekabooCore already cleanly separates automation services from AI providers, but several cross-cutting concerns (global service locators, inconsistent actor isolation, and weak modular boundaries) keep creeping back. This plan breaks the cleanup into four deliverable stages so multiple engineers can parallelize safely.

## Stage 1 — Dependency Surface Audit (1–2 days)
- Catalog every use of `PeekabooServices.shared` across CLI, macOS app, and unit tests; document needed service subsets per module.
- Introduce lightweight protocols (e.g., `Clicking`, `Typing`, `WindowManaging`) that mirror the concrete service APIs so the audit reveals redundant responsibilities.
- Add Swift Testing smoke tests for `PeekabooAgentService` that inject simple protocol mocks; this guards the migration and proves injectability before touching production code.
- Deliverable: checklist that lists each consumer → service dependency plus new protocol stubs checked in.

### Stage 1 Progress Log (Nov 13, 2025)

| Area | Files referencing `PeekabooServices.shared` | Typical dependency need |
| --- | ---: | --- |
| `Core/PeekabooCore` | 28 | Automation (`automation`, `menu`, `windows`), permissions (`screenCapture`), agent bootstrap (`PeekabooAgentService`). |
| `Apps/CLI` | 8 | Command runtime scaffolding plus menu/focus helpers still reaching into shared services for automation + session state. |
| `Apps/Mac` | 6 | UI tests and RealtimeVoice flows directly touch services, blocking deterministic tests. |
| `docs/*` | 6 | Documentation references (no code impact). |

- CLI hotspots: `CommandRuntime`, `PermissionHelpers`, and `FocusCommandUtilities` require automation, menu, windows, and logging services. These will be first adopters of explicit injection once the runtime accepts an externally provided `PeekabooServices`.
- Core MCP tools (`MenuTool`, `MoveTool`, `WindowTool`, etc.) each fetch a single service (`automation`, `menu`, `windows`). These should accept the specific service protocol instead of the full locator.
- ApplicationService still reaches back into `screenCapture` for permission checks; we will extract a `ScreenCapturePermissions` protocol so the cycle can invert.
- ✅ 04:55 UTC — CLI runtime + helpers now consume `any PeekabooServiceProviding`. Every command references the injected runtime instead of `PeekabooServices()`, and a `CommandRuntimeInjectionTests` suite guards the dependency override path.
- 05:25 UTC — MCP tool audit summary:
  - `SeeTool`, `ImageTool`, `DragTool`, `MoveTool`, `ClickTool`, `HotkeyTool`, `TypeTool`, `ScrollTool`, `DialogTool`, `MenuTool`, `DockTool`, `SpaceTool`, `AppTool`, `PermissionsTool`, and `MCPAgentTool` each read `PeekabooServices().*` (automation, windows, menu, dock, applications, dialogs, screenCapture, sessions).
  - `ScreenCaptureService+Support` and `ApplicationService` also reach back into the shared instance for permission checks.
  - ToolRegistry instantiates `PeekabooAgentService` with the singleton when enumerating tools.
  These will be handled next by passing explicit service providers through the MCP tool initializers/factories so each tool binds to the minimal protocol it needs.

Next action: land protocol stubs for the core service families (`AutomationServiceProtocol`, `ApplicationServiceProtocol`, `ScreenCaptureServiceProtocol`) and update `PeekabooServices` to expose them via protocol types so call sites can begin compiling without the singleton.

## Stage 2 — Explicit Dependency Injection (3–4 days)
- Replace `PeekabooServices()` accesses with constructor injection, starting from the edges (CLI commands, macOS app flow) and working inward.
- Keep a temporary shim (`PeekabooServicesProvider.current`) only for files not yet migrated so we can land incremental PRs.
- Update `PeekabooAgentService` initializers to require protocol-based services; provide default factory helpers in apps/CLI to keep call sites terse.
- Extend existing tests to pass mocks via the new initializers, ensuring we do not regress coverage.
- Deliverable: `PeekabooServices()` referenced only inside the shim and slated for deletion in Stage 3.

### Stage 2 Progress Log (Nov 13, 2025)

- Added `MCPToolContext`, a lightweight value container that captures the exact PeekabooCore services MCP tools need. The context materializes once from `PeekabooServices` (or the injected CLI/app services) and can be swapped per tool/test without touching globals.
- Migrated every MCP tool (click, type, scroll, vision, menus, dialogs, dock, windows, permissions, apps, spaces, etc.) to accept the context via their initializer and replaced all `PeekabooServices().*` usages with the injected handles.
- Updated `PeekabooAgentService`’s tool factory to build a context from its injected `PeekabooServiceProviding` instance so agent runs now exercise the same DI path as the CLI instead of falling back to the singleton.
- Threaded explicit contexts through the MCP server (`PeekabooMCPServer`) and CLI `peekaboo tools` command so both entry points build contexts from their injected services, leaving `.shared` as a test-only fallback.
- Added `MCPToolContext.withContext(_:)` so focused tests can override dependencies without mutating globals; trimmed the default `.shared` accessor to a task-local override for better concurrency hygiene.
- Strengthened `MCPToolContextTests` (covers default wiring plus task-local overrides) and cleaned up MCP test fixtures to use `any MCPTool`, removing the lingering concurrency warnings in the suite.
- Refactored `AppTool` to rely solely on `ApplicationServiceProtocol` and `MCPToolContext` (no more `NSWorkspace` calls), paving the way for deterministic mocks inside `MCPToolExecutionTests` and keeping DI consistent across automation tools.
- Added `MCPToolTestHelpers` and mock automation/screen capture/application services so `MCPToolExecutionTests` can override `MCPToolContext.shared`; the suite now runs entirely on mocks (no singleton access) and passes via `./runner swift test --package-path Core/PeekabooCore --filter MCPToolExecutionTests`.
- Updated `MCPSpecificToolTests`, `MCPToolRegistryTests`, and `MCPToolRegistryExternalTests` to construct all tools and client managers via helpers instead of touching `PeekabooServices()`/`TachikomaMCPClientManager.shared`, so every MCP test now runs on injectable contexts. `./runner swift test --package-path Core/PeekabooCore --filter MCPSpecificToolTests|MCPToolRegistryTests|...ExternalTests` all pass with the new harness.
- CLI runtime now requires explicit service injection: `CommandRuntime` no longer defaults to `PeekabooServices()`, the commander executor/builders call a lightweight `.makeDefault(options:)` shim, and permission helpers + command utilities dropped their singleton defaults. This removes implicit singleton usage from CLI commands/tests while keeping a single entrypoint shim around `PeekabooServices()`.
- Added `MCPToolContextTests` under `Core/PeekabooCore/Tests/PeekabooCoreTests/MCP/` to ensure the shared context stays wired, and ran `./runner swift test --package-path Core/PeekabooCore --filter MCPToolContextTests` (build succeeds; filter currently selects zero runnable tests under Swift Testing).
- ✅ Nov 14, 2025 — Finished eradicating production/test *code* references to `PeekabooServices.shared` and deleted the singleton shim. `ApplicationService`, `ScreenCaptureService`, and `FocusManagementService` now accept injected permission/application helpers; the macOS app owns a long-lived `@State private var services = PeekabooServices()` and threads it through `PeekabooAgent`, `RealtimeVoiceService`, and `PeekabooSettings.connectServices(_:)`. MCP/CLI test helpers fabricate `PeekabooServices()` instances instead of touching a global instance, `CommandRuntime.withInjectedServices` handles CLI overrides, and `ToolRegistry` accepts an explicit services parameter so developer tooling no longer spins up a singleton. Documentation references remain for historical context until the Stage 5 cleanup note lands.

## Stage 3 — Concurrency & Actor Isolation Sweep (2–3 days)
- Mark UI-facing services (`SessionStore`, `VisualizationClient`, `ApplicationService`, `MenuService`) as `@MainActor` and enforce the attribute via SwiftLint/SwiftSyntax rule.
- For non-UI services that manage mutable state (e.g., caches), consider dedicated `actor`s or `nonisolated` declarations to make intent explicit.
- Update Tachikoma bridges (`PeekabooAgentService`, agent tool adapters) so async calls hop back to the main actor before touching AppKit.
- Deliverable: zero Swift concurrency warnings with `STRICT_CONCURRENCY=complete` across PeekabooCore targets; documented decisions for services that remain nonisolated.

### Stage 3 Progress Log (Nov 14, 2025)
- PeekabooCore now treats `PeekabooServices`, `SessionManager`, and `SpaceManagementService` as `@MainActor`, and the shared `SessionManagerProtocol` interfaces in both PeekabooCore and PeekabooProtocols are marked accordingly. Visualization already lived on the main actor, so CLI/agent callers now consistently interact with main-isolated services through `CommandRuntime.withInjectedServices`. A `STRICT_CONCURRENCY=complete ./runner swift build --package-path Core/PeekabooCore` pass is clean, so Stage 3 gating is satisfied.

## Stage 4 — Modularization & Contract Tests (3–5 days)
- Split the current SwiftPM target into smaller products: `PeekabooAutomation` (pure services), `PeekabooVisualizer`, `PeekabooAgentRuntime`. Use `PeekabooCore` umbrella target only where all are required.
- Move agent-facing protocols into the automation module so Tachikoma and future apps can depend on a slim API surface.
- Add contract test suites per module that instantiate mocks/fakes to validate behavior (e.g., `UIAutomationService` happy-path flows, visualization event wiring, agent streaming loops).
- Update the macOS app + CLI manifests to consume the new modules and ensure Poltergeist builds both in parallel.
- Deliverable: clear module graph (documented here + in `docs/ARCHITECTURE.md`), plus CI job that runs the new contract suites.

## Stage 5 — Cleanup & Tooling (1–2 days)
- Remove the legacy service locator shim and delete any unused helpers uncovered during modularization.
- Introduce template snippets or Swift macro helpers for injecting services (so new commands default to DI).
- Refresh developer docs (AGENTS.md, `docs/ARCHITECTURE.md`) to describe the new module layout and DI expectations.
- Deliverable: follow-up doc PRs merged, and CI ensures new files reference DI macros instead of the old singleton.

## Coordination Notes
- Tachikoma changes (e.g., new protocols for tool execution) should happen on their own branch but land before Stage 4 to avoid dependency churn.
- Keep each stage under review behind feature flags when possible so the macOS app remains shippable throughout.
- Use the test plan from Stage 4 as release criteria before deleting the service locator in Stage 5.
