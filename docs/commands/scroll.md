---
summary: 'Simulate mouse wheel movement via peekaboo scroll'
read_when:
  - 'panning long views or tables without dragging the scrollbar'
  - 'needing scroll telemetry (direction, ticks) for automation logs'
---

# `peekaboo scroll`

`scroll` emulates trackpad/mouse-wheel input in any direction. You can scroll at the pointer position or aim at a previously captured element ID so the automation service scrolls that region even if the cursor is elsewhere.

## Key options
| Flag | Description |
| --- | --- |
| `--direction up|down|left|right` | Required. Case-insensitive and validated before execution. |
| `--amount <ticks>` | Number of scroll “ticks” (default `3`). Smooth mode multiplies this internally. |
| `--on <element-id>` | Scroll relative to a Peekaboo element from the current/most recent session. |
| `--session <id>` | Override the session used to resolve `--on`. Omit when you want to scroll wherever the pointer is. |
| `--delay <ms>` | Milliseconds between ticks (default `2`). |
| `--smooth` | Use smaller increments (3 micro ticks per requested tick) for finer movement. |
| `--app <name>` + focus flags | Force a specific app/window focus before scrolling, using `FocusCommandOptions`. |

## Implementation notes
- If you pass `--on` without a session, the command automatically looks up `services.sessions.getMostRecentSession()` so you rarely need to wire IDs manually.
- Focus is handled via `ensureFocused` even when `--on` is omitted; supplying `--app` helps the command recover when the scrollable view lives in a background Space.
- JSON output reports the actual point that was scrolled: for element targets it resolves the bounds midpoint, otherwise it samples the current cursor location via `CGEvent(source:nil)?.location`.
- `ScrollRequest` is handed directly to `AutomationServiceBridge.scroll`, so the CLI benefits from the same smooth/step semantics the agent runtime sees.

## Examples
```bash
# Scroll down five ticks wherever the pointer currently sits
polter peekaboo -- scroll --direction down --amount 5

# Scroll the element labeled "table_orders" using the latest session
polter peekaboo -- scroll --direction up --amount 2 --on table_orders

# Smooth horizontal pan inside Keynote without switching Spaces
polter peekaboo -- scroll --direction right --smooth --app Keynote --space-switch
```
