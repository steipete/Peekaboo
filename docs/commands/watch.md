---
summary: 'Watch a screen/window/region and save PNG frames only when things change'
read_when:
  - 'adding or using the watch command'
  - 'needing long-duration, change-aware captures for agents'
---

# `peekaboo watch`

Adaptive screenshot capture for agents. Runs up to a set duration, samples at low FPS when idle, bursts at higher FPS on motion, and emits only kept PNG frames plus a contact sheet and metadata.

## Common tasks
- Observe a window for 1–3 minutes and keep only meaningful frames instead of a video.
- Capture a region where an app will update later (e.g., spinner → result).
- Produce a quick contact sheet to skim the interaction without opening every PNG.

## Key options
| Flag | Description |
| --- | --- |
| `--mode screen|window|frontmost|region` | Capture scope (`region` uses global coords `x,y,w,h`). |
| `--app`, `--pid`, `--window-title`, `--window-index` | Window targeting (same semantics as `image`). |
| `--screen-index` | Pick a display for `screen` mode. |
| `--capture-focus auto|background|foreground` | Match `image` focus behavior. |
| `--duration` | Seconds to run (default 60, max 180). |
| `--idle-fps`, `--active-fps` | Sampling rates (defaults 2 / 8, active capped at 15). |
| `--threshold` | Change threshold percent to enter active mode (default 2.5). |
| `--heartbeat-sec` | Force a keep every N seconds (default 5, `0` disables). |
| `--quiet-ms` | Calm period before dropping back to idle (default 1000). |
| `--highlight-changes` | Draw motion boxes on kept frames. |
| `--max-frames`, `--max-mb` | Soft caps; session stops with a warning if hit. |
| `--resolution-cap` | Longest edge clamp (default 1440). |
| `--diff-strategy fast|quality` | Diffing strategy (fast is default). |
| `--path` | Output directory (otherwise temp `watch-sessions/watch-<id>`). |
| `--autoclean-minutes` | Temp cleanup window (default 120). |

## Outputs
- PNG frames: `frame-0001.png`… with timestamps and change percentages.
- `contact.png`: grid of sampled frames (max 6 columns).
- `metadata.json`: scope, options, stats, per-frame info, motion intervals, warnings.

## Notes
- PNG-only; no GIF/MP4.
- Region coordinates are global display coords; HiDPI-aware.
- At least the first frame is always kept; heartbeat prevents long gaps.
- Auto-clean of temp sessions on next run unless a custom `--path` is set.

## Example
```bash
polter peekaboo -- watch \
  --mode window --app Safari --window-title "Downloads" \
  --duration 90 --idle-fps 2 --active-fps 10 \
  --threshold 2.5 --heartbeat-sec 5 --quiet-ms 800 \
  --highlight-changes
```
