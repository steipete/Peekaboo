---
summary: "Plan the XPC helper that fronts TCC-bound operations for CLI/GUI/daemon reuse"
read_when:
  - "designing remote execution for Peekaboo CLI from SSH or sandboxed seats"
  - "embedding Peekaboo.app as a broker for automation services"
  - "adding or auditing XPC surfaces that wrap Screen Recording / AX operations"
---

# Peekaboo XPC Helper Plan

## Goal
Let the CLI and agents run from SSH or otherwise TCC-less shells by remoting all permission-bound operations (Screen Recording, Accessibility, AppleScript) into a process that already holds grants. Reuse that same surface from Peekaboo.app when it is running, and fall back to a dedicated helper when it is not.

## Scope (what crosses the boundary)
- Capture: screen/window/frontmost/area (ScreenCaptureService), capture metadata.
- AX-bound UI control: click, type, scroll, hotkey, gestures, window/menu/dock/dialog operations, app focus/launch/quit, list apps/windows/spaces.
- Permissions snapshot + rationale (no prompting over XPC).
- Session/cache plumbing: stash/retrieve detection sessions and contact-sheet paths so downstream CLI commands stay fast.
- Explicitly **out of scope** for v1: AI provider calls, filesystem ops, network calls, configuration writes. Keep the surface narrow and capability-checked.

## Hosts and discovery
- Two modes only: XPC or direct CLI. We try XPC first; if unreachable we fall back to in-process services.
- XPC hosts:
  - Peekaboo.app (when running) exposes the mach service.
  - `PeekabooHelper` LaunchAgent (`boo.peekaboo.helper`) for headless/SSH.
- CLI owns `RemotePeekabooServices`, connects to the first reachable XPC host, and reconnects on failure. If none are reachable, it uses local services.

## Transport choice
- Use an XPC service with a small, versioned protocol. Prefer a single listener that hands out per-client connections.
- `AsyncXPCConnection` (ChimeHQ) is a good fit for Swift concurrency; it keeps main-actor affinity clearer than raw `NSXPCConnection` and is maintained. Wrap it in a thin shim so we can swap to raw XPC if the dependency ever becomes a liability.
- **Data-only XPC surface:** exported `@objc` protocol stays ObjC-friendly (`Data` in/out). Client/server shims JSON-encode Codable payloads and decode replies; never expose `async` methods directly on the XPC interface to avoid dropped replies.
- Use `RemoteXPCService` + `QueuedRemoteXPCService` for ordering and cancellation. Long-running capture/automation calls go through the queued service with bounded concurrency.
- All payloads Codable; avoid `@objc` bridging shims beyond the Data envelope.

## Security & auth
- Code-sign validation on incoming audit token; reject unknown team IDs/bundle IDs. Guard with allowlist: Peekaboo CLI binary + Peekaboo.app only.
- Check UID match to console user; record PID/UUID on each request for audit logs.
- Capability map per method; refuse operations outside the TCC set.
- Limit helper filesystem access to its cache roots; never proxy arbitrary file I/O.

## Concurrency & threading
- Helper runs on main actor for anything that touches AX/SC/CG events; bounce XPC calls to the main actor immediately.
- Use bounded task queues for long captures; surface cancellation from clients.

## Versioning & compatibility
- Handshake message includes protocol version and app/build version. Server can advertise supported ranges; client falls back to in-process if incompatible.
- Add `X-Peekaboo-Protocol: <major.minor>` in the initial bootstrap message; breaking changes bump major.
- Reject at handshake if the client bundle/team ID isn’t allowlisted; return a typed `unauthorizedClient` error before wiring up any services.

## API outline (minimal, grouped)
- `permissions.status() -> PermissionsStatus`
- `capture.screen(display?, scale?, visualizerMode?) -> CaptureResult`
- `capture.window(app?, index?, title?) -> CaptureResult`
- `capture.area(rect) -> CaptureResult`
- `automation.click(target, clickType)`
- `automation.type(text, target?, clear?)`
- `automation.scroll(delta, target?)`
- `automation.hotkey(keys)`
- `automation.gesture(kind, points, duration)`
- `apps.list() -> [AppInfo]`, `apps.find(query) -> AppInfo` (for window/menu/dock helpers)
- `windows.list(app?) -> [WindowInfo]`, `windows.focus(id)`
- `menus.list(app/window)`, `menus.activate(path)`
- `dock.list()`, `dock.activate(index|name)`
- `sessions.store(ElementDetectionResult)`, `sessions.load(id)`, `sessions.list()`

Error model: typed error codes (`permissionDenied`, `notFound`, `timeout`, `invalidRequest`, `serverBusy`, `versionMismatch`) with optional localized detail string.

## Lifecycle commands (CLI UX)
- `peekaboo permissions bootstrap`: installs/starts the helper LaunchAgent, triggers one-time Screen Recording + Accessibility prompts on the helper binary, verifies handshake.
- `peekaboo permissions status --json`: shows which host is active (GUI/helper/local) and protocol version.
- `peekaboo daemon restart`: polite restart of helper; GUI host ignored.

## Data paths
- Reuse existing session storage layout so remote captures remain compatible (`SessionManager` paths). Helper writes under the same base; ensure permissions so CLI can read results.
- Visualizer: leave as-is (file + distributed notification) until/unless we co-host the visualizer endpoint; not required for CLI-from-SSH.

## Migration plan
1) Define `PeekabooXPCProtocol` module (Codable messages, no app coupling); add proxy/stub.
2) Build `PeekabooHelper` target (LaunchAgent bundle) hosting `PeekabooServices` and conforming to the protocol; main-actor hop inside.
3) Add GUI listener that reuses the same handler; no extra privileges needed.
4) Implement `RemotePeekabooServices` that satisfies `PeekabooServiceProviding` via XPC; plug into `CommandRuntime` selection.
5) Ship bootstrap/install commands + health checks; add integration tests gated by `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true` that exercise the proxy when permissions exist.
6) Add telemetry counters (host kind, latency, error codes) for observability.

## Known caveats
- TCC remains per-binary: the helper and app each need their own grants once. SSH usability depends on completing that initial local prompt.
- LaunchDaemon (root/session 0) is insufficient for AX/SC; stick to per-user LaunchAgent or on-demand `asuser` helper.
- Keep payloads small: don’t stream pixels over XPC; use file-backed captures and return paths + metadata.

## Implementation status (Dec 2025)
- Helper target (`PeekabooHelper`) and Peekaboo.app both host the same mach service; the GUI registers `boo.peekaboo.app` while the LaunchAgent keeps `boo.peekaboo.helper` for headless use.
- Handshake now validates the audit token (team/bundle from code signature + pid/uid), rejects non-console users, and returns the negotiated capability map.
- The remote allowlist includes menu, dock, dialog, and session/cache operations; unsupported callers receive `operationNotSupported`.
- Sessions are stored on the helper via XPC (create/store/load/list/clean), keeping detection caches warm across remote commands.
- Client discovery tries GUI first, then helper; falls back to in-process when neither is reachable. Per-request logs include latency for basic observability.
- `peekaboo permissions helper-bootstrap` still installs `~/Library/LaunchAgents/boo.peekaboo.helper.plist`, copies the helper binary into `~/Library/Application Support/Peekaboo/`, and bootstraps it via `launchctl`.
