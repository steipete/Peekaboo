---
summary: 'Run Peekaboo as an MCP server via peekaboo mcp'
read_when:
  - 'exposing Peekaboo as an MCP server'
  - 'debugging MCP server startup or transport options'
---

# `peekaboo mcp`

`mcp` runs Peekaboo as a Model Context Protocol server. `peekaboo mcp` defaults to `serve`, so you can launch the server without specifying a subcommand.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `serve` | Run Peekaboo’s MCP server over stdio/HTTP/SSE. | `--transport stdio|http|sse` (default stdio), `--port <int>` for HTTP/SSE. |

## Implementation notes
- `serve` instantiates `PeekabooMCPServer` and maps the transport string to `PeekabooCore.TransportType`. Stdio is the default for Claude Code integrations.
- HTTP/SSE server transports are stubbed; they currently throw “not implemented.”

## Examples
```bash
# Start the Peekaboo MCP server (defaults to stdio)
polter peekaboo -- mcp

# Explicit transport selection
polter peekaboo -- mcp serve --transport stdio
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
