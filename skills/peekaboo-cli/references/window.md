---
summary: 'Move, resize, and focus windows via peekaboo window'
---

# `peekaboo window`

`window` gives you programmatic control over macOS windows.

## Subcommands

| Name | Purpose | Key options |
| --- | --- | --- |
| `close` / `minimize` / `maximize` | Perform the respective window chrome action. | Standard window-identification flags. |
| `focus` | Bring the window forward, optionally hopping Spaces. | `--verify`, plus `--space-switch`. |
| `move` | Move the window to new coordinates. | `-x <int>` / `-y <int>`. |
| `resize` | Adjust width/height. | `-w <int>` / `--height <int>`. |
| `set-bounds` | Set both origin and size in one go. | `--x`, `--y`, `--width`, `--height`. |
| `list` | List windows for a specific app. | Same targeting flags. |

## Examples

```bash
# Move Finder's 2nd window to (100,100)
peekaboo window move --app Finder --window-index 1 -x 100 -y 100

# Resize Safari's frontmost window to 1200x800
peekaboo window resize --app Safari -w 1200 --height 800

# Focus Terminal even if it lives on another Space
peekaboo window focus --app Terminal --space-switch

# Close a specific window by ID
peekaboo window close --window-id 12345
```
