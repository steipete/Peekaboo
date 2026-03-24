---
summary: 'Read/write the macOS clipboard via peekaboo clipboard'
---

# `peekaboo clipboard`

Work with the macOS pasteboard. Supports text, files/images, raw base64 payloads, and save/restore slots.

## Actions

| Action | Description |
| --- | --- |
| `get` | Read the clipboard. Use `--output <path|->` for binary data. |
| `set` | Write text (`--text`), file/image (`--file-path`), or base64. |
| `load` | Shortcut for `set` with a file path. |
| `clear` | Empty the clipboard. |
| `save` / `restore` | Snapshot and restore clipboard contents with `--slot`. |

## Examples

```bash
# Copy text
peekaboo clipboard --action set --text "hello world"

# Copy text and verify
peekaboo clipboard --action set --text "hello world" --verify

# Save, clear, then restore the user's clipboard
peekaboo clipboard --action save --slot original
peekaboo clipboard --action clear
peekaboo clipboard --action restore --slot original
```
