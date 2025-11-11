---
summary: 'Track active interaction-layer bugs and reproduction steps'
read_when:
  - Debugging CLI interaction regressions
  - Triaging Peekaboo automation failures
---

# Interaction Debugging Notes

## `see` command can’t finalize captures
- **Command**: `polter peekaboo -- see --app TextEdit --path /tmp/textedit-see.png --annotate --json-output`
- **Observed**: Logger reports a successful capture, saves `/tmp/textedit-see.png`, then throws `INTERNAL_SWIFT_ERROR` with message `The file “textedit-see.png” doesn’t exist.` The file *does* exist immediately after the failure (checked via `ls -l /tmp/textedit-see.png`).
- **Expected**: Command should return success (or at least surface a real capture error) once the screenshot is on disk.
- **Impact**: Blocks every downstream workflow that needs fresh UI element maps. Even `peekaboo see --app TextEdit` without `--path` fails with the same error, so agents can’t gather element IDs at all.

## `list windows` silently emits nothing
- **Command**: `polter peekaboo list windows --app TextEdit`
- **Observed**: Exit status 0 but no stdout/stderr, regardless of `--json-output` or `--verbose`.
- **Expected**: Either a formatted window list or an explicit “no windows found” message / JSON payload.
- **Impact**: Prevents automation flows from enumerating windows to obtain IDs; also makes debugging focus issues impossible because there’s no feedback.

## Help surface is unreachable
- Root help instructs users to run `peekaboo help <subcommand>` or `<subcommand> --help`, but:
  - `polter peekaboo help window` → `Error: Unknown command 'help'`
  - `polter peekaboo image --help` → `Error: Unknown option --help`
  - Even `polter peekaboo click --help` gets intercepted by `polter`’s own help instead of reaching Peekaboo.
- **Impact**: There is no discoverable way to read per-command usage/flags from the CLI, which leaves agents guessing (and documentation contradicting reality).

### Next steps I'd suggest
1. Instrument `SeeCommand`’s `saveCaptureResult`/`performCapture` pipeline to trace when the `SavedFile.path` gets registered and why later validation thinks it’s missing (maybe a relative-path vs. expanded-path check?).
2. Verify `ListCommand.WindowsSubcommand` reaches `outputSuccessCodable` or `CLIFormatter`—it looks like the command is exiting before printing. If the service returns data, something is suppressing output; if it doesn’t, emit an explicit empty result block.
3. Restore Commander help wiring by registering a top-level `help` command (or aliasing to `peekaboo --help <subcommand>`) and ensuring each subcommand signature includes the standard `--help` flag so downstream tooling and docs stay aligned.
