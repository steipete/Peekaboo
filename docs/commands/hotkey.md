---
summary: 'Send modifier combos via peekaboo hotkey'
read_when:
  - 'triggering Cmd-based shortcuts without scripting AppleScript'
  - 'validating that focus handling works before firing global hotkeys'
---

# `peekaboo hotkey`

`hotkey` presses multiple keys at once (Cmd+C, Cmd+Shift+T, etc.). It accepts comma- or space-separated tokens either positionally or via `--keys`, normalizes them to lowercase, then hands the joined list to `AutomationServiceBridge.hotkey`. If you provide both, the positional value wins.

## Key options
| Flag | Description |
| --- | --- |
| `keys` / `--keys "cmd,c"` | Required list of keys (positional or `--keys`). Use commas or spaces; modifiers (`cmd`, `alt`, `ctrl`, `shift`, `fn`) can be mixed with letters/numbers/special keys. |
| `--hold-duration <ms>` | Milliseconds to hold the combo before releasing (default `50`). |
| `--session <id>` | Optional session to determine which app should be focused beforehand. |
| Focus flags | All `FocusCommandOptions` flags apply; focus only runs when a session is available. |

## Implementation notes
- The command errors if no keys are provided (either positionally or via `--keys`).
- When both forms are present, the positional value is used.
- Keys are parsed into an ordered list (press order) and rejoined with commas before calling the automation service, which expects `cmd,shift,p` style input and releases keys in reverse order.
- If you omit `--session`, the command skips `ensureFocused` entirely; this is handy for OS-global shortcuts like Spotlight, but for app-specific shortcuts you should reuse the `see` session.
- JSON mode returns the normalized key list, total count, and elapsed time, which is useful when logging scripted shortcuts.

## Examples
```bash
# Copy the current selection
polter peekaboo -- hotkey "cmd,c"

# Reopen the last closed tab in Safari
polter peekaboo -- hotkey --keys "cmd,shift,t" --session $(jq -r '.data.session_id' /tmp/see.json)

# Trigger Spotlight without needing a session
polter peekaboo -- hotkey --keys "cmd space" --no-auto-focus

# Tab backwards using Shift+Tab (positional, space-separated)
polter peekaboo -- hotkey "shift tab"
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
