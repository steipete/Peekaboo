---
summary: 'Position the cursor via peekaboo move'
---

# `peekaboo move`

`move` repositions the macOS cursor using coordinates, element IDs, or fuzzy queries.

## Key options

| Flag | Description |
| --- | --- |
| `[x,y]` / `--coords <x,y>` | Coordinate target. |
| `--id <element-id>` | Jump to a Peekaboo element's midpoint. |
| `--to <query>` | Resolve an element by text/query. |
| `--center` | Move to the main screen's center. |
| `--smooth` | Animate the move (default 500 ms, 20 steps). |
| `--profile <linear|human>` | `human` enables eased arcs and micro-jitter. |

## Examples

```bash
# Instantly move to a coordinate
peekaboo move 1024,88

# Human-style movement
peekaboo move 520,360 --profile human

# Hover an element by ID
peekaboo move --id menu_gear --smooth

# Center the cursor
peekaboo move --center --duration 250
```
