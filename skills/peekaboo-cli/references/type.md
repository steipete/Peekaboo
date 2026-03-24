---
summary: 'Inject keystrokes via peekaboo type'
---

# `peekaboo type`

`type` sends text, special keys, or a mix of both through the automation service.

## Key options

| Flag | Description |
| --- | --- |
| `[text]` | Optional positional string; supports escape sequences like `\n` (Return) and `\t` (Tab). |
| `--snapshot <id>` | Target a specific snapshot. |
| `--delay <ms>` | Milliseconds between synthetic keystrokes (default `2`). |
| `--wpm <80-220>` | Enable human-typing cadence at the chosen words per minute. |
| `--clear` | Issue Cmd+A, Delete before typing any new text. |
| `--return`, `--tab <count>`, `--escape`, `--delete` | Append those keypresses after (or without) the text payload. |

## Examples

```bash
# Type text and press Return afterwards
peekaboo type "open ~/Downloads\n" --app "Terminal"

# Clear the current field, type a username, tab twice, then hit Return
peekaboo type alice@example.com --clear --tab 2 --return

# Human typing at 140 WPM
peekaboo type "status report ready" --wpm 140
```
