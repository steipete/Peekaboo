---
summary: 'Handle macOS dialogs via peekaboo dialog'
read_when:
  - 'clicking buttons or entering text in save/open/system dialogs'
  - 'needing to inspect dialog structure for automation debugging'
---

# `peekaboo dialog`

`dialog` wraps `DialogService` so you can programmatically inspect, click, type into, dismiss, or drive file dialogs without re-running `see`. Pass a target (`--app`/`--pid` plus optional `--window-title`/`--window-index`) whenever possible so Peekaboo can focus the right app/window before interacting.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `click` | Press a dialog button. | `--button <label>` (required), optional `--app`/`--pid`, `--window-title`/`--window-index`. |
| `input` | Enter text into a dialog field. | `--text`, optional `--field <label>` or `--index <0-based>`, `--clear`, plus `--app`/`--pid`, `--window-title`/`--window-index`. |
| `file` | Drive NSOpenPanel/NSSavePanel style dialogs. | `--path <dir>`, `--name <filename>`, `--select <button>` (omit / `default` clicks OKButton), `--ensure-expanded`, optional `--app`/`--pid`, `--window-title`/`--window-index`. Save-like actions verify the file exists and return `saved_path`. |
| `dismiss` | Close the current dialog. | `--force` (sends Esc), optional `--app`/`--pid`, `--window-title`/`--window-index`. |
| `list` | Print dialog metadata (buttons, text fields, static text) for debugging. | Optional `--app`/`--pid`, `--window-title`/`--window-index`. |

## Implementation notes
- `dialog` subcommands share the same targeting flags as other interaction commands (`--app`/`--pid` plus `--window-title`/`--window-index`) and use the same focus helpers before interacting.
- Button clicks and text entry route through `services.dialogs` helpers, which return dictionaries describing what happened; JSON output exposes those details verbatim (`button`, `field`, `text_length`, etc.).
- `dialog input` accepts either a field label (`--field`) or an index; when neither is provided it targets the first text field. `--clear` issues a Cmd+A/Delete before typing.
- `dialog file` can both navigate to a path and fill the filename field, then clicks the action button you specify (`--select Save`, `--select Open`, etc.). Leave `--path` blank to simply confirm the current directory.
- `dialog file` defaults to clicking the dialog’s `OKButton` when `--select` is omitted (or set to `default`). Prefer this when you don’t want to guess whether the button is labeled “Save”, “Open”, “Choose”, etc.
- `--ensure-expanded` expands the dialog (Show Details) before applying `--path`. If no `PathTextField` is present, Peekaboo falls back to the standard “Go to Folder…” shortcut to reliably land in the requested directory.
- For save-like actions (resolved by the actual clicked button title), `dialog file` verifies that the saved file appears on disk (5s timeout). On success it returns `saved_path` and `saved_path_verified=true`. If you provided `--path` + `--name`, Peekaboo also enforces that the file landed in the requested directory (symlinks like `/tmp` → `/private/tmp` are normalized).
- JSON output includes additional provenance for debugging without screenshots, including `dialog_identifier`, `found_via`, `button_identifier`, `saved_path_found_via`, and `path_navigation_method` (e.g. `path_textfield_typed+fallback_go_to_folder`).
- `dialog list` is invaluable before scripting a dialog: it prints button titles, placeholders, and static text so you can pick stable labels instead of guessing.

## Examples
```bash
# Click "Don't Save" on a TextEdit sheet
polter peekaboo -- dialog click --button "Don't Save" --app TextEdit

# Enter credentials into a password prompt
polter peekaboo -- dialog input --text hunter2 --field "Password" --clear --app Safari

# Choose a file in an open panel and confirm
polter peekaboo -- dialog file --path ~/Downloads --name report.pdf --select Open

# Save a file and verify the resulting path exists
polter peekaboo -- dialog file --path /tmp --name poem.rtf --select Save --app TextEdit --json-output

# Click the default action (OKButton) and include dialog provenance in JSON output
polter peekaboo -- dialog file --path ~/Downloads --name report.pdf --ensure-expanded --app TextEdit --json-output
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
