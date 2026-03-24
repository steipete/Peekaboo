---
summary: 'Insert millisecond delays via peekaboo sleep'
---

# `peekaboo sleep`

`sleep` pauses the CLI for a fixed duration (milliseconds).

## Usage

| Argument | Description |
| --- | --- |
| `<duration>` | Positive integer in milliseconds. |

## Examples

```bash
# Sleep 1.5 seconds
peekaboo sleep 1500

# Guard a flaky UI transition
peekaboo click "Open" && peekaboo sleep 750
```
