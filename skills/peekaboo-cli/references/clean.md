---
summary: 'Prune snapshot caches via peekaboo clean'
---

# `peekaboo clean`

`clean` removes entries from `~/.peekaboo/snapshots/` by age, by ID, or wholesale.

## Modes

| Flag | Effect |
| --- | --- |
| `--all-snapshots` | Delete every cached snapshot directory. |
| `--older-than <hours>` | Delete snapshots older than the given threshold (default 24). |
| `--snapshot <id>` | Remove a single snapshot by folder name. |
| `--dry-run` | Print what would be removed without touching disk. |

## Examples

```bash
# Preview what would be deleted
peekaboo clean --older-than 12 --dry-run

# Remove a specific snapshot
SNAPSHOT=$(peekaboo see --json-output | jq -r '.data.snapshot_id')
peekaboo clean --snapshot "$SNAPSHOT"

# Delete all snapshots
peekaboo clean --all-snapshots
```
