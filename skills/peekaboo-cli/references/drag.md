---
summary: 'Execute drag-and-drop flows via peekaboo drag'
---

# `peekaboo drag`

`drag` simulates click-and-drag gestures. You can start/end on element IDs, raw coordinates, or even another application.

## Key options

| Flag | Description |
| --- | --- |
| `--from <id>` / `--from-coords x,y` | Source handle. Exactly one is required. |
| `--to <id>` / `--to-coords x,y` / `--to-app <name>` | Destination. |
| `--duration <ms>` | Drag length (default 500 ms). |
| `--steps <count>` | Number of interpolation points (default 20). |
| `--modifiers cmd,shift,…` | Modifier keys held during the drag. |
| `--profile <linear|human>` | `human` enables natural-looking arcs and jitter. |

## Examples

```bash
# Drag a file element into the Trash
peekaboo drag --from file_tile_3 --to-app Trash

# Coordinate → coordinate drag
peekaboo drag --from-coords "120,880" --to-coords "480,220" --duration 1200

# Human-style drag with adaptive timing
peekaboo drag --from-coords "80,80" --to-coords "420,260" --profile human

# Range-select items by holding Shift
peekaboo drag --from row_1 --to row_5 --modifiers shift
```
