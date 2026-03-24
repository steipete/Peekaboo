---
summary: 'Capture live screens/windows or ingest video'
---

# `peekaboo capture`

`capture` is the unified long-running capture tool with two subcommands:
- `capture live` — adaptive PNG burst capture of screens/windows/regions
- `capture video` — ingest an existing video and sample frames

## Common Outputs

- PNG frames (kept frames only)
- `contact.png` contact sheet
- `metadata.json` with stats and warnings
- Optional MP4 (`--video-out`)

## `capture live` flags

- Targeting: `--mode`, `--screen-index`, `--app`, `--pid`, `--window-title`
- Cadence: `--duration` (<=180), `--idle-fps`, `--active-fps`
- Caps: `--max-frames` (default 800), `--max-mb`
- Output: `--path <dir>`, `--video-out <path>`

## `capture video` flags

- Required: `<video>` positional argument
- Sampling: `--sample-fps <fps>` (default 2) or `--every-ms <ms>`
- Trim: `--start-ms`, `--end-ms`
- Diff: `--no-diff` (keep all sampled frames)

## Examples

```bash
# Live capture of frontmost window for 45s
peekaboo capture live --duration 45 --idle-fps 1 --active-fps 8

# Live capture with MP4 output
peekaboo capture live --mode screen --screen-index 1 --video-out /tmp/capture.mp4

# Video ingest, sample 2 fps
peekaboo capture video /path/to/demo.mov --sample-fps 2 --video-out /tmp/demo.mp4
```
