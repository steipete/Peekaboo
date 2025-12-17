---
summary: 'Target UI elements via peekaboo click'
read_when:
  - 'building deterministic element interactions after running `see`'
  - 'debugging focus/snapshot issues for click automation'
---

# `peekaboo click`

`click` is the primary interaction command. It accepts element IDs, fuzzy text queries, or literal coordinates and then drives `AutomationServiceBridge.click` with built-in focus handling and wait logic.

## Key options
| Flag | Description |
| --- | --- |
| `[query]` | Optional positional text query (case-insensitive substring match). |
| `--on <id>` / `--id <id>` | Target a specific Peekaboo element ID (e.g., `B1`, `T2`). |
| `--coords x,y` | Click exact coordinates without touching the snapshot cache. |
| `--snapshot <id>` | Reuse a prior snapshot; defaults to `services.snapshots.getMostRecentSnapshot()` when omitted. |
| `--app <name>` | Force a specific app focus before clicking (in addition to whatever snapshot resolves). |
| `--wait-for <ms>` | Millisecond timeout while waiting for the element to appear (default 5000). |
| `--double` / `--right` | Perform double-click or secondary-click instead of the default single click. |
| Focus flags | `--no-auto-focus`, `--focus-timeout-seconds`, `--focus-retry-count`, `--space-switch`, `--bring-to-current-space` (see `FocusCommandOptions`). |

## Implementation notes
- Validation makes sure you only provide one targeting strategy (ID/query vs. `--coords`) and that coordinate strings parse cleanly into doubles.
- When no `--snapshot` is provided, the command grabs the most recent snapshot ID (if any) before waiting for elements. Coordinate clicks skip snapshot usage entirely to avoid stale caches.
- Element-based clicks call `AutomationServiceBridge.waitForElement` with the supplied timeout so you don’t have to insert manual sleeps. Helpful hints are printed when timeouts expire.
- Focus is enforced just before the click by `ensureFocused`; by default it will hop Spaces if necessary unless you pass `--no-auto-focus`.
- JSON output reports `clickedElement`, the resolved coordinates, wait time, execution time, and the frontmost app after the click.

## Examples
```bash
# Click the "Send" button (ID from a previous `see` run)
polter peekaboo -- click --on B12

# Fuzzy search + extra wait for a slow dialog
polter peekaboo -- click "Allow" --wait-for 8000 --space-switch

# Issue a right-click at raw coordinates
polter peekaboo -- click --coords 1024,88 --right --no-auto-focus
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- If you see `SNAPSHOT_NOT_FOUND`, regenerate the snapshot with `peekaboo see` (or omit `--snapshot` to use the most recent one). Cleaned/expired snapshots cannot be reused.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
