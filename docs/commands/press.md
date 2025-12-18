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
| `--snapshot <id>` | Optional snapshot ID used for validation/focus (no implicit “latest snapshot” lookup). |
| Target flags | `--app <name>`, `--pid <pid>`, `--window-title <title>`, `--window-index <n>` — focus a specific app/window before pressing keys. (`--window-*` requires `--app` or `--pid`.) |
| Focus flags | Same `FocusCommandOptions` bundle as `click`/`type`. |

## Implementation notes
- Keys are lowercased and mapped to `SpecialKey`; the command fails fast with a helpful message if a token isn’t recognized.
- Focus runs when `--snapshot` or the target flags are present; for “blind” global shortcuts you can omit both and let the current frontmost app receive the keys.
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
- If you see `SNAPSHOT_NOT_FOUND`, regenerate the snapshot with `peekaboo see` (or omit `--snapshot` to use the most recent one).
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
