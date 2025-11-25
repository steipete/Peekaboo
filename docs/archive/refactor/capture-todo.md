---
summary: 'Follow-ups after replacing watch with capture'
read_when:
  - 'planning capture feature work'
  - 'adding tests for capture live/video'
---

# Capture TODOs
_Status: Archived · Focus: watch→capture migration follow-ups._

- [x] **Automation tests**: add end-to-end coverage for `capture live` / `capture video` (sampling, trim, `--no-diff`, `--video-out`, caps). Added `VideoWriterTests` with video-session run covering mp4 size caps + fps.
- [x] **VideoWriter polish**: bound video output size (aspect-aware) and derive fps from sampling cadence (uses effective FPS for video sources and active FPS fallback).
- [x] **Docs sweep**: ensure no stale “watch” mentions remain outside the updated capture docs (visualizer/cli helpers).
- [ ] **Full test run**: previous `swift test` timed out at 120s; rerun with higher timeout or targeted suites when feasible. (Ran `pnpm run test:safe` for CLI.)
