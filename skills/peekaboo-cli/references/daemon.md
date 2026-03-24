---
summary: 'Start, stop, and inspect the headless Peekaboo daemon'
---

# `peekaboo daemon`

Manage the on-demand headless daemon that keeps Peekaboo state warm.

## Commands

| Command | Description |
| --- | --- |
| `start` | Start the daemon. `--bridge-socket`, `--poll-interval-ms`, `--wait-seconds`. |
| `status` | Shows running state, PID, bridge socket, permissions, snapshot cache, window tracker stats. |
| `stop` | Stop the daemon. `--bridge-socket`, `--wait-seconds`. |

## Examples

```bash
# Start the daemon
peekaboo daemon start

# Check status
peekaboo daemon status

# Stop the daemon
peekaboo daemon stop
```
