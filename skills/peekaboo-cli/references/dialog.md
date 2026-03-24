---
summary: 'Handle macOS dialogs via peekaboo dialog'
---

# `peekaboo dialog`

`dialog` wraps `DialogService` so you can programmatically inspect, click, type into, dismiss, or drive file dialogs.

## Subcommands

| Name | Purpose | Key options |
| --- | --- | --- |
| `click` | Press a dialog button. | `--button <label>`, `--app`. |
| `input` | Enter text into a dialog field. | `--text`, `--field <label>`, `--clear`. |
| `file` | Drive NSOpenPanel/NSSavePanel dialogs. | `--path <dir>`, `--name <filename>`, `--select <button>`. |
| `dismiss` | Close the current dialog. | `--force` (sends Esc). |
| `list` | Print dialog metadata for debugging. | None. |

## Examples

```bash
# Click "Don't Save" on a TextEdit sheet
peekaboo dialog click --button "Don't Save" --app TextEdit

# Enter credentials into a password prompt
peekaboo dialog input --text hunter2 --field "Password" --clear --app Safari

# Choose a file in an open panel
peekaboo dialog file --path ~/Downloads --name report.pdf --select Open

# Save a file and verify
peekaboo dialog file --path /tmp --name poem.rtf --select Save --app TextEdit
```
