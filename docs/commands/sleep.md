---
summary: 'Insert millisecond delays via peekaboo sleep'
read_when:
  - 'throttling CLI scripts between UI actions'
  - 'forcing agents to wait for animations without adding custom loops'
---

# `peekaboo sleep`

`sleep` pauses the CLI for a fixed duration (milliseconds). It is the simplest way to add breathing room between scripted steps or to wait for macOS animations when you can’t rely on an element becoming available yet.

## Usage
| Argument | Description |
| --- | --- |
| `<duration>` | Positive integer in milliseconds. Global `--json-output` works as usual. |

## Implementation notes
- Durations ≤0 trigger a validation error before any waiting occurs.
- The command uses `Task.sleep` with millisecond → nanosecond conversion, so it respects cancellation if the surrounding script aborts.
- After waking it reports both the requested and actual duration (rounded) so you can spot scheduler hiccups when running under load.

## Examples
```bash
# Sleep 1.5 seconds
polter peekaboo -- sleep 1500

# Guard a flaky UI transition inside a script
polter peekaboo -- run flow.peekaboo.json --no-fail-fast \
  && polter peekaboo -- sleep 750 \
  && polter peekaboo -- click "Open"
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
