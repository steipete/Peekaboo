---
summary: 'Target UI elements via peekaboo click'
---

# `peekaboo click`

`click` is the primary interaction command. It accepts element IDs, fuzzy text queries, or literal coordinates and then drives automation with built-in focus handling and wait logic.

## Key options

| Flag | Description |
| --- | --- |
| `[query]` | Optional positional text query (case-insensitive substring match). |
| `--on <id>` / `--id <id>` | Target a specific Peekaboo element ID (e.g., `B1`, `T2`). |
| `--coords x,y` | Click exact coordinates without touching the snapshot cache. |
| `--snapshot <id>` | Reuse a prior snapshot. |
| `--wait-for <ms>` | Millisecond timeout while waiting for the element to appear (default 5000). |
| `--double` / `--right` | Perform double-click or secondary-click. |

## Examples

```bash
# Click the "Send" button (ID from a previous `see` run)
peekaboo click --on B12

# Fuzzy search + extra wait for a slow dialog
peekaboo click "Allow" --wait-for 8000 --space-switch

# Issue a right-click at raw coordinates
peekaboo click --coords 1024,88 --right --no-auto-focus
```

## Troubleshooting

- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- If you see `SNAPSHOT_NOT_FOUND`, regenerate the snapshot with `peekaboo see`.
