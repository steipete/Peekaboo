# Model Context Protocol (MCP) in Peekaboo

This document explains how Peekaboo integrates external MCP servers through TachikomaMCP, and how to configure and test transports (stdio, HTTP, SSE) from the CLI.

## Overview

Peekaboo can consume tools exposed by any MCP-compatible server. We currently support three transport modes via TachikomaMCP:

- stdio: spawn a local process and talk over stdio using MCP framing
- http (streamable HTTP): single HTTP endpoint for request/response streaming
- sse (Server-Sent Events): GET establishes a read stream; write requests are POSTed as JSON-RPC

All transports converge to a single client that performs:
- initialize → notifications/initialized → tools/list → tools/call
- Strict per-request timeout (defaults 10s from the CLI; probe honors it)

## CLI usage

List high-level help:

```
peekaboo mcp --help
```

Add an MCP server (stdio example):

```
peekaboo mcp add files -- npx -y @modelcontextprotocol/server-filesystem /Users/me/docs
```

Add an MCP server (SSE example) with headers:

```
peekaboo mcp add my-sse --transport sse \
  --header "Authorization=Bearer $TOKEN" \
  --timeout 10 -- https://example.com/mcp/sse
```

Arguments after `--` fill `command` and optional `args`. For SSE, `command` is the URL.

Test the connection (respects `--timeout`):

```
peekaboo mcp test my-sse
```

List configured servers and health:

```
peekaboo mcp list
```

## Configuration model

Entries are persisted to the user profile config (JSON) under `mcpClients`. Effective config keys are:

- transport: "stdio" | "http" | "sse"
- command: for stdio: executable; for http/sse: URL
- args: array (stdio only)
- env: map of environment variables (stdio)
- headers: map of HTTP headers (http/sse)
- enabled: boolean
- timeout: seconds for request timeouts and connection probing
- autoReconnect: boolean
- description: optional string

Example (SSE):

```json
{
  "mcpClients": {
    "context7-url": {
      "transport": "sse",
      "command": "https://api.context7.com/mcp/sse",
      "headers": { "Authorization": "Bearer ${CONTEXT7_API_KEY}" },
      "enabled": true,
      "timeout": 10
    }
  }
}
```

Environment variables in the JSON are expanded at load time (e.g. `${CONTEXT7_API_KEY}`).

## SSE transport specifics

- Read channel: HTTP GET to `command` URL with header `Accept: text/event-stream`.
- Write channel: JSON-RPC requests are POSTed with `Content-Type: application/json`.
- Endpoint discovery:
  - If the server emits an SSE event `endpoint` with a URL (relative or absolute), we POST writes there.
  - Fallback: if no `endpoint` is seen, we POST to the same URL as the SSE stream (the `command` URL).
- Headers: any `--header Key=Value` pairs you pass at `mcp add` are forwarded on both the GET (read) and POST (write) requests.
- Timeouts: per-request timeout is enforced by the client; CLI defaults to 10 seconds.

Known server behaviors:
- Some servers accept POST to the same SSE URL.
- Some emit an SSE `endpoint` event to specify a separate write URL.
- If a server responds HTTP 405 to POST on the SSE URL and does not emit an `endpoint` event, the client cannot complete initialize; in that case, consult the server documentation for its write URL expectations.

## Troubleshooting

- initialize times out after ~10s:
  - Check that the Authorization or other required headers are provided (`--header`).
  - Verify the server supports POST on the SSE URL or emits an `endpoint` event; otherwise writes cannot be delivered.
  - Confirm the server speaks the MCP initialize method (`initialize`) with protocolVersion `2025-03-26` or `2024-11-05`.
- HTTP 405 on POST:
  - Indicates the write path is not permitted for POST. The server either expects a different route or a discovery event for a write endpoint.

## Roadmap / Improvements

- Optional CLI flag for an explicit write URL when using SSE (e.g. `--write-url`), to support servers that separate read and write paths without emitting discovery events.
- Auto-detection heuristics based on common SSE route patterns.
- Doc examples for popular public MCP servers.
