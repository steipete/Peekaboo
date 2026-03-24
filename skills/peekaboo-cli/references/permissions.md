---
summary: 'Check or explain required macOS permissions via peekaboo permissions'
---

# `peekaboo permissions`

`peekaboo permissions` centralizes entitlement checks.

## Subcommands

| Name | Purpose |
| --- | --- |
| `status` (default) | Reports Screen Recording, Accessibility, Full Disk Access status. |
| `grant` | Prints human-readable steps to fix missing entitlements. |

## Examples

```bash
# Quick sanity check
peekaboo permissions status

# Get remediation steps
peekaboo permissions grant

# JSON output for agents
peekaboo permissions --json-output | jq '.data[] | select(.status != "granted")'
```
