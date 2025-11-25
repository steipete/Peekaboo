---
summary: 'Open files/URLs with Peekaboo focus controls via peekaboo open'
read_when:
  - 'handing documents/URLs to specific apps from automation scripts'
  - 'needing structured output around macOS open events'
---

# `peekaboo open`

`open` mirrors macOS `open` but layers on Peekaboo’s conveniences: session-level logging, JSON output, focus control, and “wait until ready” behavior. It resolves paths (with `~` expansion), honors URLs with schemes, and optionally forces a specific handler.

## Key options
| Flag | Description |
| --- | --- |
| `[target]` | Required positional path or URL. Relative paths are resolved against the current working directory. |
| `--app <name|path>` | Force a particular application by friendly name, bundle ID, or `.app` path. |
| `--bundle-id <id>` | Resolve the handler via bundle ID directly. Overrides `--app` if both are set. |
| `--wait-until-ready` | Block until the handler reports `isFinishedLaunching` (10 s timeout). |
| `--no-focus` | Leave the handler in the background even after opening. |
| Global flags | `--json-output` prints an `OpenResult` (target, resolved target, handler name, PID, focus state). |

## Implementation notes
- Targets without a URL scheme are treated as filesystem paths; relative values are combined with `FileManager.default.currentDirectoryPath`, and `~` prefixes expand to the user’s home.
- Handler resolution tries bundle ID, friendly name, `.app` path, or direct path in that order. If nothing matches, the command throws `NotFoundError.application` with the exact string you passed.
- When no handler is specified, the default macOS association handles the file/URL, but you still get structured output describing whichever app actually opened it.
- Focus defaults to “on” (like `open`); passing `--no-focus` sets `NSWorkspace.OpenConfiguration.activates = false` and skips the activation attempt.
- `--wait-until-ready` uses the same polling helper as `app launch`, so it’s safe to use this command before issuing follow-up clicks/keystrokes.

## Examples
```bash
# Open a PDF in the default viewer but avoid stealing focus
polter peekaboo -- open ~/Docs/spec.pdf --no-focus

# Force TextEdit to open a scratch file and wait for it to become ready
polter peekaboo -- open /tmp/notes.txt --bundle-id com.apple.TextEdit --wait-until-ready

# Launch Safari with a URL and report the resulting PID as JSON
polter peekaboo -- open https://example.com --json-output
```

## Design notes
- Purpose: mirror `open -a` workflows while keeping Peekaboo’s logging, focus control, and structured JSON output.
- Target resolution: if the argument has a URL scheme, use it; otherwise expand `~`, resolve relative paths against CWD, and build a file URL (path need not exist).
- Handler selection order: explicit `--bundle-id` → `--app` (bundle lookup, `.app` path, or common app directories) → system default handler. Invalid selectors throw `NotFoundError.application`.
- Execution: builds `NSWorkspace.OpenConfiguration` with `activates = !noFocus`, polls up to 10s when `--wait-until-ready`, and still succeeds if activation fails (logs a warning).
- Output shape (JSON): includes success flag, original + resolved target, handler app name + bundle id, PID, readiness, and focus state.
