---
summary: 'Drive application menus via peekaboo menu'
---

# `peekaboo menu`

`menu` controls classic macOS menu bars and menu extras from the CLI.

## Subcommands

| Subcommand | Purpose | Key options |
| --- | --- | --- |
| `click` | Activate an application menu item. | `--item` (single-level) or `--path "File > Export > PDF"`. |
| `click-extra` | Click status-bar menu extras. | `--title <menu-extra>`, `--verify`, `--item`. |
| `list` | Dump the menu tree for a specific app. | `--include-disabled`. |
| `list-all` | Snapshot the frontmost app's full menu tree + all system menu extras. | `--include-disabled`, `--include-frames`. |

## Examples

```bash
# Click File > New Window in Safari
peekaboo menu click --app Safari --path "File > New Window"

# Inspect the Finder menu tree, including disabled actions
peekaboo menu list --app Finder --include-disabled

# Capture the current menu + menu extras as JSON
peekaboo menu list-all --include-frames --json-output > /tmp/menu.json
```
