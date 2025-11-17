---
summary: 'Watch command follow-ups and refactor backlog'
read_when:
  - 'planning a second pass on the watch command'
  - 'triaging performance/UX polish for adaptive captures'
---

# `watch` Refactor Backlog

This doc tracks the next improvements to make `peekaboo watch` sturdier and more agent-friendly.

## High-impact fixes
- **(Done)** Diff budget + fallback: per-frame SSIM budget, auto-fallback to fast, `diffDowngraded` warning.
- **(Done)** Multi-blob motion boxes (connected components with caps).
- **(Done)** Keep-based filenames + sampled contact metadata exposed in CLI/MCP.
- **(Done)** Region clamp: off-screen errors; straddling regions clamp with warning.
- **(Done)** Focus heuristics parity via code sharing: `WatchCommand` now reuses the `ImageCommand` window scoring/filtering helpers.
- **(Done)** Autoclean safety: track `autocleanAt`, skip deleting user-specified paths, and emit structured `autoclean` warnings with counts.
- **(Done)** Shared metadata helpers: CLI and MCP now share `WatchMetaSummary` for emitting contact/diff metadata.

## Notes
- Cap scenario tests now exist (Swift Testing, stubbed capture) but remain behind the automation/Swift test filtering gate.
- Future performance ideas (optional): downscale diff further when FPS lags; reuse downscaled buffers for contact thumbs.
