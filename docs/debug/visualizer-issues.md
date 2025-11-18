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
| VIS-003 | Capture (watch) HUD channel (`showWatchCapture`) is a no-op, so users get no feedback during capture runs. | 🟩 Fixed | Dedicated capture HUD now has its own settings toggle plus a timeline/tick indicator so sessions no longer look like screenshot flashes (VisualizerCoordinator + WatchCaptureHUDView.swift). |
| VIS-005 | Annotated screenshot overlays use raw AX coordinates, so red element bounds land in the wrong spot. | 🟩 Fixed | `VisualizerBoundsConverter` flips AX (top-left) coordinates into screen space before dispatching to Peekaboo.app, keeping overlays aligned (SeeTool.swift + new converter/tests). |
| VIS-004 | No automated smoke test walks all animations; easy to regress (e.g., settings toggles). | 🟩 Fixed | Added `peekaboo visualizer` smoke command (Apps/CLI/Sources/PeekabooCLI/Commands/System/VisualizerCommand.swift) that fires every visualizer effect in sequence. |

_Last updated: 2025-11-17_
