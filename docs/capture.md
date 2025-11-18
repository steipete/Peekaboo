---
summary: 'Capture command (live + video) with adaptive frames, contact sheet, optional MP4'
read_when:
  - 'planning or implementing the capture command'
  - 'adding long-form, change-aware captures for agents'
  - 'aligning capture parameters with CLI/MCP tooling'
---

# `capture` Command Notes

Goal: one command for long-running, change-aware capture (`capture live`) and video ingestion (`capture video`), emitting meaningful PNG frames, a contact sheet, metadata, and optional MP4 from kept frames. `capture watch` is a hidden alias to `capture live` for compatibility; the old standalone `watch` command/tool is removed.

## UX & Defaults
- **Live (`capture live`)**: targeting/focus/cadence flags unchanged from watch (mode/app/pid/window/region, capture-focus, duration ≤180, idle-fps, active-fps, threshold, heartbeat-sec, quiet-ms). Caps: max-frames (default 800), max-mb. Diff: strategy fast|quality + budget. Resolution cap default 1440. Optional `--video-out` writes MP4 from kept frames.
- **Video (`capture video <file>`)**: sampling via `--sample-fps` (default 2) XOR `--every-ms`; trim with `--start-ms/--end-ms`; `--no-diff` keeps all sampled frames; shares caps/diff/resolution/output flags with live. Requires ≥2 kept frames.

## Outputs
- PNG frames (kept only)
- `contact.png` contact sheet
- `metadata.json` (CaptureResult) with stats, warnings, grid info, source (live|video), videoIn/out
- Optional MP4 (`--video-out`) from kept frames

## Implementation highlights
- Core types: `CaptureScope/Options/Result` (watch typealiases kept temporarily).
- Session accepts a `CaptureFrameSource` (live: ScreenCapture; video: AVAssetReader-based `VideoFrameSource`).
- Diff + hysteresis preserved; `--no-diff` bypasses filtering.
- MP4 writing via `VideoWriter` when requested.

## Quick tests
- Live smoke: `peekaboo capture live --mode screen --duration 5 --active-fps 8 --threshold 0` → frames > 0, contact sheet exists.
- Video ingest: `peekaboo capture video /path/demo.mov --sample-fps 2 --start-ms 5000 --video-out /tmp/demo.mp4` → ≥2 kept frames, MP4 written.
