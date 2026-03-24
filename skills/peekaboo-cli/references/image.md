---
summary: 'Capture raw screenshots or windows via peekaboo image'
---

# `peekaboo image`

`image` produces raw PNG/JPG files for windows, screens, menu bar regions, or the current frontmost app.

## Key options

| Flag | Description |
| --- | --- |
| `--app`, `--pid`, `--window-title`, `--window-index` | Resolve a window target. |
| `--mode screen|window|frontmost|multi` | Override the auto mode picker. |
| `--screen-index <n>` | Limit screen captures to a single display. |
| `--path <file>` | Force the output path. |
| `--retina` | Store captures at native Retina scale (2x). |
| `--format png|jpg` | Emit PNG (default) or JPEG. |
| `--analyze "prompt"` | Send the saved file to the configured AI provider. |

## Examples

```bash
# Capture Safari window and save a JPEG
peekaboo image --app Safari --window-title "Release Notes" --format jpg --path /tmp/safari.jpg

# Dump every display and summarize with AI
peekaboo image --mode screen --analyze "Summarize the key UI differences"

# Snapshot only the menu bar icons
peekaboo image --app menubar --capture-focus background
```
