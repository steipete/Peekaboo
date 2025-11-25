---
summary: 'Inspect native + MCP tooling via peekaboo tools'
read_when:
  - 'deciding which automation tool to call from agents or scripts'
  - 'debugging missing MCP servers or tool registrations'
---

# `peekaboo tools`

`peekaboo tools` prints the authoritative tool catalog that the CLI, Peekaboo.app, and MCP server expose. The command hydrates the native tool set (Image, See, Click, Window, etc.) and then asks `TachikomaMCPClientManager` for any connected servers, so you can audit everything an agent will see without attaching a debugger.

## Key options
| Flag | Description |
| --- | --- |
| `--native-only` / `--mcp-only` | Filter the list to built-in tools or remote MCP servers respectively. |
| `--mcp <server>` | Show tools from a single server ID (matches the IDs in `peekaboo mcp list`). |
| `--include-disabled` | Keep disabled MCP servers in the JSON/text output instead of silently skipping them. |
| `--group-by-server` | Nest external tools under their server heading even in text mode. |
| `--no-sort` | Preserve registration order instead of alphabetizing every tool. |
| `--json-output` | Emit `{native:[], external:[{server,tools:[]}], summary:{…}}` for machine parsing.

## Implementation notes
- The command instantiates every native `MCPTool` manually (ImageTool, ClickTool, DialogTool, etc.), registers them into `MCPToolRegistry`, then awaits dynamic registration from `TachikomaMCPClientManager.shared` so you see the same merged list the agent runtime will use.
- Display formatting is handled by `ToolDisplayOptions`; when `--group-by-server` is set it switches to server-prefixed labels, while JSON mode serializes each tool’s `.name`, `.description`, and source.
- Filtering happens before formatting (`ToolOrganizer.filter` + `.sort`), so expensive grouping/sorting only touches the subset you asked for.
- Because the command implements `RuntimeOptionsConfigurable`, it respects global `--json-output`/`--verbose` flags even when invoked from other commands (e.g., `peekaboo learn` can embed the summaries verbatim).

## Examples
```bash
# Quick native-only audit
polter peekaboo -- tools --native-only

# See which MCP servers are registered and what they expose
polter peekaboo -- tools --mcp-only --group-by-server

# Produce a JSON blob for an agent integration test
polter peekaboo -- tools --json-output > /tmp/tools.json
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
