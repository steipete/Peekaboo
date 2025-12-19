---
summary: 'Inspect native tooling via peekaboo tools'
read_when:
  - 'deciding which automation tool to call from agents or scripts'
  - 'debugging missing tool registrations'
---

# `peekaboo tools`

`peekaboo tools` prints the authoritative tool catalog that the CLI, Peekaboo.app, and MCP server expose. The command hydrates the native tool set (Image, See, Click, Window, etc.) so you can audit everything an agent will see without attaching a debugger.

## Key options
| Flag | Description |
| --- | --- |
| `--no-sort` | Preserve registration order instead of alphabetizing every tool. |
| `--json-output` | Emit `{tools:[…], count:n}` for machine parsing. |

## Implementation notes
- The command instantiates every native `MCPTool` manually (ImageTool, ClickTool, DialogTool, etc.) so you see the same tool set the agent runtime will use.
- Filtering happens before formatting (`ToolFiltering.apply`), so allow/deny rules match the agent + MCP server behavior.
- Because the command implements `RuntimeOptionsConfigurable`, it respects global `--json-output`/`--verbose` flags even when invoked from other commands (e.g., `peekaboo learn` can embed the summaries verbatim).

## Examples
```bash
# Produce a JSON blob for an agent integration test
polter peekaboo -- tools --json-output > /tmp/tools.json
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
