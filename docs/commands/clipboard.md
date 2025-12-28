---
summary: 'Read/write the macOS clipboard via peekaboo clipboard'
read_when:
  - 'you need to seed or inspect clipboard content in automation flows'
  - 'saving/restoring the user clipboard around scripted actions'
---

# `peekaboo clipboard`

Work with the macOS pasteboard. Supports text, files/images, raw base64 payloads, and save/restore slots to avoid clobbering the user's clipboard.

## Actions
| Action | Description |
| --- | --- |
| `get` | Read the clipboard. Use `--prefer <uti>` to bias type selection and `--output <path|->` to write binary data. |
| `set` | Write text (`--text`), file/image (`--file-path`/`--image-path`), or base64 + `--uti`. Optional `--also-text` sets a plain-text companion. |
| `load` | Shortcut for `set` with a file path. |
| `clear` | Empty the clipboard. |
| `save` / `restore` | Snapshot and restore clipboard contents. Default slot is `"0"`; use `--slot` to name slots. |

## Key options
| Flag | Description |
| --- | --- |
| `--action` | One of `get`, `set`, `clear`, `save`, `restore`, `load`. |
| `--text` | Plain text to set. |
| `--file-path`, `--image-path` | File or image to copy (UTI inferred from extension). |
| `--data-base64` + `--uti` | Raw payload + explicit UTI. |
| `--prefer <uti>` | Preferred UTI when reading. |
| `--output <path|->` | Where to write binary data on `get`; `-` streams to stdout. |
| `--slot <name>` | Save/restore slot (default `0`). |
| `--also-text <string>` | Add a text representation when setting binary data. |
| `--allow-large` | Permit payloads over 10 MB (guard is 10 MB by default). |

## Examples
```bash
# Copy text
peekaboo clipboard --action set --text "hello world"

# Read clipboard and save binary to a file
peekaboo clipboard --action get --output /tmp/clip.bin

# Save, clear, then restore the user's clipboard
peekaboo clipboard --action save --slot original
peekaboo clipboard --action clear
peekaboo clipboard --action restore --slot original
```

## Notes
- Binary reads without `--output` return a summary; use `--output -` to pipe data.
- Slot saves are stored in a dedicated named pasteboard so they work across separate `peekaboo clipboard` invocations.
- `restore` removes the saved slot after applying it to avoid leaving clipboard snapshots around indefinitely.
- Size guard: writes larger than 10 MB require `--allow-large`.
- Text writes include both `public.plain-text` and the `.string`/`public.utf8-plain-text` representation for compatibility.

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
