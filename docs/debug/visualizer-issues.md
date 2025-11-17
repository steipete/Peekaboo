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
| VIS-003 | Watch capture channel (`showWatchCapture`) is a no-op, so users get no feedback during `peekaboo watch`. | 🟧 In Progress | Watch HUD overlay (Apps/Mac/Peekaboo/Features/Visualizer/WatchCaptureHUDView.swift) now displays a pill indicator whenever watch capture ticks. Future enhancement: add timeline/tick marks driven by frame metadata. |
| VIS-004 | No automated smoke test walks all animations; easy to regress (e.g., settings toggles). | 🟩 Fixed | Added `peekaboo visualizer` smoke command (Apps/CLI/Sources/PeekabooCLI/Commands/System/VisualizerCommand.swift) that fires every visualizer effect in sequence. |

_Last updated: 2025-11-17_
