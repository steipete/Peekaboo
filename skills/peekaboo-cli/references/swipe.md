---
summary: 'Perform gesture-style drags via peekaboo swipe'
---

# `peekaboo swipe`

`swipe` drives gesture-style movement from one point to another over a fixed duration.

## Key options

| Flag | Description |
| --- | --- |
| `--from <id>` / `--from-coords x,y` | Source location. |
| `--to <id>` / `--to-coords x,y` | Destination location. |
| `--duration <ms>` | Default 500 ms. |
| `--steps <count>` | Number of intermediate points (default 20). |
| `--profile <linear|human>` | Use `human` for real-looking pointer motion. |

## Examples

```bash
# Swipe between two element IDs
peekaboo swipe --from card_1 --to card_2 --duration 650 --steps 30

# Drag from coordinates
peekaboo swipe --from-coords 120,880 --to-coords 120,200

# Human-style swipe
peekaboo swipe --from-coords 80,640 --to-coords 820,320 --profile human
```
