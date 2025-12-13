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
| `--id <element-id>` | Jump to a Peekaboo element’s midpoint based on the latest snapshot. |
| `--to <query>` | Resolve an element by text/query using `waitForElement` (5 s timeout). |
| `--center` | Ignore other targets and move to the main screen’s center. |
| `--snapshot <id>` | Required when using `--id`/`--to`; defaults to the most recent snapshot. |
| `--smooth` | Animate the move over multiple steps (defaults to 500 ms, 20 steps). |
| `--duration <ms>` / `--steps <n>` | Override the smooth-move timing/step count; instant moves use duration `0` unless overridden. |
| `--profile <linear\|human>` | Select a movement profile. `human` enables eased arcs and micro-jitter with no extra tuning required. |

## Implementation notes
- Validation enforces “pick something”: coordinates, `--id`, `--to`, or `--center`. Mixed inputs (e.g., coordinates + `--center`) are rejected before any cursor movement.
- Element-based moves reuse snapshot data via `services.snapshots.getDetectionResult`; query-based moves run `AutomationServiceBridge.waitForElement`, so they automatically wait up to 5 s for dynamic UIs.
- Smooth moves compute intermediate steps client-side and track the previous cursor location so the result payload can include the travel distance.
- `--profile human` automatically enables smooth movement, adapts duration/steps to travel distance, and adds natural jitter/overshoot. See `docs/human-mouse-move.md` for deeper guidance.
- JSON output reports `fromLocation`, `targetLocation`, `targetDescription`, total distance, and run time—handy when you need to assert that the pointer actually moved.

## Examples
```bash
# Instantly move to a coordinate
polter peekaboo -- move 1024,88

# Human-style movement with one flag
polter peekaboo -- move 520,360 --profile human

# Hover the element with ID `menu_gear` using the latest snapshot
polter peekaboo -- move --id menu_gear --smooth

# Center the cursor on the main display before taking a screenshot
polter peekaboo -- move --center --duration 250 --steps 15
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
