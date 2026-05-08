---
summary: 'Simulate mouse wheel movement via peekaboo scroll'
read_when:
  - 'panning long views or tables without dragging the scrollbar'
  - 'needing scroll result details (direction, ticks) for automation logs'
---

# `peekaboo scroll`

`scroll` emulates trackpad/mouse-wheel input in any direction. You can scroll at the pointer position or aim at a previously captured element ID so the automation service scrolls that region even if the cursor is elsewhere.

## Key options
| Flag | Description |
| --- | --- |
| `--direction up|down|left|right` | Required. Case-insensitive and validated before execution. |
| `--amount <ticks>` | Number of scroll “ticks” (default `3`). Smooth mode multiplies this internally. |
| `--on <element-id>` | Scroll relative to a Peekaboo element from the current/most recent snapshot. |
| `--snapshot <id>` | Override the snapshot used to resolve `--on`. Omit when you want to scroll wherever the pointer is. |
| `--delay <ms>` | Milliseconds between ticks (default `2`). |
| `--smooth` | Use smaller increments (10 micro ticks per requested tick) for finer movement. |
| Target flags | `--app <name>`, `--pid <pid>`, `--window-id <id>`, `--window-title <title>`, `--window-index <n>` — focus a specific app/window before scrolling. (`--window-title`/`--window-index` require `--app` or `--pid`; `--window-id` does not.) |
| Focus flags | `FocusCommandOptions` control Space switching + retries. |

## Implementation notes
- If you pass `--on` without a snapshot, the command automatically looks up `services.snapshots.getMostRecentSnapshot()` so you rarely need to wire IDs manually.
- Focus is handled via `ensureFocused`; supplying a target helps the command recover when the scrollable view lives in a background Space.
- JSON output reports the actual point that was scrolled: for element targets it resolves the bounds midpoint, applies moved-window adjustment when possible, and includes `targetPoint` diagnostics with the original snapshot midpoint, final resolved point, snapshot ID, and adjustment status. Coordinate-less scrolls sample the current cursor location via `CGEvent(source:nil)?.location`.
- `ScrollRequest` is handed directly to `AutomationServiceBridge.scroll`, so the CLI benefits from the same smooth/step semantics the agent runtime sees.

## Examples
```bash
# Scroll down five ticks wherever the pointer currently sits
peekaboo scroll --direction down --amount 5

# Scroll the element labeled "table_orders" using the latest snapshot
peekaboo scroll --direction up --amount 2 --on table_orders

# Smooth horizontal pan inside Keynote without switching Spaces
peekaboo scroll --direction right --smooth --app Keynote --space-switch
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json` or `--verbose` to surface detailed errors.
