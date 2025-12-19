---
summary: 'Plan for a headless Peekaboo daemon with live window tracking and MCP integration'
read_when:
  - 'planning or implementing the Peekaboo daemon lifecycle'
  - 'adding live window tracking or daemon status reporting'
  - 'wiring MCP to run in daemon mode'
---

# Peekaboo Daemon Plan

## Goals
- Provide a headless daemon with explicit lifecycle commands:
  - `peekaboo daemon start`
  - `peekaboo daemon stop`
  - `peekaboo daemon status`
- When running as MCP (`peekaboo mcp`), automatically enter daemon mode:
  - In-memory snapshot store
  - Live window tracking
  - Enhanced observability
- Improve accuracy and speed via cached state + event-driven updates.

## Non-goals (initially)
- No GUI or menu bar UI for the daemon.
- No launchd agent/daemon integration.
- No external network listeners beyond MCP’s stdio transport (HTTP/SSE still out of scope).

## User Experience
### Commands
- `peekaboo daemon start`
  - Starts a headless daemon **from the same `peekaboo` binary** (on-demand).
  - Ensures bridge socket is up and window tracking is active.
- `peekaboo daemon stop`
  - Gracefully shuts down the daemon.
  - Cleans up observers and sockets.
- `peekaboo daemon status`
  - Reports:
    - Running state + PID
    - Bridge socket path + handshake
    - Permissions (Screen Recording, Accessibility)
    - Snapshot cache stats (count, last access)
    - Window tracker stats (tracked windows, last event timestamp)
    - MCP mode indicator (if daemon was launched by MCP)

### Output format
- Human-readable by default, `--json` supported (same style as `bridge status`).

## Architecture
### High-level
```
CLI (peekaboo) ─┐
                ├── Daemon Controller ──> Headless Daemon Host
MCP (stdio)  ───┘                             │
                                              ├─ PeekabooServices (InMemorySnapshotManager)
                                              ├─ WindowTrackerService (AX + CG fallback)
                                              ├─ Bridge Host (socket)
                                              └─ Observability / Metrics
```

### New components
- **DaemonHost** (new headless executable)
  - Owns a long-lived `PeekabooServices(snapshotManager: InMemorySnapshotManager())`.
  - Starts Bridge host listener and WindowTrackerService.
  - Exposes a local control channel for stop/status.

- **WindowTrackerService** (new service, likely in `PeekabooAutomationKit`)
  - Uses AX notifications (`AXWindowCreated`, `AXWindowMoved`, `AXWindowResized`, etc.).
  - Maintains an in-memory registry keyed by `CGWindowID` + AX identifier.
  - Periodic CGWindowList diff for resilience (apps that don’t emit AX events).

- **SnapshotInvalidation** (new logic in snapshot manager or automation layer)
  - When a tracked window moves/resizes, mark snapshot stale or update bounds.
  - On interaction, re-verify window position before clicking/typing.

### MCP auto-daemon
- When `peekaboo mcp` starts, it **always runs in daemon mode**:
  - InMemorySnapshotManager
  - WindowTrackerService enabled
  - Observability enabled
- No separate background process required; the MCP server process *is* the daemon.

## Placement
- Single entry point: `peekaboo` runs in **daemon mode** when requested.
- On-demand only; no launchd agent.

## Status/Observability Fields
- `daemon.running` (bool)
- `daemon.pid`
- `daemon.startedAt`
- `daemon.mode` (manual|mcp)
- `bridge.socketPath`
- `bridge.handshake` (hostKind, ops, version)
- `permissions.screenRecording`
- `permissions.accessibility`
- `snapshots.count`
- `snapshots.lastAccessedAt`
- `tracker.trackedWindows`
- `tracker.lastEventAt`
- `tracker.axObservers`
- `tracker.cgPollIntervalMs`

## Implementation Phases
1) **Daemon scaffolding**
   - Create headless executable target.
   - Add `peekaboo daemon start|stop|status` commands.
   - Implement local control channel (Unix socket or pidfile + health probe).

2) **Daemon mode services**
   - Add `DaemonServices` initializer using InMemorySnapshotManager.
   - Ensure Bridge host runs inside daemon.

3) **WindowTrackerService**
   - AX observer subscriptions + CGWindowList polling fallback.
   - Registry API: list tracked windows, last event, etc.

4) **Snapshot invalidation + focus verification**
   - Integrate with click/type/focus paths.
   - Prefer re-verify bounds when window moved.

5) **MCP integration**
   - When `peekaboo mcp` starts, enable daemon mode and tracker.

6) **Telemetry + tests**
   - Unit tests for tracker diffing.
   - CLI status snapshot tests.
   - MCP server smoke test in daemon mode.

## Build/Run
- CLI:
  - `pnpm run build:cli`
- Daemon (headless target):
  - `pnpm run build:swift` (add a dedicated script if needed)
- Status:
  - `peekaboo daemon status --json`

## Open Questions
- Should daemon auto-install a launchd agent, or only run on-demand?
- Do we want `peekaboo mcp` to spawn a separate daemon or just run in-process (current plan)?
- How aggressive should CGWindowList polling be when AX notifications are quiet?
