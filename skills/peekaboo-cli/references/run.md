---
summary: 'Execute .peekaboo.json scripts via peekaboo run'
---

# `peekaboo run`

`peekaboo run` loads a `.peekaboo.json` (PeekabooScript) file and executes every step.

## Key options

| Flag | Description |
| --- | --- |
| `<scriptPath>` | Positional argument pointing at a `.peekaboo.json` file. |
| `--output <file>` | Write the JSON execution report to disk. |
| `--no-fail-fast` | Continue executing even if a step fails. |
| `--json-output` | Emit machine-readable JSON to stdout. |

## Examples

```bash
# Run a script and view the JSON summary
peekaboo run scripts/safari-login.peekaboo.json --json-output

# Capture results but keep executing even if a step flakes
peekaboo run ./flows/regression.peekaboo.json --no-fail-fast --output /tmp/results.json
```
