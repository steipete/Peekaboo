## [3.1.0] - 2026-05-10

### Changed
- Refreshed the agent model catalog through Tachikoma: defaults now use GPT-5.5, Claude Opus 4.7, Gemini 3.1, latest Mistral, and Grok 4.3, while stale GPT-4.x/GPT-5.1/GPT-5.2, Claude 3.x, and old Grok IDs are rejected.
- Consolidated MCP installation docs into the main MCP page and removed stale standalone Claude Desktop and MCP best-practices pages from the docs site.
- Added docs-site agent metadata, social preview assets, and security discovery files, with GitHub links moved to the OpenClaw-owned repository. Thanks @williamclay8 for #115.
- Release automation now builds and uploads the signed, notarized Peekaboo.app zip by default, updates Sparkle appcast metadata, and accepts one-line App Store Connect API keys for notarization.
- Refined the macOS Settings window, menu bar popover header, and Playground chrome with denser native layout, clearer controls, and less debug noise.
- Fixed the macOS app's invisible settings helper window and refreshed the app icon artwork so Dock no longer shows a stray blank window or white icon backing.
- CLI automation commands now prefer a warm on-demand daemon for bursty use and route desktop observation through the daemon when supported, avoiding repeated process/service startup and large screenshot payloads over the Bridge socket.

### Performance
- Daemon-backed `peekaboo image`/MCP image calls now write screenshots inside the daemon and return lightweight metadata, making warm screenshot calls substantially faster and preventing large-image Bridge timeouts.
- Capture engine `auto` now tries CoreGraphics before ScreenCaptureKit for faster repeated screenshot calls while preserving explicit ScreenCaptureKit selection through `--capture-engine modern`.

