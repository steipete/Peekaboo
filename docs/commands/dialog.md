---
summary: 'Handle macOS dialogs via peekaboo dialog'
read_when:
  - 'clicking buttons or entering text in save/open/system dialogs'
  - 'needing to inspect dialog structure for automation debugging'
---

# `peekaboo dialog`

`dialog` wraps `DialogService` so you can programmatically inspect, click, type into, dismiss, or drive file dialogs without re-running `see`. Pass `--app`/`--window` hints whenever possible; the command will focus the host app (via `WindowServiceBridge`) before interacting.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `click` | Press a dialog button. | `--button <label>` (required), optional `--window <title>`, `--app <name>`. |
| `input` | Enter text into a dialog field. | `--text`, optional `--field <label>` or `--index <0-based>`, `--clear`, plus `--window`/`--app`. |
| `file` | Drive NSOpenPanel/NSSavePanel style dialogs. | `--path <dir>`, `--name <filename>`, `--select <button>` (default `Save`), `--app`. |
| `dismiss` | Close the current dialog. | `--force` (sends Esc), `--window`, `--app`. |
| `list` | Print dialog metadata (buttons, text fields, static text) for debugging. | `--window`, `--app`. |

## Implementation notes
- Every subcommand calls `focusDialogAppIfNeeded` to bring the host window/sheet forward. If the window can’t be focused (e.g., already gone) the helper swallows the error so retries don’t crash.
- Button clicks and text entry route through `services.dialogs` helpers, which return dictionaries describing what happened; JSON output exposes those details verbatim (`button`, `field`, `text_length`, etc.).
- `dialog input` accepts either a field label (`--field`) or an index; when neither is provided it targets the first text field. `--clear` issues a Cmd+A/Delete before typing.
- `dialog file` can both navigate to a path and fill the filename field, then clicks the action button you specify (`--select Save`, `--select Open`, etc.). Leave `--path` blank to simply confirm the current directory.
- `dialog list` is invaluable before scripting a dialog: it prints button titles, placeholders, and static text so you can pick stable labels instead of guessing.

## Examples
```bash
# Click "Don't Save" on a TextEdit sheet
polter peekaboo -- dialog click --button "Don't Save" --app TextEdit

# Enter credentials into a password prompt
polter peekaboo -- dialog input --text hunter2 --field "Password" --clear --app Safari

# Choose a file in an open panel and confirm
polter peekaboo -- dialog file --path ~/Downloads --name report.pdf --select Open
```
