---
summary: 'Diagnose Peekaboo Bridge host connectivity via peekaboo bridge'
read_when:
  - 'verifying whether the CLI is using Peekaboo.app / Clawdbot.app as a Bridge host'
  - 'debugging codesign / TeamID failures for bridge.sock connections'
  - 'checking which socket path Peekaboo is probing'
---

# `peekaboo bridge`

`peekaboo bridge` reports how the CLI resolves a Peekaboo Bridge host (the socket-based TCC broker used for Screen Recording / Accessibility / AppleScript operations).

## Subcommands
| Name | Purpose |
| --- | --- |
| `status` (default) | Probes the configured socket paths, attempts a Bridge handshake, and reports which host would be selected (or if Peekaboo will fall back to local in-process execution). |

## Notes
- Host discovery order is documented in `docs/bridge-host.md`.
- `--no-remote` (or `PEEKABOO_NO_REMOTE`) skips remote probing and forces local execution.
- `--bridge-socket <path>` (or `PEEKABOO_BRIDGE_SOCKET`) overrides host discovery and probes only that socket.
- Hosts validate callers by code signature TeamID. If the host rejects the client (`unauthorizedClient`), install a signed Peekaboo CLI build or enable the debug-only escape hatch on the host.
- If `bridge status` reports `internalError` / “Bridge host returned no response”, the probed host likely closed the socket without replying (older host builds). Hosts built from `main` after 2025-12-18 return a structured `unauthorizedClient` error instead, which is much easier to debug.

## Examples
```bash
# Human-readable status (selected host only)
polter peekaboo -- bridge status

# Full probe results + structured output for agents
polter peekaboo -- bridge status --verbose --json-output | jq '.data'

# Probe a specific host socket path
polter peekaboo -- bridge status --bridge-socket \
  ~/Library/Application\ Support/clawdbot/bridge.sock

# Probe Claude Desktop host socket path (if Claude.app hosts PeekabooBridge)
polter peekaboo -- bridge status --bridge-socket \
  ~/Library/Application\ Support/Claude/bridge.sock

# Force local (skip Peekaboo.app / Clawdbot.app hosts)
polter peekaboo -- bridge status --no-remote
```
