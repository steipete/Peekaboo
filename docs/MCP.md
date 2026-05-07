---
summary: 'Review Model Context Protocol (MCP) in Peekaboo guidance'
read_when:
  - 'planning work related to model context protocol (mcp) in peekaboo'
  - 'debugging or extending features described here'
---

# Model Context Protocol (MCP) in Peekaboo

This document explains how Peekaboo exposes its automation tools as an MCP server and how to start it from the CLI.

## Overview

Peekaboo runs as an MCP server over stdio, exposing its native tools (image, see, click, etc.) to external MCP clients such as Claude Desktop or Cursor.
Peekaboo no longer hosts or manages external MCP servers; configure your MCP client to launch `peekaboo mcp` directly.

Supported transports:
- **stdio**: supported and default.
- **http / sse**: recognized flags, but server transports are not implemented yet.

## CLI usage

Show help:

```
peekaboo mcp --help
```

Start the server (defaults to stdio):

```
peekaboo mcp
```

Explicit transport:

```
peekaboo mcp serve --transport stdio
```

## Observation Targets

The MCP `image` and `see` tools share target parsing with the desktop observation pipeline:

- omit `app_target`, pass `screen`, or pass `screen:N` for display capture;
- pass `frontmost` for the current foreground app window;
- pass `menubar` for menu-bar capture;
- pass `PID:1234`, `PID:1234:2`, `App Name`, `App Name:2`, or `App Name:Window Title` for app/window capture.

The MCP `image` tool stores logical 1x captures by default. Pass `scale: "native"` or `retina: true` to request native display pixels.

## Troubleshooting

- Ensure Screen Recording + Accessibility permissions are granted (`peekaboo permissions status`).
- If the MCP client cannot connect, confirm you are launching Peekaboo with `mcp` or `mcp serve` and that the client is using stdio transport.
