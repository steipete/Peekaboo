---
summary: 'Drive application menus via peekaboo menu'
read_when:
  - 'navigating File/Edit/... menus or menu extras without UI scripting'
  - 'listing menu trees to grab exact command paths for automation'
---

# `peekaboo menu`

`menu` controls classic macOS menu bars and menu extras from the CLI. It focuses the target app (using `FocusCommandOptions`), resolves menu structures via `MenuServiceBridge`, and then either clicks items or prints the hierarchy so you can grab the right path.

## Subcommands
| Subcommand | Purpose | Key options |
| --- | --- | --- |
| `click` | Activate an application menu item via `--item` (single-level) or `--path "File > Export > PDF"`. | Target flags `--app <name|bundle|PID:1234>`, optional `--pid`, optional `--window-id`/`--window-title`/`--window-index`, plus all focus flags. Paths are normalized automatically if you accidentally pass a `'>'` string to `--item`. |
| `click-extra` | Click status-bar menu extras (Wi-Fi, Bluetooth, custom icons). | `--title <menu-extra>` is required; `--item` is parsed but currently prints a warning because nested extra menus aren’t implemented yet. |
| `list` | Dump the menu tree for a specific app (optionally showing disabled items). | Same target flags as `click`, plus `--include-disabled`. |
| `list-all` | Snapshot the frontmost app’s full menu tree *and* all system menu extras in one go. | `--include-disabled`, `--include-frames` (adds pixel coordinates for extras). |

## Implementation notes
- `click`/`list` accept the same target flags as other interaction commands (`--app`/`--pid` plus optional `--window-id`/`--window-title`/`--window-index`) and focus the best matching window before interacting. When no `--app`/`--pid` is provided, Peekaboo targets the frontmost app.
- Menu focus uses `ensureFocusIgnoringMissingWindows`, which tolerates apps that keep a menu bar without a visible window (e.g., Finder when all windows are closed).
- Any `--item` string that already contains `'>'` is automatically interpreted as a `--path` so agents don’t have to rewrite their inputs. The command even prints a note when this normalization occurs.
- Errors bubble up as typed `MenuError`s; JSON mode maps them to specific error codes (`MENU_ITEM_NOT_FOUND`, `MENU_BAR_NOT_FOUND`, etc.) so CI can distinguish between missing apps vs. absent menu items.
- `list-all` pairs `MenuServiceBridge.listFrontmostMenus` with `listMenuExtras`, filters disabled entries unless asked otherwise, and emits a structured `apps:[{menus,statusItems}]` payload when `--json-output` is used.

## Examples
```bash
# Click File > New Window in Safari
polter peekaboo -- menu click --app Safari --path "File > New Window"

# Inspect the Finder menu tree, including disabled actions
polter peekaboo -- menu list --app Finder --include-disabled

# Capture the current menu + menu extras as JSON (with coordinates)
polter peekaboo -- menu list-all --include-frames --json-output > /tmp/menu.json
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
