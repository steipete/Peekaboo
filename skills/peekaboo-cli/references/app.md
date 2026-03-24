---
summary: 'Control macOS apps via peekaboo app'
---

# `peekaboo app`

`app` bundles every app-management primitive: launching, quitting, hiding, relaunching, switching focus, and listing processes.

## Subcommands

| Name | Purpose | Key flags |
| --- | --- | --- |
| `launch` | Start an app by name/path/bundle ID. | `--bundle-id`, `--open <path|url>`, `--wait-until-ready`, `--no-focus`. |
| `quit` | Quit one app or *all* regular apps. | `--app <name>`, `--all`, `--except "Finder,Terminal"`, `--force`. |
| `relaunch` | Quit + relaunch the same app. | `--wait <seconds>`, `--force`, `--wait-until-ready`. |
| `hide` / `unhide` | Toggle app visibility. | Same targeting flags as `launch`/`quit`. |
| `switch` | Activate a specific app or cycle Cmd+Tab style. | `--to <name|bundle|PID:1234>`, `--cycle`, `--verify`. |
| `list` | Enumerate running apps. | `--include-hidden`, `--include-background`. |

## Examples

```bash
# Launch Xcode with a project
peekaboo app launch "Xcode" --open ~/Projects/MyApp.xcodeproj --no-focus

# Quit everything but Finder and Terminal
peekaboo app quit --all --except "Finder,Terminal"

# Switch and verify the app is frontmost
peekaboo app switch --to Safari --verify

# Cycle to the next app
peekaboo app switch --cycle
```
