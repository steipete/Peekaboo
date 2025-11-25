---
summary: 'Automate macOS Dock interactions via peekaboo dock'
read_when:
  - 'launching/closing apps through Dock affordances'
  - 'toggling Dock visibility or iterating over Dock items in scripts'
---

# `peekaboo dock`

`dock` exposes Dock-specific helpers so you don’t have to rely on brittle coordinate clicks. It leverages `DockServiceBridge`, which uses AX to locate Dock items, right-click menus, and visibility toggles.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `launch <app>` | Left-click a Dock icon to launch/activate it. | Positional app title as shown in the Dock. |
| `right-click` | Open a Dock item’s context menu (and optionally pick a menu item). | `--app <Dock title>` plus optional `--select "Keep in Dock"`, `--select "New Window"`, etc. |
| `hide` / `show` | Toggle Dock visibility (same as System Settings ➝ Dock & Menu Bar). | No options. |
| `list` | Enumerate Dock items, their bundle IDs, and whether they’re running/pinned. | `--json-output` prints structured info (titles, kind, position). |

## Implementation notes
- Item resolution is AX-based, so names match what VoiceOver would read (case-sensitive). Launching returns success even when the app is already running; the Dock is still clicked to bring it forward.
- `right-click` first finds the item, then triggers the context menu, then optionally selects `--select <title>`. If you omit `--select`, it just opens the menu (useful if you want to inspect it with `see`).
- Hide/show operations call the Dock service and return JSON/text acknowledgements; they don’t fiddle with defaults commands, so they’re instantaneous and reversible.
- Errors coming from `DockServiceBridge` (item not found, Dock unavailable) are mapped to structured error codes when `--json-output` is active, which helps CI detect missing icons.

## Examples
```bash
# Launch Safari directly from the Dock
polter peekaboo -- dock launch Safari

# Right-click Finder and choose "New Window"
polter peekaboo -- dock right-click --app Finder --select "New Window"

# Hide the Dock before recording a video
polter peekaboo -- dock hide
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
