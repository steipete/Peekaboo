---
summary: 'Position the cursor via peekaboo move'
read_when:
  - 'hovering elements without clicking'
  - 'lining up the pointer before a screenshot or drag sequence'
---

# `peekaboo move`

`move` repositions the macOS cursor using coordinate targets, element IDs, fuzzy queries, or a simple “center of screen” flag. It’s useful for hover-driven menus, tooltips, or aligning the cursor before taking a screenshot.

## Key options
| Flag | Description |
| --- | --- |
| `[x,y]` | Optional positional coordinates (e.g., `540,320`). |
| `--id <element-id>` | Jump to a Peekaboo element’s midpoint based on the latest session. |
| `--to <query>` | Resolve an element by text/query using `waitForElement` (5 s timeout). |
| `--center` | Ignore other targets and move to the main screen’s center. |
| `--session <id>` | Required when using `--id`/`--to`; defaults to the most recent session. |
| `--smooth` | Animate the move over multiple steps (defaults to 500 ms, 20 steps). |
| `--duration <ms>` / `--steps <n>` | Override the smooth-move timing/step count; instant moves use duration `0` unless overridden. |

## Implementation notes
- Validation enforces “pick something”: coordinates, `--id`, `--to`, or `--center`. Mixed inputs (e.g., coordinates + `--center`) are rejected before any cursor movement.
- Element-based moves reuse session data via `services.sessions.getDetectionResult`; query-based moves run `AutomationServiceBridge.waitForElement`, so they automatically wait up to 5 s for dynamic UIs.
- Smooth moves compute intermediate steps client-side and track the previous cursor location so the result payload can include the travel distance.
- JSON output reports `fromLocation`, `targetLocation`, `targetDescription`, total distance, and run time—handy when you need to assert that the pointer actually moved.

## Examples
```bash
# Instantly move to a coordinate
polter peekaboo -- move 1024,88

# Hover the element with ID `menu_gear` using the latest session
polter peekaboo -- move --id menu_gear --smooth

# Center the cursor on the main display before taking a screenshot
polter peekaboo -- move --center --duration 250 --steps 15
```
