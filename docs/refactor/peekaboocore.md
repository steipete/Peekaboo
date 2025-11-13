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

## Stage 2 — Explicit Dependency Injection (3–4 days)
- Replace `PeekabooServices.shared` accesses with constructor injection, starting from the edges (CLI commands, macOS app flow) and working inward.
- Keep a temporary shim (`PeekabooServicesProvider.current`) only for files not yet migrated so we can land incremental PRs.
- Update `PeekabooAgentService` initializers to require protocol-based services; provide default factory helpers in apps/CLI to keep call sites terse.
- Extend existing tests to pass mocks via the new initializers, ensuring we do not regress coverage.
- Deliverable: `PeekabooServices.shared` referenced only inside the shim and slated for deletion in Stage 3.

## Stage 3 — Concurrency & Actor Isolation Sweep (2–3 days)
- Mark UI-facing services (`SessionStore`, `VisualizationClient`, `ApplicationService`, `MenuService`) as `@MainActor` and enforce the attribute via SwiftLint/SwiftSyntax rule.
- For non-UI services that manage mutable state (e.g., caches), consider dedicated `actor`s or `nonisolated` declarations to make intent explicit.
- Update Tachikoma bridges (`PeekabooAgentService`, agent tool adapters) so async calls hop back to the main actor before touching AppKit.
- Deliverable: zero Swift concurrency warnings with `STRICT_CONCURRENCY=complete` across PeekabooCore targets; documented decisions for services that remain nonisolated.

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
