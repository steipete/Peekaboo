---
summary: 'Send special keys or sequences via peekaboo press'
---

# `peekaboo press`

`press` fires individual `SpecialKey` values (Return, Tab, arrows, F-keys, etc.) in sequence.

## Key options

| Flag | Description |
| --- | --- |
| `[keys…]` | Positional list of keys (`return`, `tab`, `up`, `f1`, `forward_delete`, …). |
| `--count <n>` | Repeat the entire key sequence `n` times (default `1`). |
| `--delay <ms>` | Delay between key presses (default `100`). |

## Examples

```bash
# Equivalent to hitting Return once
peekaboo press return

# Tab through a menu twice, then confirm
peekaboo press tab tab return

# Walk a dialog down three rows
peekaboo press down --count 3 --delay 200
```
