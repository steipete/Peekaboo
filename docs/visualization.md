---
summary: 'Peekaboo visual feedback bridge over distributed notifications'
read_when:
  - Working on VisualizationClient or VisualizerEventReceiver
  - Investigating CLI → app visual feedback issues
---

# Visualization Diagnostics

Peekaboo’s visual feedback stack no longer relies on XPC brokers or LaunchAgents. Instead, the CLI writes lightweight event envelopes to a shared directory and pings the macOS app via `NSDistributedNotificationCenter`. If the UI is alive it renders the animation immediately; if not, the message is silently dropped—exactly the “best effort” behavior we want for automation hints.

## Components

| Component | Location | Responsibility |
| --- | --- | --- |
| `VisualizationClient` | `Core/PeekabooCore/Sources/PeekabooCore/Visualizer/VisualizationClient.swift` | Runs inside the CLI/MCP processes, serializes animation payloads, persists them via `VisualizerEventStore`, and posts distributed notifications containing the event ID + kind. |
| `VisualizerEventStore` | `Core/PeekabooCore/.../VisualizerEventStore.swift` | Defines the `VisualizerEvent` payloads, manages the shared `~/Library/Application Support/PeekabooShared/VisualizerEvents` directory, and exposes helpers to persist/load/clean up events. |
| `VisualizerEventReceiver` | `Apps/Mac/Peekaboo/Services/Visualizer/VisualizerEventReceiver.swift` | Lives inside Peekaboo.app, listens for `boo.peekaboo.visualizer.event` notifications, loads the referenced event JSON, and forwards it to `VisualizerCoordinator`. |
| `VisualizerCoordinator` | `Apps/Mac/Peekaboo/Services/Visualizer/VisualizerCoordinator.swift` | Renders the SwiftUI overlays (flash, clicks, typing, menus, annotated screenshots, etc.) and enforces user settings. |

## Event Flow

1. **CLI emits** – Services in PeekabooCore call `VisualizationClient.shared.show…`. The client builds a strongly typed `VisualizerEvent.Payload`, ensures the shared directory exists, and atomically writes `<uuid>.json`.
2. **Notification ping** – After the file lands, the client posts `DistributedNotificationCenter.default().post(name: .visualizerEventDispatched, object: "<uuid>|<kind>")`. No `userInfo` is attached to remain sandbox-safe.
3. **App receives** – `VisualizerEventReceiver` parses the UUID, loads the JSON via `VisualizerEventStore.loadEvent(id:)`, and hands the payload to `VisualizerCoordinator`. Once the animation call resolves, it deletes the JSON file.
4. **Cleanup** – Both the CLI and app periodically call `VisualizerEventStore.cleanup(olderThan:)` so unclaimed files (e.g., app never launched) disappear automatically. By default we keep at most ~10 minutes of backlog.

Because there is no acknowledgement or retry loop, **events are intentionally transient**: if Peekaboo.app is not running, the CLI logs a single warning and skips visual feedback until the UI returns.

## Storage & Format

- **Directory**: `~/Library/Application Support/PeekabooShared/VisualizerEvents`. Override with `PEEKABOO_VISUALIZER_STORAGE=/custom/path` or, for future sandboxing, set `PEEKABOO_VISUALIZER_APP_GROUP=com.example.group` so the store lives inside the specified container.
- **File name**: `<UUID>.json`
- **Schema**: `VisualizerEvent` encodes `{ id, createdAt, payload }`. Payload is a `Codable` enum covering every animation (`screenshotFlash`, `clickFeedback`, `annotatedScreenshot`, …). `Data` fields (e.g., screenshots) are base64 encoded automatically by `JSONEncoder`.

## Settings & Environment

- `PEEKABOO_VISUAL_FEEDBACK=false` – disables the client globally (no files, no notifications).
- `PEEKABOO_VISUAL_SCREENSHOTS=false` – skips screenshot flash events only.
- `PEEKABOO_VISUALIZER_STDOUT=true|false` – forces VisualizationClient logs to stderr regardless of bundle context.
- `PEEKABOO_VISUALIZER_STORAGE=/path` – overrides the shared directory (useful in tests).
- `PEEKABOO_VISUALIZER_APP_GROUP=<group>` – asks the store to resolve an App Group container instead of `~/Library/Application Support`.
- `PEEKABOO_VISUALIZER_FORCE_APP=true` – test hook that bypasses the “Peekaboo.app must be running” check so you can trigger events from headless harnesses (remember to delete the generated JSON afterward).

The macOS app continues to honor user-facing toggles via `PeekabooSettings`; `VisualizerCoordinator` checks those before playing anything.

## Logging & Diagnostics

- **CLI** – `VisualizationClient` logs every dispatch attempt to the `boo.peekaboo.core` subsystem. Run `scripts/visualizer-logs.sh --stream` to tail both the client and receiver categories.
- **App** – `VisualizerEventReceiver` logs receipt/failures under `boo.peekaboo.mac`. When diagnosing missing visuals, confirm you see “Processing visualizer event …” entries followed by `VisualizerCoordinator` output.
- **File inspection** – `ls ~/Library/Application Support/PeekabooShared/VisualizerEvents` to see outstanding events. A growing pile means the app isn’t consuming them (maybe it isn’t running, or the JSON failed to decode).
- **Cleanup** – manually purge with `rm ~/Library/Application\ Support/PeekabooShared/VisualizerEvents/*.json` if you need a clean slate; both sides will recreate the folder automatically.

## Failure Modes

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| CLI logs “Peekaboo.app is not running…” | UI not launched (intended behavior) | Start Peekaboo.app or its login item. |
| Event files accumulate but no animations | App missing accessibility/screen permissions or crashed before instantiating `VisualizerEventReceiver` | Relaunch the app, check `Console` for `VisualizerEventReceiver` errors, and verify permissions via Settings → Privacy. |
| `VisualizerEventStore` errors about writing files | Shared directory missing or unwritable | Ensure the parent path exists and that the current user can write to it; override via `PEEKABOO_VISUALIZER_STORAGE` if needed. |
| Annotated screenshot payloads fail to decode | Event file truncated or cleaned before the app loaded it | Increase cleanup threshold (edit `VisualizationClient.cleanupInterval`) or avoid killing the app mid-transfer. |

## Smoke Tests

1. Launch Peekaboo.app (Poltergeist rebuild ensures fresh bits). Confirm logs show `Visualizer event receiver registered`.
2. Run a CLI command that triggers visuals, e.g. `polter peekaboo see --mode screen --annotate --path /tmp/peekaboo-see.png`.
3. Observe CLI stderr for `Dispatching visualizer event …` and watch the overlays on screen.
4. Verify `~/Library/Application Support/PeekabooShared/VisualizerEvents` stays mostly empty—files should appear briefly and then disappear once consumed.
5. Optional: set `PEEKABOO_VISUAL_FEEDBACK=false`, rerun the command, and confirm no files or notifications appear (the CLI should log that visual feedback is disabled).
