---
summary: 'Enumerate apps, windows, screens, and permissions via peekaboo list'
---

# `peekaboo list`

`peekaboo list` is a container command for inventory subcommands.

## Subcommands

| Subcommand | What it does | Notable options |
| --- | --- | --- |
| `apps` (default) | Enumerates running GUI apps with bundle ID, PID, focus status. | None. |
| `windows` | Lists windows owned by a specific process. | `--app <name>`, `--include-details bounds,ids,off_screen`. |
| `menubar` | Dumps every status-item title/index. | `--json-output`. |
| `screens` | Shows connected displays, resolution, scaling. | None. |
| `permissions` | Mirrors `peekaboo permissions status`. | None. |

## Examples

```bash
# List every app visible to AX
peekaboo list

# Inspect Chrome windows with bounds + IDs
peekaboo list windows --app "Google Chrome" --include-details bounds,ids

# Pipe display layout into jq
peekaboo list screens --json-output | jq '.data.screens[] | {name, size: .frame}'
```
