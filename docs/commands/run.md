---
summary: 'Execute .peekaboo.json scripts via peekaboo run'
read_when:
  - 'batching multiple CLI steps into a reusable automation script'
  - 'capturing structured execution results for regression tests'
---

# `peekaboo run`

`peekaboo run` loads a `.peekaboo.json` (PeekabooScript) file, executes every step via `ProcessService`, and reports the aggregated result. It’s the same engine the agent runtime uses for scripted flows, which makes it ideal for regression suites or reproducing agent traces.

## Key options
| Flag | Description |
| --- | --- |
| `<scriptPath>` | Positional argument pointing at a `.peekaboo.json` file. |
| `--output <file>` | Write the JSON execution report to disk instead of stdout. |
| `--no-fail-fast` | Continue executing the remaining steps even if one fails (default behavior is fail-fast). |
| `--json-output` | Emit machine-readable JSON to stdout (wrapper + `ScriptExecutionResult`). (Alias: `--json` / `-j`) |

## Implementation notes
- Scripts are parsed on the main actor via `services.process.loadScript`, so relative paths (`~/`, `./`) resolve exactly as they do when agents run scripts.
- Execution delegates to `services.process.executeScript`, which returns a `[StepResult]` containing individual timings, success flags, and error strings; the command wraps those in a summary with total durations and counts.
- `--output` writes via `JSONEncoder().encode` + atomic file replacement; if the write succeeds but the script fails, you still get the partial data for debugging.
- In JSON mode (`--json-output` / `--json` / `-j`), stdout is a single `CodableJSONResponse<ScriptExecutionResult>` payload (top-level `success` tracks overall script success).
- The command exits non-zero if any step fails (even when `--no-fail-fast` continues execution) so CI can register the run as failed.

## Examples
```bash
# Run a script and view the JSON summary inline
polter peekaboo -- run scripts/safari-login.peekaboo.json --json-output

# Capture results for later inspection but keep executing even if a step flakes
polter peekaboo -- run ./flows/regression.peekaboo.json --no-fail-fast --output /tmp/regression-results.json
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
