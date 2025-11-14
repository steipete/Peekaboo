---
summary: 'Check or explain required macOS permissions via peekaboo permissions'
read_when:
  - 'verifying screen recording + accessibility entitlements before a run'
  - 'needing grant instructions for CI or remote machines'
---

# `peekaboo permissions`

`peekaboo permissions` centralizes entitlement checks. The default `status` subcommand reports the runtime view of Screen Recording, Accessibility, Full Disk Access, and any other guardrails the services expose. `grant` prints the same table plus human-readable steps so you can fix issues without hunting through docs.

## Subcommands
| Name | Purpose |
| --- | --- |
| `status` (default) | Fetches the current permission set via `PermissionHelpers.getCurrentPermissions` and prints each entry (`granted`, `denied`, etc.). Honors `--json-output` so agents can block proactively. |
| `grant` | Reuses the same snapshot but focuses on remediation: when in text mode it prints the exact System Settings pane/location for each missing entitlement. |

## Implementation notes
- Both subcommands conform to `RuntimeOptionsConfigurable`, so they inherit global `--json-output`/`--verbose` flags even when invoked from compound commands like `peekaboo learn`.
- The command executes entirely on the main actor, avoiding extra prompts or sandbox warnings—the same code path runs at CLI startup to warn if entitlements are missing.
- JSON mode uses `outputSuccessCodable`, which means you get a `{name, status, grantInstructions}` object for each permission and can diff the snapshots over time.

## Examples
```bash
# Quick sanity check before running UI automation
polter peekaboo -- permissions

# Feed the status into an agent to ensure entitlements are set
polter peekaboo -- permissions --json-output | jq '.data[] | select(.status != "granted")'

# Hand someone clear remediation steps
polter peekaboo -- permissions grant
```
