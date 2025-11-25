---
summary: 'Prune session caches via peekaboo clean'
read_when:
  - 'saving disk space or nuking stale session artifacts'
  - 'debugging interactions that still reference an old session ID'
---

# `peekaboo clean`

`clean` removes entries from `~/.peekaboo/session/` by age, by ID, or wholesale. Because every `see`/`click` pipeline streams screenshots and UI maps into that cache, it can grow quickly; this command is the supported way to prune it without deleting unrelated files.

## Modes
| Flag | Effect |
| --- | --- |
| `--all-sessions` | Delete every cached session directory. |
| `--older-than <hours>` | Delete sessions older than the given hour threshold (defaults to 24 if omitted). |
| `--session <id>` | Remove a single session by folder name (the `sessionId` from `see`). |
| `--dry-run` | Print what would be removed without touching disk. |

Only one of the three selection flags may be supplied at a time; the command validates this before doing any IO.

## Implementation notes
- Cleanup work is delegated to `services.files` (`cleanAllSessions`, `cleanOldSessions`, `cleanSpecificSession`), so it benefits from the same file-locking + sandbox awareness as the rest of Peekaboo.
- Text output summarizes number of sessions removed and bytes freed (using `ByteCountFormatter`), while JSON output wraps the raw `CleanResult` with an `executionTime` so you can log metrics.
- When `--session <id>` misses, the underlying `FileServiceError.sessionNotFound` is surfaced with actionable messaging instead of silently succeeding.

## Examples
```bash
# Preview what would be deleted without actually removing files
polter peekaboo -- clean --older-than 12 --dry-run

# Remove the session returned from the last `see` run
SESSION=$(polter peekaboo -- see --json-output | jq -r '.data.session_id')
polter peekaboo -- clean --session "$SESSION"
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
