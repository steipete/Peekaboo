---
summary: 'Start, stop, and inspect the headless Peekaboo daemon'
read_when:
  - 'managing the Peekaboo daemon lifecycle'
  - 'checking daemon health, permissions, or tracker status'
---

# peekaboo daemon

Manage the on-demand headless daemon that keeps Peekaboo state warm, tracks windows live, and serves bridge requests.

## Commands

### Start
```
peekaboo daemon start
```
Options:
- `--bridge-socket <path>` override the default bridge socket path.
- `--poll-interval-ms <ms>` window tracker poll interval (default 1000ms).
- `--wait-seconds <sec>` how long to wait for startup (default 3s).

### Status
```
peekaboo daemon status
```
Shows:
- running state + PID
- bridge socket + host kind
- activity state (active requests, last activity, idle timeout/deadline)
- permissions (screen recording / accessibility / automation)
- snapshot cache summary
- window tracker stats (tracked windows, last event, polling)
- browser MCP state (connected, tool count, detected Chrome count)

### Stop
```
peekaboo daemon stop
```
Options:
- `--bridge-socket <path>` override the default bridge socket path.
- `--wait-seconds <sec>` how long to wait for shutdown (default 3s).

## Notes
- Normal automation commands auto-start the daemon in `auto` mode when the default daemon socket is unavailable.
- Auto-started daemons exit after an idle timeout (default 300 seconds), while explicit `peekaboo daemon start` remains manual and stays up until stopped.
- The daemon uses an in-memory snapshot store for speed.
- Set `PEEKABOO_DAEMON_IDLE_TIMEOUT_SECONDS` to tune the auto-start idle timeout.
- Set `PEEKABOO_DAEMON_SOCKET` to override the auto-start daemon socket for testing.
- For local development with unsigned binaries, set `PEEKABOO_ALLOW_UNSIGNED_SOCKET_CLIENTS=1`.
