---
summary: 'Move, resize, and focus windows via peekaboo window'
read_when:
  - 'wrangling app windows before issuing UI interactions'
  - 'needing JSON receipts for close/minimize/maximize/focus actions'
---

# `peekaboo window`

`window` gives you programmatic control over macOS windows. Every subcommand accepts `WindowIdentificationOptions` (`--app`, `--pid`, `--window-title`, `--window-index`) so you can pinpoint the exact window before acting. Output is mirrored in JSON and text for easy scripting.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `close` / `minimize` / `maximize` | Perform the respective window chrome action. | Standard window-identification flags. |
| `focus` | Bring the window forward, optionally hopping Spaces or moving it to the current Space. | Adds `FocusCommandOptions` (`--no-auto-focus`, `--space-switch`, `--bring-to-current-space`, `--focus-timeout-seconds`, `--focus-retry-count`). |
| `move` | Move the window to new coordinates. | `-x <int>` / `-y <int>` specify the new origin. |
| `resize` | Adjust width/height while keeping the origin. | `-w <int>` / `--height <int>`. |
| `set-bounds` | Set both origin and size in one go. | `--x`, `--y`, `--width`, `--height`. |
| `list` | Shortcut for `list windows` scoped to a single app. | Same targeting flags; outputs the `list windows` payload. |

## Implementation notes
- Every action validates that at least an app or PID is supplied; optional `--window-title` and `--window-index` disambiguate when multiple windows exist.
- All geometry-changing commands re-fetch window info after acting (when possible) and stuff the updated bounds into the JSON payload so automated tests can assert the final rectangle.
- `focus` routes through `WindowServiceBridge.focusWindow` and honors the global focus flags (`--space-switch` to jump Spaces, `--bring-to-current-space` to move the window instead, etc.). It logs debug output when focus fails so agents know to fall back.
- When `window list` runs, it simply calls the same helper as `peekaboo list windows` but saves you from retyping the longer command.

## Examples
```bash
# Move Finder’s 2nd window to (100,100)
polter peekaboo -- window move --app Finder --window-index 1 -x 100 -y 100

# Resize Safari’s frontmost window to 1200x800
polter peekaboo -- window resize --app Safari -w 1200 --height 800

# Focus Terminal even if it lives on another Space
polter peekaboo -- window focus --app Terminal --space-switch
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
