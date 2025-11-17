---
summary: 'Open issues for Peekaboo visualizer effects'
read_when:
  - 'verifying visual feedback coverage'
  - 'debugging missing visualizer animations'
---

# Visualizer Issues Log

| ID | Description | Status | Notes |
| --- | --- | --- | --- |
| VIS-001 | `showElementDetection` payload never triggered (no overlays when running `peekaboo see`). | 🟩 Fixed | SeeTool now dispatches element-detection payloads after UI detection completes (Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/SeeTool.swift). |
| VIS-002 | `showAnnotatedScreenshot` payload unused, so annotated screenshot animation never runs. | 🟩 Fixed | SeeTool emits annotated-screenshot events when `--annotate` is requested, piping the generated PNG + detection bounds into the visualizer. |
| VIS-003 | Watch capture channel (`showWatchCapture`) is a no-op, so users get no feedback during `peekaboo watch`. | 🟥 Open | Replace current stub (Apps/Mac/Peekaboo/Services/Visualizer/VisualizerCoordinator.swift:142) with timeline/tick overlay idea; add harness button to preview. |
| VIS-004 | No automated smoke test walks all animations; easy to regress (e.g., settings toggles). | 🟧 Tracking | Add CLI smoke command or automation to press each button in `VisualizerTestView.swift` before releases. |

_Last updated: 2025-11-17_
