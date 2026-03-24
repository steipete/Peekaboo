---
summary: 'Run Peekaboo as an MCP server via peekaboo mcp'
---

# `peekaboo mcp`

`mcp` runs Peekaboo as a Model Context Protocol server.

## Subcommands

| Name | Purpose | Key options |
| --- | --- | --- |
| `serve` | Run Peekaboo's MCP server over stdio/HTTP/SSE. | `--transport stdio|http|sse` (default stdio), `--port <int>`. |

## Examples

```bash
# Start the MCP server (defaults to stdio)
peekaboo mcp

# Explicit transport selection
peekaboo mcp serve --transport stdio
```
