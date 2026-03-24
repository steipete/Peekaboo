---
summary: 'Open files/URLs with Peekaboo focus controls via peekaboo open'
---

# `peekaboo open`

`open` mirrors macOS `open` but with Peekaboo's focus control and structured output.

## Key options

| Flag | Description |
| --- | --- |
| `[target]` | Required positional path or URL. |
| `--app <name|path>` | Force a particular application. |
| `--bundle-id <id>` | Resolve the handler via bundle ID. |
| `--wait-until-ready` | Block until the handler reports ready (10s timeout). |
| `--no-focus` | Leave the handler in the background. |

## Examples

```bash
# Open a PDF without stealing focus
peekaboo open ~/Docs/spec.pdf --no-focus

# Force TextEdit and wait
peekaboo open /tmp/notes.txt --bundle-id com.apple.TextEdit --wait-until-ready

# Launch Safari with a URL
peekaboo open https://example.com --json-output
```
