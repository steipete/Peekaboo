---
summary: "Describe Peekaboo Bridge host architecture (socket-based TCC broker)"
read_when:
  - "embedding Peekaboo automation into another macOS app"
  - "debugging remote execution for Peekaboo CLI"
  - "auditing auth/security for privileged automation surfaces"
---

# Peekaboo Bridge Host

Peekaboo Bridge is a **socket-based** broker for permission-bound operations (Screen Recording, Accessibility, AppleScript). It lets a CLI (or other client process) drive automation via a host app that already has the necessary TCC grants.

This replaces the previous XPC-based helper approach.

## Hosts and discovery (client preference order)

Clients try hosts in this order:

1. **Peekaboo.app** (primary host)
   - Socket: `~/Library/Application Support/Peekaboo/bridge.sock`
2. **Claude.app** (fallback host; piggyback on Claude Desktop TCC grants)
   - Socket: `~/Library/Application Support/Claude/bridge.sock`
3. **Clawdis.app** (fallback host)
   - Socket: `~/Library/Application Support/clawdis/bridge.sock`
4. **Local in-process** (no host available; requires the caller process to have TCC grants)

There is **no auto-launch** of Peekaboo.app.

## Transport

- **UNIX-domain socket**, single request per connection:
  - Client writes one JSON request, then half-closes.
  - Host replies with one JSON response and closes.
- Payloads are `Codable` JSON with a small handshake for:
  - protocol version negotiation
  - capability/operation advertisement

## Security

Peekaboo BridgeHost validates callers before processing any request:

- Reads the peer PID via `getsockopt(..., LOCAL_PEERPID, ...)`.
- Validates the peer’s **code signature TeamID** via Security.framework (`SecCodeCopyGuestWithAttributes`).
- Rejects any process not signed by an allowlisted TeamID (default: `Y5PE65HELJ`).

Debug-only escape hatch:

- Set `PEEKABOO_ALLOW_UNSIGNED_SOCKET_CLIENTS=1` to allow same-UID unsigned clients (local dev only).

## Snapshot state

Bridge hosts are intended to be long-lived and keep automation state **in memory**:

- Hosts typically use `InMemorySnapshotManager` so follow-up actions can reuse the “most recent snapshot” per app/bundle without passing IDs around.
- Screenshot artifacts are still referenced by **file path** (e.g. in `/tmp`), and are not streamed incrementally.

## CLI behavior

- By default, the CLI attempts to use a remote host when available.
- Use `--no-remote` to force local execution.
- Use `--bridge-socket <path>` or `PEEKABOO_BRIDGE_SOCKET` to override host discovery.
- Use `peekaboo bridge status` to verify which host would be selected and why (probe results, handshake errors, etc.).
