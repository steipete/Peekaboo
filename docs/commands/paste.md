---
summary: 'Paste into an app by temporarily setting clipboard content'
read_when:
  - 'you want fewer steps than clipboard set + hotkey cmd,v + clipboard restore'
  - 'you need deterministic pastes without clobbering the user clipboard'
---

# `peekaboo paste`

`paste` is an atomic convenience wrapper:

1. Snapshot the current clipboard (if any)
2. Set clipboard content
3. Focus the target (optional, via `--app`/`--window-title`/`--window-index`)
4. Paste (`Cmd+V`)
5. Restore the previous clipboard (or clear if it was empty)

This reduces drift compared to running multiple commands manually.

## Key options
| Flag | Description |
| --- | --- |
| `--app` / `--window-title` / `--window-index` | Target/focus the destination before pasting. |
| `<text>` / `--text` | Paste plain text. |
| `--data-base64` + `--uti` | Paste a raw payload with an explicit UTI (e.g. `public.rtf`). |
| `--file-path` / `--image-path` | Load file bytes into the clipboard, then paste. |
| `--also-text` | Add a plain-text companion when setting binary data. |
| `--restore-delay-ms` | Wait before restoring the clipboard (helps apps that read clipboard lazily). |

## Examples
```bash
# Paste text into TextEdit
peekaboo paste "Hello" --app TextEdit

# Paste into a specific window
peekaboo paste --text "Hello" --app TextEdit --window-title "Untitled"

# Paste RTF (binary) with a text companion
peekaboo paste --data-base64 "$BASE64" --uti public.rtf --also-text "(fallback)" --app TextEdit
```

