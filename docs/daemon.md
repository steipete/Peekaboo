---
summary: 'Reference for Peekaboo daemon lifecycle, routing, sockets, and migration.'
read_when:
  - 'debugging reusable daemon startup, status, migration, or idle exit'
  - 'understanding CLI, GUI Bridge, and MCP runtime ownership'
---

# Peekaboo daemon

Peekaboo's reusable daemon keeps automation services, snapshots, window tracking, and browser MCP state warm across
separate CLI invocations. It runs from the same `peekaboo` binary and is managed with:

```bash
peekaboo daemon start
peekaboo daemon status
peekaboo daemon stop
```

## Runtime ownership

Each long-lived host has one distinct role and socket:

| Runtime | Socket | Lifecycle |
| --- | --- | --- |
| Reusable CLI daemon | `~/Library/Application Support/Peekaboo/daemon.sock` | Auto-started with idle exit, or manual until stopped. |
| Peekaboo.app Bridge | `~/Library/Application Support/Peekaboo/bridge.sock` | Owned by the GUI app and its TCC grants. |
| MCP server | stdio | Owned by the MCP client; no Bridge listener or published socket. |

Commands outside the exact-build preference below prefer the reusable daemon when it is healthy. If it is unavailable,
they use a healthy Peekaboo.app host with the required capability before auto-starting a daemon. If no remote host is
usable, the command falls back to process-local services when that operation permits it.

