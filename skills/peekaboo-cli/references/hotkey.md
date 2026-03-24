---
summary: 'Send modifier combos via peekaboo hotkey'
---

# `peekaboo hotkey`

`hotkey` presses multiple keys at once (Cmd+C, Cmd+Shift+T, etc.).

## Key options

| Flag | Description |
| --- | --- |
| `keys` / `--keys "cmd,c"` | Required list of keys. Use commas or spaces; modifiers (`cmd`, `alt`, `ctrl`, `shift`, `fn`) can be mixed with letters/numbers. |
| `--hold-duration <ms>` | Milliseconds to hold the combo before releasing (default `50`). |

## Examples

```bash
# Copy the current selection
peekaboo hotkey "cmd,c"

# Reopen the last closed tab
peekaboo hotkey --keys "cmd,shift,t"

# Trigger Spotlight
peekaboo hotkey --keys "cmd space" --no-auto-focus

# Tab backwards using Shift+Tab
peekaboo hotkey "shift tab"
```
