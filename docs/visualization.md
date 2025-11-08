# Visualization Diagnostics

Peekaboo's visualization pipeline now has three coordinated pieces:

1. **VisualizerXPCService** runs inside the macOS app and renders click/typing overlays, flashes, space switches, and annotations.
2. **PeekabooVisualizerBridge.xpc** is a lightweight helper bundled with the app. It stores the most recent anonymous listener endpoint exported by `VisualizerXPCService` and serves it to every client that connects.
3. **VisualizationClient** (part of PeekabooCore/CLI) connects to the bridge, retrieves the latest endpoint, mirrors important events to stderr for agents, and invokes the renderer during CLI operations like `peekaboo see`.

## XPC Transport Contract

macOS refuses to archive `NSXPCListenerEndpoint` instances outside of an `NSXPCCoder`, so we can no longer persist the endpoint on disk. The flow is therefore:

1. Peekaboo.app launches, instantiates `VisualizerXPCService`, and obtains an anonymous `NSXPCListener.endpoint`.
2. The app dials the embedded helper (`boo.peekaboo.visualizer.bridge`) and calls `registerVisualizerEndpoint(_:)`.
3. Every CLI process calls `fetchVisualizerEndpoint()` on the bridge. If it receives a non-nil endpoint it builds `NSXPCConnection(listenerEndpoint:)` directly to the in-app service. Otherwise it retries later.

For this to stay reliable:

- Ensure `PeekabooVisualizerBridge.xpc` only lives inside `Peekaboo.app/Contents/XPCServices`. A stray copy inside `Resources` won’t run.
- Keep Peekaboo.app (or its login item) running so the anonymous listener keeps registering itself with the bridge.
- Make sure both the app and the CLI log broker failures loudly—silent timeouts make debugging impossible.

## Runtime Logging

### Console mirroring for agents

Any non-macOS bundle (CLI, tests, agents) mirrors visualization logs to stderr. You should immediately see messages such as `🔌 Client: Attempting to connect` or `Retrying in 2s` when running `peekaboo see`. Set `PEEKABOO_VISUALIZER_STDOUT=false` to mute the mirror or `=true` to force it on inside the macOS app.

### Unified logging & privacy overrides

We permanently install the `EnablePeekabooLogPrivateData` profile (see `docs/logging-profiles/README.md`). This keeps private-data logging enabled across the `boo.peekaboo.core`, `boo.peekaboo.mac`, and `boo.peekaboo.visualizer` subsystems so diagnostics actually contain window titles, endpoints, and process names. Only uninstall the profile if you are prepping a locked-down demo machine; reinstall it immediately afterward.

On machines where profiles are forbidden, run the fallback override and leave it in place during your session:

```bash
sudo log config --mode private_data:on \
  --subsystem boo.peekaboo.core \
  --subsystem boo.peekaboo.mac \
  --persist
```

Reset only when you explicitly need the stock policy: `sudo log config --reset private_data`.

### scripts/visualizer-logs.sh

Use `scripts/visualizer-logs.sh` to capture the relevant unified logs without memorising predicates.

```bash
# Show the last 15 minutes of visualization chatter
scripts/visualizer-logs.sh --last 15m

# Stream logs while exercising the CLI
scripts/visualizer-logs.sh --stream
```

Pass `--predicate '...'` if you need to dig into a specific subsystem or category.

## Smoke Tests

1. Launch Peekaboo.app from the latest build output (it publishes the visualizer endpoint).
2. Run `polter peekaboo -- see --mode screen --annotate --path /tmp/peekaboo-see.png`.
3. Confirm the CLI prints the VisualizationClient connection logs (`Attempting to connect`, `Successfully connected`, etc.).
4. Run `scripts/visualizer-logs.sh --last 5m` to ensure the macOS host logs show the incoming requests.

If step 2 works but you do not see logs in step 4, reinstall the logging profile or enable the temporary `log config --mode private_data:on ...` override.

## Failure Modes To Watch

- **Peekaboo.app not running:** The CLI will log `Peekaboo.app is not running` and retry with exponential backoff. Launch the app and re-run the command.
- **Bridge missing or corrupted:** Both sides log `Failed to connect to endpoint broker`. Rebuild the app to regenerate `PeekabooVisualizerBridge.xpc` and confirm it sits under `Contents/XPCServices`.
- **Connection interrupted:** The CLI logs the interruption, tears down the proxy, and schedules another attempt (2s, 4s, 6s). You should not see unbounded timers anymore.
- **Slow `isVisualFeedbackEnabled`:** We now guard the initial RPC with a 2s timeout so the CLI remains responsive.
- **App crash:** Fetch the `.ips` file via `ls -t ~/Library/Logs/DiagnosticReports | head -n 1`, attach it to the issue, then relaunch the app so the bridge re-registers the endpoint.

Keep this document updated whenever we touch the overlay pipeline so postmortems have a single source of truth.
