---
summary: 'Capture annotated UI maps with peekaboo see'
---

# `peekaboo see`

`peekaboo see` captures the current macOS UI, extracts accessibility metadata, and (optionally) saves annotated screenshots. CLI and agent flows rely on these UI maps to find element IDs (`elem_123`), bounds, labels, and snapshot IDs.

## Key options

| Flag | Description |
| --- | --- |
| `--app`, `--window-title`, `--pid` | Limit capture to a known app/window/process. |
| `--mode screen` | Capture the entire display instead of a single window. |
| `--annotate` | Overlay element bounds/IDs on the output image. |
| `--path <file>` | Save the screenshot/annotation to disk. |
| `--json-output` | Emit structured metadata (recommended for scripting). |
| `--menubar` | Capture menu bar popovers via window list + OCR. |
| `--timeout-seconds <seconds>` | Increase overall timeout for large/complex windows. |

## Examples

```bash
# Capture frontmost window, print JSON, and save an annotated PNG
peekaboo see --json-output --annotate --path /tmp/see.png

# Target a specific app or window title
peekaboo see --app "Google Chrome" --window-title "Login"

# Find elements with jq
peekaboo see --app "Safari" --json-output | jq '.data.ui_elements[] | select(.label | test("Sign in"; "i"))'
```

## Troubleshooting

- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- If the CLI reports **blind typing**, re-run `see` with `--app <Name>` so we can autofocus the app before typing.
