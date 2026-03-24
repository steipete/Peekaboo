---
summary: 'Diagnose Peekaboo Bridge host connectivity via peekaboo bridge'
---

# `peekaboo bridge`

`peekaboo bridge` reports how the CLI resolves a Peekaboo Bridge host.

## Subcommands

| Name | Purpose |
| --- | --- |
| `status` (default) | Probes socket paths, attempts Bridge handshake, reports which host would be selected. |

## Notes

- Host discovery order is documented in `docs/bridge-host.md`.
- `--no-remote` skips remote probing and forces local execution.
- `--bridge-socket <path>` overrides host discovery and probes only that socket.

## Examples

```bash
# Human-readable status
peekaboo bridge status

# Full probe results + structured output
peekaboo bridge status --verbose --json-output | jq '.data'

# Probe a specific socket
peekaboo bridge status --bridge-socket ~/Library/Application\ Support/clawdbot/bridge.sock
```
