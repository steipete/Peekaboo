---
summary: 'Manage macOS Spaces via peekaboo space'
---

# `peekaboo space`

`space` wraps Peekaboo's SpaceManagementService to list Spaces, switch among them, and move windows.

## Subcommands

| Name | Purpose | Key options |
| --- | --- | --- |
| `list` | Enumerate Spaces and their windows. | `--detailed` for per-window crawl. |
| `switch` | Jump to a Space by number. | `--to <n>` (1-based). |
| `move-window` | Move an app window to another Space. | `--app`, `--to <n>` or `--to-current`, `--follow`. |

## Examples

```bash
# Show every Space plus assigned windows
peekaboo space list --detailed

# Move Safari window to Space 3 and follow it
peekaboo space move-window --app Safari --to 3 --follow

# Switch back to Space 1
peekaboo space switch --to 1
```
