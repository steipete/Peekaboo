---
summary: 'Inspect native tooling via peekaboo tools'
read_when:
  - 'deciding which automation tool to call from agents or scripts'
  - 'debugging missing tool registrations'
---

# `peekaboo tools`

`peekaboo tools` prints the authoritative native MCP tool catalog that `peekaboo mcp` exposes. The command hydrates the same native MCP tool set (Image, See, Click, Window, etc.) so you can audit what MCP clients will see without attaching a debugger.

## Key options
| Flag | Description |
| --- | --- |
| `--no-sort` | Preserve registration order instead of alphabetizing every tool. |
| `--json` | Emit `{tools:[…], count:n}` for machine parsing. |

## Implementation notes
- The command and MCP server both use `MCPToolCatalog`, so tool additions only need to be registered once.
- Filtering happens before formatting (`ToolFiltering.apply`), so allow/deny rules match MCP server behavior.
- Input-strategy availability filtering also runs before formatting, so action-only tools are hidden when the current policy cannot support them.
- The command runs locally by default because it only reports the static native catalog; pass `--bridge-socket <path>` only when you need to inspect a specific bridge host.
- Because the command implements `RuntimeOptionsConfigurable`, it respects global `--json`/`--verbose` flags even when invoked from other commands (e.g., `peekaboo learn` can embed the summaries verbatim).

## Examples
```bash
# Produce a JSON blob for an agent integration test
peekaboo tools --json > /tmp/tools.json
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json` or `--verbose` to surface detailed errors.
