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
- **Focus heuristics parity via code sharing:** Extract shared window scoring/selection utilities from `image` so `watch` uses the same heuristics (size/visibility/level/minimized filtering) instead of bespoke logic.
- **Autoclean safety:** Track `autocleanAt`, skip deleting user-specified paths, and emit structured `autoclean` warning with counts.
- **Shared metadata helpers:** Deduplicate diff/contact metadata emission between CLI and MCP surfaces to avoid divergence.

## Testing gaps
- Add CLI automation tests:
  - Cap warnings (`max-frames`, size cap).
  - Diff-budget downgrade path (force SSIM slow, assert `diffDowngraded`).
  - Region clamp warning path.
- Add hysteresis/early-stop Swift Testing coverage (enter/exit thresholds, frame/size caps).

## Docs polish
- Document MCP meta fields (`contact_columns/contact_rows/contact_sampled_indexes`) explicitly for agents.

## Performance ideas
- Downscale diff further (128px) when CPU load is high or FPS falls behind; record the downgrade.
- Cache the downscaled buffer for contact-sheet thumbs to avoid a second resize pass when many frames are kept.
