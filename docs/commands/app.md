---
summary: 'Control macOS apps via peekaboo app'
read_when:
  - 'launching/quitting/focusing apps as part of an automation flow'
  - 'auditing running apps or force cycling foreground focus'
---

# `peekaboo app`

`app` bundles every app-management primitive Peekaboo exposes: launching, quitting, hiding, relaunching, switching focus, and listing processes. Each subcommand works directly with `NSWorkspace`/AX data so it shares the same view of the system as the rest of the CLI.

## Subcommands
| Name | Purpose | Key flags |
| --- | --- | --- |
| `launch` | Start an app by name/path/bundle ID, optionally opening documents. | `--bundle-id`, `--open <path|url>` (repeatable), `--wait-until-ready`, `--no-focus`. |
| `quit` | Quit one app or *all* regular apps (with optional exclusions). | `--app <name>`, `--pid`, `--all`, `--except "Finder,Terminal"`, `--force`. |
| `relaunch` | Quit + relaunch the same app in one step. | Positional `<app>`, `--wait <seconds>` between quit/launch, `--force`, `--wait-until-ready`. |
| `hide` / `unhide` | Toggle app visibility. | Accept the same targeting flags as `launch`/`quit`. |
| `switch` | Activate a specific app (`--to`) or cycle Cmd+Tab style (`--cycle`). | `--to <name|bundle|PID:1234>`, `--cycle`. |
| `list` | Enumerate running apps. | `--include-hidden`, `--include-background`. |

## Implementation notes
- Launch resolves bundle IDs first, then friendly names (searching `/Applications`, `/System/Applications`, `~/Applications`, etc.), and finally absolute paths. `--open` can be repeated to pass multiple documents/URLs to the launched app.
- Quit mode supports `--all` plus `--except`, automatically ignoring core system processes (`Finder`, `Dock`, `SystemUIServer`, `WindowServer`). When quits fail, the command prints hints about unsaved changes and suggests `--force`.
- Hide/unhide uses `NSRunningApplication.hide()` / `.unhide()` and surfaces JSON output with per-app success data.
- `switch --cycle` synthesizes Cmd+Tab events using `CGEvent` so it behaves like the real keyboard shortcut; `switch --to` activates the exact PID resolved via AX.
- `relaunch` polls for termination (up to 5 s), waits the requested interval, then launches via bundle ID or bundle path and optionally waits for `isFinishedLaunching` before reporting success.

## Examples
```bash
# Launch Xcode with a project and keep it backgrounded
polter peekaboo -- app launch "Xcode" --open ~/Projects/Peekaboo.xcodeproj --no-focus

# Quit everything but Finder and Terminal
polter peekaboo -- app quit --all --except "Finder,Terminal"

# Cycle to the next app exactly once
polter peekaboo -- app switch --cycle
```
