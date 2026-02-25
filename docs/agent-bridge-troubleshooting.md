# Agent Bridge Troubleshooting

When running Peekaboo from AI agent frameworks (OpenClaw, Claude Code, etc.) that spawn commands via Node.js or similar runtimes, you may encounter capture failures even when permissions are granted.

## Common Issue: Bridge Capture Failure

### Symptoms

```
INTERNAL_SWIFT_ERROR: Failed to start stream due to audio/video capture failure
PeekabooBridgeErrorEnvelope error 1
```

These errors occur on commands that use window/screen capture (`see`, `image --mode window`) when routed through the Peekaboo bridge daemon.

Non-capture commands (`click`, `type`, `hotkey`, `list`, `permissions`) work normally.

### Root Cause

The Peekaboo bridge daemon process may not inherit ScreenCaptureKit (SCKit) TCC grants from the parent terminal/agent process. This is a macOS security behavior where SCKit permissions are tied to the specific process requesting capture, not inherited from parent processes.

### Affected Environments

- macOS 15+ (Sequoia/Tahoe)
- Commands spawned by Node.js-based agent runners (OpenClaw, etc.)
- Peekaboo 3.0.0-beta3

### Workaround

Stop the daemon and use local mode with the CoreGraphics capture engine:

```bash
# Stop the daemon to avoid bridge routing
peekaboo daemon stop

# Use local CG engine for screen capture (bypasses SCKit)
peekaboo see --mode screen --screen-index 0 --capture-engine cg --no-remote --json
```

### Why This Works

- `--no-remote` forces local execution (skips bridge daemon)
- `--capture-engine cg` uses CoreGraphics instead of ScreenCaptureKit
- CoreGraphics uses a different permission model that works in agent-spawned contexts
- `--mode screen --screen-index 0` captures the full display instead of targeting a specific window

### Recommended Agent Integration Pattern

For AI agents that need to automate macOS via Peekaboo:

1. **Use Browser Relay for web tasks** — Chrome extensions or browser automation tools handle web forms more reliably than screen capture + click
2. **Use Peekaboo for native macOS tasks** — Finder, System Settings, dialogs, menus
3. **Wrap Peekaboo in a script** that handles the daemon stop + CG fallback automatically:

```bash
#!/bin/bash
# Ensure daemon is stopped for reliable capture
peekaboo daemon stop 2>/dev/null || true

# Capture with CG engine
peekaboo see --mode screen --screen-index 0 \
  --capture-engine cg --no-remote --json
```

4. **Non-capture commands work via bridge** — `click`, `type`, `hotkey`, `press`, `scroll` can use the daemon normally

### Related Issues

- [#75](https://github.com/steipete/Peekaboo/issues/75) — Screen Recording permission check fails on macOS 26 when spawned by Node.js
- [#77](https://github.com/steipete/Peekaboo/issues/77) — Peekaboo no permission in OpenClaw
- [#52](https://github.com/steipete/Peekaboo/issues/52) — Swift continuation leak causes see/image/permissions commands to hang
