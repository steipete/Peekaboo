---
summary: 'Automate macOS Dock interactions via peekaboo dock'
---

# `peekaboo dock`

`dock` exposes Dock-specific helpers using AX to locate Dock items.

## Subcommands

| Name | Purpose | Key options |
| --- | --- | --- |
| `launch <app>` | Left-click a Dock icon to launch/activate. | `--verify` to wait for app running. |
| `right-click` | Open a Dock item's context menu. | `--app <Dock title>`, `--select "Keep in Dock"`. |
| `hide` / `show` | Toggle Dock visibility. | None. |
| `list` | Enumerate Dock items. | `--json-output`. |

## Examples

```bash
# Launch Safari from the Dock
peekaboo dock launch Safari

# Launch and verify
peekaboo dock launch Safari --verify

# Right-click Finder and choose "New Window"
peekaboo dock right-click --app Finder --select "New Window"

# Hide the Dock
peekaboo dock hide
```
