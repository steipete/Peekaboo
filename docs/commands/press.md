---
summary: 'Send special keys or sequences via peekaboo press'
read_when:
  - 'navigating dialogs with arrow/tab/return patterns'
  - 'debugging scripted key sequences that need deterministic timing'
---

# `peekaboo press`

`press` fires individual `SpecialKey` values (Return, Tab, arrows, F-keys, etc.) in sequence. It routes through the same `TypeActionsRequest` stack as `type`, so focus handling and snapshot reuse behave the same way.

## Key options
| Flag | Description |
| --- | --- |
| `[keys…]` | Positional list of keys (`return`, `tab`, `up`, `f1`, `forward_delete`, …). Validation rejects unknown tokens. |
| `--count <n>` | Repeat the entire key sequence `n` times (default `1`). |
| `--delay <ms>` | Delay between key presses (default `100`). |
| `--hold <ms>` | Planned hold duration per key (currently stored but not yet wired to the automation layer). |
| `--snapshot <id>` | Use a specific snapshot; otherwise the last snapshot wins. |
| Focus flags | Same `FocusCommandOptions` bundle as `click`/`type`. |

## Implementation notes
- Keys are lowercased and mapped to `SpecialKey`; the command fails fast with a helpful message if a token isn’t recognized.
- The focus helper only runs when a snapshot ID is available, so for “blind” global shortcuts you can omit `--snapshot` entirely.
- Repetition multiplies the sequence client-side—e.g., `press tab return --count 3` becomes six actions—so you get predictable ordering.
- Results include the literal key list, total presses, repeat count, and elapsed time in both text and JSON modes.
- The `--hold` flag is parsed and stored for future use but does not change behavior yet; include manual sleeps if you need long key holds.

## Examples
```bash
# Equivalent to hitting Return once
polter peekaboo -- press return

# Tab through a menu twice, then confirm
polter peekaboo -- press tab tab return

# Walk a dialog down three rows with headroom between repetitions
polter peekaboo -- press down --count 3 --delay 200
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
