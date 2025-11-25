---
summary: 'Capture live screens/windows or ingest video; adaptive frames + contact sheet'
read_when:
  - 'using peekaboo capture'
  - 'automating long-running visual captures'
---

# `peekaboo capture`

`capture` replaces `watch` as the unified long-running capture tool. It has two subcommands:

- `capture live` — adaptive PNG burst capture of screens/windows/regions with idle/active FPS, diff-based frame keeping, contact sheet, and metadata.
- `capture video` — ingest an existing video, sample frames (by FPS or interval), optionally skip diff filtering, and emit the same outputs.

A hidden alias `capture watch` maps to `capture live` for backwards compatibility. The old standalone `watch` command/tool is removed.

## Common Outputs
- PNG frames (kept frames only)
- `contact.png` contact sheet
- `metadata.json` (`CaptureResult`) with stats, warnings, grid info, and source (live|video)
- Optional MP4 (`--video-out`) built from kept frames

## `capture live` flags
- Targeting: `--mode`, `--screen-index`, `--app`, `--pid`, `--window-title`, `--window-index`, `--region` (global coords)
- Focus: `--capture-focus auto|background|foreground`
- Cadence: `--duration` (<=180), `--idle-fps`, `--active-fps`, `--threshold`, `--heartbeat-sec`, `--quiet-ms`
- Caps: `--max-frames` (default 800), `--max-mb`
- Diff/output: `--highlight-changes`, `--resolution-cap` (default 1440), `--diff-strategy fast|quality`, `--diff-budget-ms`, `--video-out <path>`
- Paths: `--path <dir>` (default temp `capture-sessions/capture-<uuid>`), `--autoclean-minutes` (default 120)

## `capture video` flags
- Required: `--input <video>` (positional `input` argument)
- Sampling: `--sample-fps <fps>` (default 2) XOR `--every-ms <ms>`
- Trim: `--start-ms`, `--end-ms`
- Diff: `--no-diff` (keep all sampled frames); otherwise uses diff/keep logic
- Caps/output: `--max-frames`, `--max-mb`, `--resolution-cap` (default 1440), `--diff-strategy`, `--diff-budget-ms`, `--video-out`
- Paths: `--path`, `--autoclean-minutes`

Validation: video source rejects targeting/focus/cadence flags; live rejects sampling/trim/no-diff. Video runs require >=2 kept frames or return an error.

## Examples
```bash
# Live, change-aware capture of frontmost window for 45s
peekaboo capture live --duration 45 --idle-fps 1 --active-fps 8 --threshold 2.0

# Live, target specific screen, MP4 output
peekaboo capture live --mode screen --screen-index 1 --video-out /tmp/capture.mp4

# Video ingest, sample 2 fps, trim first 5s
peekaboo capture video /path/to/demo.mov --sample-fps 2 --start-ms 5000 --video-out /tmp/demo.mp4

# Video ingest, keep all sampled frames at 500ms interval (no diff filtering)
peekaboo capture video /path/to/demo.mov --every-ms 500 --no-diff
```

## Design notes
- Hidden alias: `capture watch` maps to `capture live`; the old standalone `watch` tool was removed.
- Live defaults: max duration 180s, `--max-frames` 800, resolution cap 1440, diff strategy `fast` unless `--diff-strategy quality` is set.
- Video ingest uses the same diff/keep logic as live; `--no-diff` keeps every sampled frame. Requires at least 2 kept frames.
- Core types: `CaptureScope/Options/Result` with a pluggable `CaptureFrameSource` (ScreenCapture for live, AVAssetReader for video). Optional MP4 is written by `VideoWriter` when `--video-out` is set.
- Quick smokes:  
  - `peekaboo capture live --mode screen --duration 5 --active-fps 8 --threshold 0` → frames > 0, contact sheet exists.  
  - `peekaboo capture video /path/demo.mov --sample-fps 2 --start-ms 5000 --video-out /tmp/demo.mp4` → ≥2 kept frames and MP4 written.
