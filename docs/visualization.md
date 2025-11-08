# Visualization Diagnostics

Peekaboo's visualization pipeline has two moving pieces:

1. **VisualizerXPCService** runs inside the macOS app and renders click/typing overlays, flashes, and annotations.
2. **VisualizationClient** ships with the CLI and Core frameworks. It connects to the XPC service, mirrors interesting events to stderr for agent users, and toggles visual feedback during capture.

### XPC transport contract

Peekaboo ships an embedded XPC service bundle (`PeekabooVisualizerService.xpc`) whose bundle identifier is `boo.peekaboo.visualizer`. The macOS app copies this service into `Peekaboo.app/Contents/XPCServices` and the service declares a Mach service with the same name, so every CLI can connect via `NSXPCConnection(machServiceName: VisualizerXPCServiceName)`.

For this to work reliably:

- Peekaboo.app (or its login item) must be running so the service bundle is present on disk (launchd will spin up the helper on demand).
- `Info.plist` must keep the `MachServices` entry so `launchd` lets clients dial the service.
- `VisualizerXPCService` must stay alive for the lifetime of the app and accept multiple concurrent connections.

If we ever move the host into a helper/login item the Mach service name must remain unchanged so existing CLIs continue to connect.

The sections below capture the current debugging workflow so we do not lose tribal knowledge the next time the overlays appear to be "missing".

## Runtime Logging

### Console mirroring for agents

When the CLI (or any non-macOS-app bundle) instantiates `VisualizationClient.shared`, it mirrors every connection and tool invocation message to `stderr`. This gives instant feedback while running commands such as `peekaboo see`: you will see messages like `INFO Scheduling connection retry #1` directly in the terminal without spelunking `log show`. Set `PEEKABOO_VISUALIZER_STDOUT=false` to silence the console mirroring or `=true` to force it on even inside the macOS app.

### Unified logging & privacy overrides

The macOS host still emits the same messages through Apple's unified logging, but Apple redacts dynamic payloads by default. We now keep the Peekaboo logging profile installed at all times so the system captures real values (see `docs/logging-profiles/README.md`). That profile implements Peter Steinberger's "Logging Privacy Shenanigans" playbook for the `boo.peekaboo.core`, `boo.peekaboo.mac`, and `boo.peekaboo.visualizer` subsystems. If you ever end up on a machine without the profile, follow the steps below to install it and leave it in place.

1. Install the Peekaboo logging profile (preferred) so the OS records full payloads.
2. If you cannot install profiles on a given box, run `sudo log config --mode private_data:on --subsystem boo.peekaboo.core --subsystem boo.peekaboo.mac --persist` instead and leave it enabled for the duration of your work.
3. Reproduce the issue and capture logs with `log stream --info --predicate 'subsystem == "boo.peekaboo.core"'`.
4. Only remove the override when you intentionally need a locked-down environment (`log config --reset private_data`).

This policy keeps development boxes permanently verbose while still documenting how to tighten things back up for customer demos.

## Smoke tests

Use these steps to verify the visualization stack end-to-end:

1. Launch the macOS app (it hosts the XPC service).
2. Run `polter peekaboo -- see --mode screen --path /tmp/peekaboo-see.png --annotate`.
3. Confirm the CLI prints the `Visualizer` connection log lines and that `/tmp/peekaboo-see*.png` contains the annotated overlays.
4. Watch `log stream` from the macOS app to ensure the service logs the requests.

If step 2 succeeds but there are no logs in step 4, install the privacy override profile and try again.

## Failure modes to look for

- **Peekaboo.app is not running:** `VisualizationClient` now logs this explicitly and keeps retrying with exponential backoff instead of silently giving up.
- **XPC connection interrupted:** the client writes an immediate warning and schedules another attempt after 2, 4, then 6 seconds; no `Timer`/run-loop tricks are required anymore.
- **Slow or wedged `isVisualFeedbackEnabled`:** we time out on a detached task so the CLI stays responsive instead of freezing the MainActor.

Keep this document updated whenever we touch the overlay pipeline so we can reference a single living artifact during postmortems.
