---
summary: 'Paste text or rich content via peekaboo paste'
---

# `peekaboo paste`

`paste` is an atomic "clipboard + Cmd+V + restore" helper. It temporarily replaces the clipboard, pastes, then restores the previous contents.

## Key options

| Flag | Description |
| --- | --- |
| `[text]` / `--text` | Plain text to paste. |
| `--file-path` / `--image-path` | Copy a file or image, then paste. |
| `--data-base64` + `--uti` | Paste raw base64 payload with explicit UTI. |
| `--restore-delay-ms` | Delay before restoring previous clipboard (default 150ms). |

## Examples

```bash
# Paste plain text into TextEdit
peekaboo paste "Hello, world" --app TextEdit

# Paste rich text (RTF)
peekaboo paste --data-base64 "$RTF_B64" --uti public.rtf --app TextEdit

# Paste a PNG into Notes
peekaboo paste --file-path /tmp/snippet.png --app Notes
```
