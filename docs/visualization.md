---
summary: "Peekaboo Visualizer Bridge, Animations, and Diagnostics"
read_when:
  - Working on VisualizerXPCService, VisualizationClient, or overlay animations
  - Investigating CLI → app visual feedback issues
---

# Visualization Diagnostics

Peekaboo’s visual feedback stack now consists of a three-part bridge that keeps the CLI, MCP tools, and the macOS app in sync:

1. **VisualizerXPCService** (`Apps/Mac/Peekaboo/Services/Visualizer/VisualizerXPCService.swift`) lives inside Peekaboo.app. It owns the anonymous `NSXPCListener`, exports every animation method in `VisualizerXPCProtocol`, and forwards work to `VisualizerCoordinator`.
2. **PeekabooVisualizerBridge.xpc** (`Apps/Mac/PeekabooBridge/PeekabooVisualizerBridge.xpc`) is a lightweight helper process. It keeps the most recent `NSXPCListenerEndpoint` in memory so external clients can always ask for the latest connection without knowing which app process spawned it.
3. **VisualizationClient** (`Core/PeekabooCore/Sources/PeekabooCore/Visualizer/VisualizationClient.swift`) ships with the CLI and PeekabooCore. It dials the bridge (`VisualizerEndpointBrokerServiceName`), turns the endpoint into an `NSXPCConnection(listenerEndpoint:)`, mirrors all connection state to stderr for agents, and issues animation RPCs during commands like `peekaboo see`.

The CLI also shares the ObjC protocol definition in `VisualizerEndpointBrokerProtocol.swift`, so both app and CLI agree on the broker contract at compile time.

## Component Map & Lifecycle

| Component | Location | Responsibility |
| --- | --- | --- |
| `VisualizerXPCService` | `Apps/Mac/Peekaboo/Services/Visualizer/VisualizerXPCService.swift` | Creates the anonymous listener, handles new XPC connections, registers the endpoint with the broker, and exposes every animation endpoint. |
| `VisualizerCoordinator` | `Apps/Mac/Peekaboo/Services/Visualizer/VisualizerCoordinator.swift` | Renders each animation via SwiftUI overlay windows, applies settings, and serialises work on `OptimizedAnimationQueue`. |
| `PeekabooVisualizerBridge.xpc` | `Apps/Mac/PeekabooBridge/` | Implements `VisualizerEndpointBrokerProtocol`, storing the latest `NSXPCListenerEndpoint` and serving it to clients. |
| `VisualizationClient` | `Core/PeekabooCore/.../VisualizationClient.swift` | Runs inside CLI/tests, polls `NSXPCConnection(serviceName: VisualizerEndpointBrokerServiceName)` until an endpoint arrives, then talks directly to the anonymous listener. |

### Connection Flow

1. **App boot** – `PeekabooApp` instantiates `VisualizerCoordinator` and `VisualizerXPCService`. The service immediately registers its anonymous endpoint with the bridge via `registerVisualizerEndpoint(_:)`.
2. **Bridge cache** – The bridge holds only the latest endpoint in RAM; no endpoints are written to disk (macOS forbids serializing `NSXPCListenerEndpoint` outside `NSXPCCoder`).
3. **CLI request** – `VisualizationClient.connect()` creates a short-lived XPC connection to the bridge and calls `fetchVisualizerEndpoint`. If the bridge responds with `nil`, the client logs a warning and schedules a retry (2s/4s/6s).
4. **Direct channel** – When the bridge returns an endpoint, the CLI creates `NSXPCConnection(listenerEndpoint:)`, validates `isVisualFeedbackEnabled`, and caches the proxy for the duration of the command.
5. **Recovery** – Interruptions or invalidations tear down the proxy, mark the client as disconnected, and trigger the same exponential retry as the “no endpoint” path.

Keep Peekaboo.app (or its login item) running so a fresh listener is always registered. If the bridge crashes, the app will re-register within a second because `VisualizerXPCService` keeps retrying until `registerVisualizerEndpoint` succeeds.

## Animation Catalog (Powered by `VisualizerCoordinator`)

Every CLI/MCP action maps to a method on `VisualizerXPCService`, which in turn calls the corresponding coordinator method. The coordinator validates user settings before rendering each SwiftUI overlay. Highlights:

