# Peekaboo v3.0.0-beta2

## Installation

### Homebrew (Recommended)
```bash
brew tap steipete/tap
brew install peekaboo
```

### Direct Download
```bash
curl -L https://github.com/steipete/peekaboo/releases/download/v3.0.0-beta2/peekaboo-macos-arm64.tar.gz | tar xz
sudo mv peekaboo-macos-arm64/peekaboo /usr/local/bin/
```

### npm (includes MCP server)
```bash
npm install -g @steipete/peekaboo
```

## What's New

### Highlights
- **Socket-based Peekaboo Bridge**: privileged automation now runs in a long-lived, signed bridge host and the CLI connects over a UNIX socket.
- **Snapshots replace sessions**: snapshots are scoped per target bundle ID and auto-reused for follow-up actions.
- **New `peekaboo paste`**: set clipboard content, paste (Cmd+V), then restore the prior clipboard.
- **Deterministic window targeting** via `--window-id`.
- **MCP server-only**: Peekaboo still runs as an MCP server, but no longer hosts/manages external MCP servers.
- **Visualizer extracted + stabilized**: improved preview timings, less clipping.

### Breaking changes (beta1 → beta2)
- Removed the v3.0.0-beta1 XPC helper pathway; remote execution now uses the Peekaboo Bridge socket host model.
- Renamed automation “sessions” → “snapshots” across CLI output and APIs.
- Removed external MCP client support (`peekaboo mcp add/list/test/call/enable/disable` removed); `peekaboo mcp` now defaults to `serve`.
- CLI builds now target **macOS 15+**.

## Checksums

```
0ba82f82bfc489d44c794f2233b2a41495ddc97a5c81aa6235693031d6997a26  peekaboo-macos-arm64.tar.gz
228a37ff5e307a2322212ce63291dd2a2399a88982e5ff0c808be7fa89e6844d  steipete-peekaboo-3.0.0-beta2.tgz
```
