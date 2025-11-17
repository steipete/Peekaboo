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

## Testing gaps
- Expand hysteresis/early-stop Swift Testing coverage (enter/exit thresholds, frame/size caps, long idle→active→idle transitions).

## Docs polish
- **(Done)** Document MCP meta fields (`contact_columns/contact_rows/contact_sampled_indexes`, `contact_thumb_size`) for agents.

## Performance ideas
- Downscale diff further (128px) when CPU load is high or FPS falls behind; record the downgrade.
- Cache the downscaled buffer for contact-sheet thumbs to avoid a second resize pass when many frames are kept.