| Action | RPC | Notes from code |
| --- | --- | --- |
| Screenshot flash | `showScreenshotFlash(in:)` | 200 ms flash with the “👻 every 100th screenshot” easter egg controlled by `PeekabooSettings.screenshotFlashEnabled`. |
| Click feedback | `showClickFeedback(at:type:)` | Ripple animation sized to 200 px around the click point, supports `.single`, `.double`, `.right`. |
| Typing widget | `showTypingFeedback(keys:duration:)` | Bottom-centered keyboard overlay (`TypeAnimationView`) honoring `visualizerAnimationSpeed`. |
| Scroll indicator | `showScrollFeedback(at:direction:amount:)` | Directional arrows rendered near the scroll origin, disabled when `scrollAnimationEnabled` is false. |
| Mouse trail / swipe | `showMouseMovement` / `showSwipeGesture` | Particle trail or gradient swipe path animating across all displays. |
| Hotkeys | `showHotkeyDisplay(keys:duration:)` | Large overlay of key combos, often triggered by automation keyboard shortcuts. |
| App lifecycle | `showAppLaunch` / `showAppQuit` | Bouncing icon (launch) or shrink/fade (quit), optionally populated with the app’s icon path. |
| Window + menu flows | `showWindowOperation`, `showMenuNavigation`, `showDialogInteraction` | Annotated outlines, breadcrumb highlights, and button pulses. |
| Spaces + element detection | `showSpaceSwitch`, `showElementDetection`, `showAnnotatedScreenshot` | Used by CLI “see” mode to render overlays matching detected UI elements. |

Per-action toggles live in `PeekabooSettings` (see `VisualizerSettings` enum near the bottom of `VisualizerXPCService.swift`). Respect those flags when adding new animations.

## Settings & Environment Controls

- **In-app settings** – `SettingsWindow` exposes `Visual Feedback Enabled`, effect intensity, animation speed, plus per-action toggles (flash, clicks, typing, scroll, mouse trail, etc.).
- **Environment variables** – `VisualizationClient` honours `PEEKABOO_VISUAL_FEEDBACK=false` (global kill switch) and `PEEKABOO_VISUAL_SCREENSHOTS=false` (skip flash only). `PEEKABOO_VISUALIZER_STDOUT=true|false` forces stderr mirroring on/off outside the macOS bundle.
- **Defaults** – Non-app processes mirror every log line (subsystem `boo.peekaboo.core`, category `VisualizationClient`) to stderr so agents immediately see connection status.

## Runtime Logging & Diagnostics

### CLI mirroring

Expect log lines such as `🔌 Client: Attempting to connect`, `Broker returned no endpoint`, `Registered endpoint with broker`, and `Retrying in 2s`. If you do **not** see these when running `polter peekaboo see`, the CLI binary is stale or the bridge could not be reached.

### Unified logging profile

We permanently install the `EnablePeekabooLogPrivateData` configuration (see `docs/logging-profiles/README.md`). When you cannot install profiles (e.g., on CI), run:

```bash
sudo log config --mode private_data:on \
  --subsystem boo.peekaboo.core \
  --subsystem boo.peekaboo.mac \
  --persist
```

Reset with `sudo log config --reset private_data` once you finish debugging.

### `scripts/visualizer-logs.sh`

Use the helper to capture the right predicate without memorising syntax:

```bash
# Show the last 15 minutes of visualizer chatter
scripts/visualizer-logs.sh --last 15m

# Live-stream while running CLI commands
scripts/visualizer-logs.sh --stream
```

Override the predicate via `--predicate 'subsystem == "boo.peekaboo.mac"'` when you need narrower scopes.

## Smoke Tests

1. Launch Peekaboo.app (built via `polter peekaboo --version` to ensure a fresh binary). The app logs `🎨 XPC Service: Registered endpoint with broker`.
2. Run `polter peekaboo -- see --mode screen --annotate --path /tmp/peekaboo-see.png`.
3. Verify the CLI prints the connection lifecycle logs and that overlays render in real time.
4. Run `scripts/visualizer-logs.sh --last 5m` to ensure macOS unified logs show matching entries from both subsystems.

If step 2 succeeds but step 4 shows nothing, reinstall the logging profile or rerun `sudo log config --mode private_data:on …`.

## Failure Modes Checklist

- **Peekaboo.app not running** – CLI now logs `Peekaboo.app is not running; visual feedback unavailable until it launches` once and quietly retries every few seconds. Launch the app (or its login item) and the client reconnects automatically.
- **Bridge missing or corrupted** – Logs show `Failed to connect to endpoint broker`. Reinstall or rebuild the app so `PeekabooVisualizerBridge.xpc` is placed inside `Contents/XPCServices`.
- **Connection interrupted** – Expect `XPC connection interrupted/invalidated`; the client tears down the proxy and retries (2 s, 4 s, 6 s). If retries never succeed, inspect the bridge logs via `scripts/visualizer-logs.sh --stream`.
- **Slow `isVisualFeedbackEnabled`** – `VisualizationClient` drops the connection if the initial RPC takes longer than 2 s. Watch for `Connection test failed` and inspect the app logs for deadlocks.
- **App crash** – Grab the latest `Peekaboo-*.ips` file from `~/Library/Logs/DiagnosticReports`, attach it to the issue, relaunch the app, and ensure the endpoint re-registers.

Keep this document updated whenever `VisualizerXPCService`, the bridge, or `VisualizationClient` change so new agents have an authoritative single source of truth.