A command carrying a concrete `ps1_` snapshot reference bypasses that preference order. It uses the unique
authenticated producer across caller-local state and live daemon/GUI Bridge candidates, and refuses before dispatch
when no single host can prove ownership. Explicit `--bridge-socket` checks only that listener; `--no-remote` checks
only caller-local state. See [Bridge snapshot authority](bridge-host.md#snapshot-authority).

Implicit commands that require screen capture, inspect the AX tree, use browser MCP, or consume/invalidate snapshot
state first prefer the current CLI build's deterministic `daemon-<build>.sock`. They may auto-start that exact-build
daemon before considering an otherwise healthy Peekaboo.app host, because protocol compatibility alone does not make
build-sensitive in-memory state interchangeable. This preference does not apply to explicit Bridge paths, custom
daemon paths, application inventory or launch, or local-only execution.

An on-demand daemon reporting missing Screen Recording, Accessibility, or Event Synthesizing grants held by the
running Peekaboo.app host ranks after that app during implicit routing, unless the daemon also holds a grant the app
reports missing; unreported permissions keep the existing order. Snapshot-owned actions and lifecycle commands
requiring a surviving daemon are unaffected. Before auto-start, the same comparison uses the caller's non-interactive permission preflights to skip launching a weaker daemon when a capable Peekaboo.app host would win; unknown permissions retain the existing launch policy.

Exact-build preference keeps snapshot producers and invalidators on the same binary generation when possible, but is
not an affinity requirement: when the GUI is selected, its snapshot watermark is caught up before execution and the
normal mutation barrier invalidates the selected host and known sibling hosts, just as with daemon auto-start disabled.

The same build-scoped socket is the compatibility fallback when another build owns `daemon.sock` but lacks a required
capability. Native and Rosetta invocations of the same universal binary share it. Daemon status prefers the compatible
host and warns when another daemon also exists; explicit daemon start safely promotes a compatible auto fallback to
manual mode. After executable upgrades, implicit routing rediscovers compatible same-user fallback sockets and validates
their daemon identity before reuse. Explicit Bridge paths and custom daemon paths do not scan sibling sockets.

Explicit `--bridge-socket` or `PEEKABOO_BRIDGE_SOCKET` selects only that Bridge path and disables daemon auto-start.
`PEEKABOO_DAEMON_SOCKET` changes the reusable daemon path without becoming an explicit Bridge override.
`--no-remote` or `PEEKABOO_NO_REMOTE` forces local execution.

## Lifecycle modes

- **Auto**: launched on demand by a CLI command; exits after inactivity (default 300 seconds).
- **Manual**: launched by `peekaboo daemon start`; remains running until `peekaboo daemon stop`.

`PEEKABOO_DAEMON_IDLE_TIMEOUT_SECONDS` changes the auto idle timeout. Accepted requests count as activity, and shutdown
waits for accepted connections and operational services to drain.

Standalone `mcp` daemon mode is intentionally unavailable. `peekaboo mcp` owns its stdio lifecycle and uses only
process-local support such as window tracking.

## Socket ownership

Bridge listeners hold an exclusive lease beside their socket for the listener's full lifetime. Publication is atomic:
a host binds and secures a private temporary socket, then publishes it without replacing an owned path. Stale recovery
requires proof that no same-user process has the exact UNIX path open; a failed connection alone is not enough.

Shutdown removes a socket only when its filesystem identity still matches the listener that created it. Client
connect, read, and write operations are nonblocking and deadline-bound so abandoned connections cannot exhaust the
host.

## Legacy migration

Older daemons may still occupy Peekaboo.app's `bridge.sock`. Current daemon control detects the host kind before acting:

- Peekaboo.app is never mistaken for a daemon.
- Auto and manual daemons that advertise conditional stop migrate to `daemon.sock` while preserving lifecycle mode,
  polling interval, and idle timeout.
- Migration defers while requests are active.
- Older daemons without conditional stop remain on the legacy socket until they exit or are explicitly stopped.

## Status

`peekaboo daemon status --json` reports:

- PID, start time, lifecycle mode, and socket path
- Bridge protocol version, host kind, and advertised operations
- active requests, last activity, idle timeout, and idle deadline
- Screen Recording, Accessibility, and Event Synthesizing permissions
- snapshot count and last access
- tracked windows, AX observers, and poll interval; reconciliation retains only the exact bounds and owner PID needed for move-aware input
- cached browser MCP connection, tool count, and detected browsers

Daemon health never waits for optional browser discovery or connection validation. It starts at most one diagnostic
refresh at a time and returns the last completed values with `browser.observation: "indeterminate"`; before the first
completion, the empty values are unavailable information, not confirmed absence. Human output says `State: unconfirmed`.
Use `browser status` for a fresh browser observation. Native application metadata reads run on a dedicated background
queue, while browser connection validation and execution retain their existing ownership and ordering.

A missing or refused socket still reports `running: false`. A timeout, authorization failure, malformed reply, or
response loss after handshake fails the command with `success: false` and a nonzero exit; it does not prove absence.
Explicit start/stop use the same strict probes before choosing a target. Shutdown retains its existing wait and PID
checks, retries read-only observations, and reports an unresolved probe failure rather than claiming successful stop.

### Unsigned developer builds

Prefer the [notarized tap or npm CLI](install.md#homebrew-recommended). For a source build (including Homebrew core's
`peekaboo` formula), explicitly opt in before starting or connecting to your own daemon:

```bash
export PEEKABOO_ALLOW_UNSIGNED_DAEMON=1
peekaboo daemon start
peekaboo daemon status
```

The variable applies only when the current process is not release-signed. It lets an unsigned CLI trust only an
on-demand daemon with the same effective UID and exact same live kernel CDHash (the same executable bytes), and
lets that daemon admit only matching clients. Auto-start and `daemon start` propagate the variable. Restart an
existing daemon to apply the opt-in policy on the host as well. Different builds and GUI Bridge hosts still
require release signing. Release-signed CLIs, daemons, and Peekaboo.app ignore this variable completely.

`bridge status` and `daemon status` label accepted connections `unsigned same-binary developer opt-in`; JSON includes
`trustMode: "unsignedSameBinaryDeveloperOptIn"`. This is developer trust, not release-signature or source-provenance
attestation. Without the variable, an unsigned CLI skips implicit daemon auto-start and evaluates existing hosts
before falling back to local services where the command permits it. Its fallback description reports skipped
startup and untrusted hosts. A failed local host-authentication check makes that candidate unavailable during
implicit routing; it never authorizes replacing its socket or relaunching onto it. Other occupancy-probe errors
still fail the command. Release-signed clients retain their existing routing and error behavior.

Explicit `daemon start` and `daemon run` still start daemons without the variable; unsuccessful authenticated
readiness checks retain the unsigned-build installation hint. Explicit `daemon status`, `daemon stop`,
`--bridge-socket`, and `PEEKABOO_BRIDGE_SOCKET` retain authentication failures instead of silently falling back.

Ad-hoc source builds lack the hardened runtime: injected code can run inside the same binary and therefore share its
CDHash. Enable this only on machines you control. Prefer the notarized install for normal use.

See [`peekaboo daemon`](commands/daemon.md) for command flags and [Bridge host](bridge-host.md) for transport and
security details.
