---
summary: "AXorcist↔Peekaboo boundary: keep AXorcist lean AX toolkit, push heuristics to Peekaboo; current state + next actions."
read_when:
  - "planning refactors that touch AXorcist or Peekaboo AX boundaries"
  - "deciding where AX and CG event helpers should live"
  - "adding or adjusting accessibility-related APIs"
---

# AXorcist Boundary & API Refactor (Nov 18, 2025)

## Current snapshot
- InputDriver now hosts all click/drag/scroll/hotkey paths for Peekaboo UI services; Peekaboo no longer posts CGEvents directly.
- SwiftLint rule in Peekaboo warns on AXUIElement/CGEvent usage or ApplicationServices imports in UI services.
- WindowIdentityUtilities wraps `AXWindowResolver`; MouseLocationUtilities delegates to `AppLocator`.
- CaptureOutput tightened: bounded SCStream timeout + test hooks; CLI tests pass with automation skipped.
- Open warnings to chase: `CGWindowListCreateImage` deprecation in `PermissionCommand`, unused-result warnings in `VisualizerCommand` demo steps.

## Boundary decision
- **AXorcist:** generic AX glue—element wrappers, permission/assert helpers, window/app lookup, input synthesis, attribute casting, timeouts/retry helpers, and light logging hooks. No Peekaboo-specific heuristics (menus/dialog scoring, session caches).
- **Peekaboo:** heuristics and UX: menu/dock/dialog specialization, scoring/ranking, overlays, agent/session state.
- Rule: if any macOS automation user would want it, keep it in AXorcist; if it embeds Peekaboo behavior, keep it in Peekaboo.

## API improvements to ship in AXorcist
- Provide `AXApp`/`AXWindowHandle` facades so callers never need `AXUIElementCreateApplication` or raw attributes.
- Expand `InputDriver` ergonomics without overhead: optional `moveIfNeeded(from:)`, `scroll(lines:at:)`, safe delay presets, and cursor caching helpers.
- Add `AXTimeoutPolicy` + `withAXTimeout` utilities (reuse Peekaboo’s timeout logic) with near-zero overhead defaults.
- Return `AppLocator`/`WindowResolver` results as lightweight value types (pid, bundle id, title, frame, layer) to replace Peekaboo’s CGWindowList parsing.
- Offer opt-in observability hooks (closures) for timing/events so Peekaboo can forward to its logger without new dependencies.

## Duplication/cleanup backlog in Peekaboo
- Replace direct `AXUIElementCreateApplication`/attribute calls in ApplicationService, UIAutomationService, DialogService, WindowManagementService, MenuService helpers, Scroll/Type/Click services (see current `rg AXUIElement` hits). Route through new AXorcist facades.
- Remove remaining CGEvent accessors (only InputDriver should synthesize events) and retire the `CGWindowListCreateImage` fallback in PermissionCommand to silence the deprecation.
- Delete the resurrected timeout helpers (`Element+Timeout.swift`) once AXorcist exposes shared timeout policy.
- Keep menu/dock/dialog heuristics in Peekaboo but make them depend only on AXorcist primitives.

## Test plan
- **AXorcist:** add unit tests for AppLocator/window resolver, timeout helpers, and InputDriver move/pressHold error cases (mirroring Peekaboo coverage).
- **Peekaboo:** keep CLI + automation tests as integration guard; backfill contract tests around menu/dock/dialog heuristics once they are peeled off raw AX APIs.

## Immediate next steps (suggested order)
1) Ship `AXApp`/`AXWindowHandle` facades in AXorcist; swap Peekaboo services to use them (eliminates most lint hits).
2) Move Peekaboo timeout wrapper into AXorcist (`withAXTimeout`) and delete `Element+Timeout.swift` residue.
3) Replace PermissionCommand’s CGWindowList probe with a ScreenCaptureKit-based permission provocation (or an InputDriver.currentLocation noop) to drop the deprecation warning.
4) Add AXorcist tests for AppLocator/window resolver; wire Peekaboo tests to rely on those models instead of duplicating fixtures.
5) Tighten lint once migration is done (warning → error) to keep the boundary enforced.

Notes: keep AXorcist hot paths allocation-free; avoid adding async layers unless the underlying API blocks. Use `@testable import AXorcist` for the new unit tests and mirror any helper edits into `agent-scripts` if touched.
