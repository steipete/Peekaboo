---
summary: 'Manage Model Context Protocol servers via peekaboo mcp'
read_when:
  - 'exposing Peekaboo as an MCP server or consuming external MCP tools'
  - 'adding/removing/testing MCP server configs for Claude/Inspector workflows'
---

# `peekaboo mcp`

`mcp` is the control surface for Peekaboo’s Model Context Protocol stack. It can launch Peekaboo as a server (`mcp serve`), manage external servers (add/remove/enable/disable/test/info/list), and even call remote tools directly. All subcommands operate on the same profile that the MCP runtime loads, so edits here immediately affect Peekaboo.app and the CLI.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `serve` | Run Peekaboo’s MCP server over stdio/HTTP/SSE. | `--transport stdio|http|sse` (default stdio), `--port <int>` for HTTP/SSE. |
| `list` | Show configured external servers (plus optional health checks). | `--skip-health-check` skips probing. |
| `add <name> -- <command …>` | Register a new server definition. | `--transport`, `--env KEY=VALUE` (repeatable), `--header Key=Value` for HTTP/SSE, `--timeout`, `--description`, `--disabled`. Command/args come after `--`. |
| `remove` | Delete a server from the profile. | `--force` skips confirmation. |
| `enable` / `disable` | Toggle a server’s enabled flag and (re)connect/disconnect. | Server name argument required. |
| `info` | Dump the stored config + current health report for one server. | Respects `--json-output`. |
| `test` | Probe connectivity and (optionally) list tools. | `--timeout <seconds>`, `--show-tools`. |
| `call` | Invoke a tool exposed by another MCP server. | Positional `<server>`, `--tool <name>`, `--args '{"key":"value"}'` (JSON). |
| `inspect` | Reserved stub that currently just reports “not implemented.” | No options yet—expect failure until the inspector flow lands. |

## Implementation notes
- `serve` instantiates `PeekabooMCPServer` and maps the transport string to `PeekabooCore.TransportType`. Stdio is the default for Claude Code integrations; HTTP/SSE is wired for the forthcoming remote mode.
- `list` registers a built-in Chrome DevTools MCP server (`npx -y chrome-devtools-mcp@latest`) before scanning user profiles, ensuring it shows up even if you never ran `mcp add chrome-devtools …`.
- Adding servers parses repeated `--env` / `--header` flags into dictionaries, persists the profile via `TachikomaMCPClientManager.persist()`, and immediately probes the server unless `--disabled` is set.
- `call` parses `--args` as arbitrary JSON (objects or `null`), waits for the server to report healthy, then prints either a colored textual response or a JSON payload matching the MCP spec (content array, metadata, errors, etc.).
- Enable/disable/test/info all leverage `MCPClientManager.shared`, so running them keeps the MCP daemon in sync with your edits without restarting Peekaboo.

## Examples
```bash
# Start the Peekaboo MCP server for Claude Code (stdio transport)
polter peekaboo -- mcp serve

# Add a local Chrome DevTools MCP helper
polter peekaboo -- mcp add chrome-devtools-local --transport stdio -- env API_TOKEN=abc -- npx -y chrome-devtools-mcp@latest

# Call a remote tool with JSON args and see the structured response
polter peekaboo -- mcp call claude-code --tool edit_file --args '{"path":"main.swift"}' --json-output
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
