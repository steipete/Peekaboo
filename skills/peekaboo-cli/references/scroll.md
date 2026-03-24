---
summary: 'Simulate mouse wheel movement via peekaboo scroll'
---

# `peekaboo scroll`

`scroll` emulates trackpad/mouse-wheel input in any direction.

## Key options

| Flag | Description |
| --- | --- |
| `--direction up|down|left|right` | Required. Case-insensitive. |
| `--amount <ticks>` | Number of scroll "ticks" (default `3`). |
| `--on <element-id>` | Scroll relative to a Peekaboo element from the snapshot. |
| `--smooth` | Use smaller increments for finer movement. |

## Examples

```bash
# Scroll down five ticks at the current pointer position
peekaboo scroll --direction down --amount 5

# Scroll the element labeled "table_orders"
peekaboo scroll --direction up --amount 2 --on table_orders

# Smooth horizontal pan
peekaboo scroll --direction right --smooth --app Keynote
```
