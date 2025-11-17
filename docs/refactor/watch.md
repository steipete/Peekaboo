---
summary: 'Watch command follow-ups and refactor backlog'
read_when:
  - 'planning a second pass on the watch command'
  - 'triaging performance/UX polish for adaptive captures'
---

# `watch` Refactor Backlog

This doc tracks the next improvements to make `peekaboo watch` sturdier and more agent-friendly.

## High-impact fixes
- **Diff budget + fallback:** Add a per-frame time budget for SSIM (`quality`). If exceeded, auto-fallback to `fast`, emit `diffDowngraded`, and note the switch in metadata.
- **Multi-blob motion boxes:** Replace the single bounding rect with connected-component blobs (with min-size + max-count caps) so overlays point to distinct changes instead of one coarse box.
- **Keep-based filenames:** Name output frames by kept order (`keep-0001.png`) rather than capture loop index so ordering matches the final retained sequence.
- **Contact sheet metadata:** Include sampling strategy, total kept frames, and selected frame indexes in the contact sheet metadata; expose `diffAlgorithm/diffScale` in CLI/MCP responses (not only metadata.json).
- **Fast failure for bad regions:** Reject regions fully off-screen; if a region straddles displays, either crop with a warning or require a single-display region (documented).
- **Focus heuristics parity:** When no `window-index` is provided, reuse `image`’s window scoring (size/visibility) instead of first-window default to reduce “blank/hidden window” captures.
- **Autoclean safety:** Track `autocleanAt` per session, skip deleting user-specified paths, and log how many temp sessions were cleaned.

## Testing gaps
- Add CLI automation test using a mocked capture source:
  - Asserts JSON output shape, contact sheet existence, and warnings on caps (`max-frames`).
  - Verifies `diffAlgorithm/diffScale` appear in the top-level CLI/MCP payload.
- Add hysteresis test (enter/exit thresholds) and early-stop tests (frame cap, size cap) to Swift Testing.

## Docs polish
- Add a short “watch vs image vs see” comparison table to `docs/commands/watch.md`.
- Add troubleshooting tips for long runs (e.g., lower `active-fps` for video-heavy scenes).

## Performance ideas
- Downscale diff further (128px) when CPU load is high or FPS falls behind; record the downgrade.
- Cache the downscaled buffer for contact-sheet thumbs to avoid a second resize pass when many frames are kept.
