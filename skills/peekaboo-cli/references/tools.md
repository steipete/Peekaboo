---
summary: 'Inspect native tooling via peekaboo tools'
---

# `peekaboo tools`

`peekaboo tools` prints the authoritative tool catalog that the CLI, Peekaboo.app, and MCP server expose.

## Key options

| Flag | Description |
| --- | --- |
| `--no-sort` | Preserve registration order instead of alphabetizing. |
| `--json-output` | Emit `{tools:[…], count:n}` for machine parsing. |

## Example

```bash
# Produce a JSON blob of all tools
peekaboo tools --json-output > /tmp/tools.json
```
