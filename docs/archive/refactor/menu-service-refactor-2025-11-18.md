---
summary: 'MenuService refactor notes (Nov 18, 2025)'
read_when:
  - 'continuing MenuService traversal/refactor work'
  - 'adding tests or diagnostics for menu interactions'
---

## MenuService refactor — 2025-11-18

Context
- Split the 1k-line MenuService into focused extensions (List/Actions/Extras/Traversal) plus helper models and traversal limits; added traversalPolicy/init hook and bounded traversal budget.
- Traversal now caps depth/children/time for listing, path walking, and name-based clicks; visualizer wiring isolated in a helper.

What to do next (strong recommendations)
- Switch traversal timing to `ContinuousClock`/`Duration` and log remaining budget to improve diagnostics; consider exposing a debug policy via DI instead of enum-only.
- Centralize AX helpers (menuBar/systemWide, placeholder/title utilities) in a shared UI AX helper file so Dock/Menu/etc. reuse one implementation and tests cover it once.
- Harden lookups: normalize titles (whitespace/diacritics/case) and recognize accelerator glyphs when matching menu items and extras; add partial-match strategy toggles to reduce false positives.
- Make visualizer/test seams: inject `VisualizationClient` and `Logger` so unit tests can stub; keep singleton as default.
- Add resilience: optional retry around `AXPress`, depth-based debounce tuning for submenus, and a short-lived cache for `MenuStructure` per app/session to cut repeated AX walks.

Tests to add
- Unit: traversal budget enforcement (depth/children/time) with mocked Element tree; placeholder-to-identifier resolution for menu extras.
- Integration/snapshot: `clickMenuItem` happy-path and missing-path failures; `clickMenuBarItem` matching precedence (exact/case-insensitive/partial) with placeholder titles.
