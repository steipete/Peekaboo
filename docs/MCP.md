# Model Context Protocol (MCP) in Peekaboo

This document explains how Peekaboo integrates external MCP servers through TachikomaMCP, and how to configure and test transports (stdio, HTTP, SSE) from the CLI.

## Overview

Peekaboo can consume tools exposed by any MCP-compatible server. We currently support three transport modes via TachikomaMCP:

- stdio: spawn a local process and talk over stdio using MCP framing
- http (streamable HTTP): single HTTP endpoint for request/response streaming
- sse (Server-Sent Events): single URL; GET establishes a read stream and the same URL accepts POST JSON-RPC writes

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

- Single URL model: the same URL is used for both the read stream (GET with `Accept: text/event-stream`) and the write channel (POST JSON-RPC with `Content-Type: application/json`).
- Headers: any `--header Key=Value` pairs you pass at `mcp add` are applied to both the GET (read) and POST (write) requests.
- Endpoint event: servers may optionally emit an `endpoint` SSE event containing a string URL or a JSON object like `{ "url": "/rpc" }`. We accept either form, resolved relative to the base URL. If not emitted, we continue using the same URL.
- Timeouts: per-request timeout is enforced by the client; CLI defaults to 10 seconds.

## Troubleshooting

- initialize times out after ~10s:
  - Check that Authorization or other required headers are provided (`--header`).
  - Confirm the server supports POST on the SSE URL and speaks MCP `initialize`.

## Notes

- Peekaboo’s SSE client now forwards custom headers on the GET request in addition to POST.
- The `endpoint` event is accepted as either a string or a JSON object with `url`/`endpoint`.
