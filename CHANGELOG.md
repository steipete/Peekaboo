# Changelog

## [Unreleased]

### Added
- `peekaboo clipboard` now supports `--verify` to read back clipboard writes after `set`/`load`.
- `peekaboo see --menubar` captures active menu bar popovers via window list + OCR, tries opening the specified menu extra when `--app` is set, and falls back to OCR-only menu bar captures when no popover window is detected.
- `peekaboo menubar click --verify` validates menu bar clicks by popover owner PID or any visible owner window (OCR fallback enabled by default; AX checks opt-in).
- `peekaboo menubar click --verify` now also detects focused-window changes when a menu bar app opens a settings window.
- `peekaboo dock launch --verify`, `peekaboo window focus --verify`, and `peekaboo app switch --verify` add lightweight post-action checks.
- `peekaboo menu click-extra --verify` adds the same popover/window verification as `menubar click --verify`.
- AX element detection now caches per-window AX traversals for ~1.5s to reduce repeated `see` thrash.
- Screen/area captures now default to a persistent ScreenCaptureKit stream and log wait + frame-age timings for profiling.

### Fixed
- Menu bar extras now combine CGWindow data with AX fallbacks to surface third-party items like Trimmy, and clicks target the owning window for reliability.
- Menu bar extras now hydrate missing owner PIDs from running app metadata to improve open-menu detection.
- Menu bar popover selection now prefers owner-name matches and X-position hints to avoid mismatched popovers.
- Menu bar open-menu probing now returns AX menu frames over the bridge to support popover captures.
- Menu bar screenshot captures now use the real menu bar height derived from the screen’s visible frame.
- Clipboard text writes now publish both `public.plain-text` and `.string` (`public.utf8-plain-text`) across CLI, MCP tools, paste, and script runs.
- `peekaboo see --menubar` now attempts an OCR area fallback after auto-clicking a menu extra even when the open-menu AX state is missing.
- Menu bar click verification now detects popovers in both top-left and bottom-left coordinate systems.
- Menu bar click verification now requires OCR text to include the target title/owner name when falling back to OCR (set `PEEKABOO_MENUBAR_OCR_VERIFY=0` to disable).
- Menu bar popover selection now relaxes owner-PID filtering when the app hint doesn't match any candidate, reducing wrong-window OCR captures.
- Menu bar popover OCR area/frame fallbacks now validate against app hints before accepting a capture.

## [3.0.0-beta3] - Unreleased

## [3.0.0-beta2] - 2025-12-19

### Highlights
- **Socket-based Peekaboo Bridge**: privileged automation runs in a long-lived **bridge host** (Peekaboo.app, or another signed host like Clawdis.app) and the CLI connects over a UNIX socket (replacing the v3.0.0-beta1 XPC helper model).
- **Snapshots replace sessions**: snapshots live in memory by default, are scoped **per target bundle ID**, and are reused automatically for follow-up actions (agent-friendly; fewer IDs to plumb around).
- **MCP server-only**: Peekaboo still runs as an MCP server for Claude Desktop/Cursor/etc, but no longer hosts/manages external MCP servers.
- **Reliability upgrades for “single action” automation**: hard wall-clock timeouts and bounded AX traversal to prevent hangs.
- **Visualizer extracted + stabilized**: overlay UI lives in `PeekabooVisualizer`, with improved preview timings and less clipping.

### Breaking
- Removed the v3.0.0-beta1 XPC helper pathway; remote execution now uses the **Peekaboo Bridge** socket host model.
- Renamed automation “sessions” → “snapshots” across CLI output, cache/paths, and APIs.
- Removed external MCP client support (`peekaboo mcp add/list/test/call/enable/disable` removed); `peekaboo mcp` now defaults to `serve`, and `mcpClients` configuration is no longer supported.
- CLI builds now target **macOS 15+**.

### Added
- `peekaboo paste`: set clipboard content, paste (Cmd+V), then restore the prior clipboard (text, files/images, base64 payloads).
- Deterministic window targeting via `--window-id` to avoid title/index ambiguity.
- `peekaboo bridge status` diagnostics for host selection/handshake/security; plus runtime controls `--bridge-socket` and `--no-remote`.
- Bridge security: caller validation via **code signature TeamID allowlist** (and optional bundle allowlist), with a **debug-only** same-UID escape hatch (`PEEKABOO_ALLOW_UNSIGNED_SOCKET_CLIENTS=1`).
- `peekaboo hotkey` accepts the key combo as a positional argument (in addition to `--keys`) for quick one-liners like `peekaboo hotkey "cmd,shift,t"`.
- `peekaboo learn` renders its guide as ANSI-styled markdown on rich terminals, while still emitting plain markdown when piped.
- Agent providers now include `gemini-3-flash`, expanding the out-of-the-box model catalog for `peekaboo agent`.
- Agent streaming loop now injects `DESKTOP_STATE` (focused app/window title, cursor position, and clipboard preview when the `clipboard` tool is enabled) as untrusted, delimited context to improve situational awareness.
- Peekaboo’s macOS app now surfaces About/Updates inside Settings (Sparkle update checks when signed/bundled).

### Changed
- Bridge host discovery order is now: **Peekaboo.app → Clawdis.app → local in-process** (no auto-launch).
- Capture defaults favor the classic engine for speed/reliability, with explicit capture-engine flags when you need SCKit behavior.
- Agent defaults now prefer Claude Opus 4.5 when available, with improved streaming output for supported providers.
- OpenAI model aliases now map to the latest GPT-5.1 variants for `peekaboo agent`.

### Fixed
- ScreenCaptureKit window capture no longer returns black frames for GPU-rendered windows (notably iOS Simulator), and display-bound crops now use display-local `sourceRect` coordinates on secondary monitors.
- `peekaboo see` is now bounded for “single action” use (10s wall-clock timeout without `--analyze`), and timeouts surface as `TIMEOUT` exit codes instead of silent hangs.
- Dialog file automation is more reliable: can force “Show Details” (`--ensure-expanded`) and verifies the saved path when possible.
- `peekaboo dialog` subcommands now expose the full interaction targeting + focus options (Commander parity).
- App resolution now prioritizes exact name matches over bundleID-contains matches, preventing `--app Safari` from accidentally matching helper processes with “Safari” in their bundle ID.
- UI element detection enforces conservative traversal limits (depth/node/child caps) plus a detection deadline, making runaway AX trees safe.
- Listing apps via a bridge no longer risks timing out: window counts now use CGWindowList instead of per-app AX enumeration.
- Visualizer previews now respect their full duration before fading out; overlays no longer disappear in ~0.3s regardless of requested timing.
- `peekaboo image`: infer output encoding from `--path` extension when `--format` is omitted, and reject conflicting `--format` vs `--path` extension values.
- `peekaboo image --analyze`: Ollama vision models are now supported.
- `peekaboo click --coords` no longer crashes on invalid input; invalid coordinates now fail with a structured validation error.
- Auto-focus no longer no-ops when a snapshot is missing a `windowID`, preventing follow-up actions from landing in the wrong frontmost app.
- `peekaboo window list` no longer returns duplicate entries for the same window.
- `peekaboo capture live` avoids window-index mismatches that could attach to the wrong window when multiple candidates are present.
- Bridge hosts that reject the CLI now reply with a structured `unauthorizedClient` error response instead of closing the socket (EOF), and the CLI error message includes actionable guidance for older hosts.

## [3.0.0-beta1] - 2025-11-25

### Added
- Tool allow/deny filters now log when a tool is hidden, including whether the rule came from environment variables or config, and tests cover the messaging.
- `peekaboo image --retina` captures at native HiDPI scale (2x on Retina) with scale-aware bounds in the capture pipeline, plus docs and tests to lock in the behavior.
- Peekaboo now inherits Tachikoma’s Azure OpenAI provider and refreshed model catalog (GPT‑5.1 family as default, updated Grok/Gemini 2.5 IDs), and the `tk-config` helper is exposed through the provider config flow for easier credential setup.
- Full GUI automation commands—`see`, `click`, `type`, `press`, `scroll`, `hotkey`, and `swipe`—now ship in the CLI with multi-screen capture so you can identify elements on any display and act on them without leaving the terminal.
- Natural-language AI agent flows (`peekaboo agent "…"` or simply `peekaboo "…"`) let you describe multi-step tasks in prose; the agent chains native tools, emits verbose traces, and supports low-level hotkeys when you need to fall back to precise control.
- Dedicated window management, multi-screen, and Spaces commands (`window`, `space`) give you scripted control over closing, moving, resizing, and re-homing macOS apps, including presets like left/right halves and cross-display moves.
- Menu tooling now enumerates every application menu plus system menu extras, enabling zero-click discovery of keyboard shortcuts and scripted menu activation via `menu list`, `menu list-all`, `menu click`, and `menu click-extra`.
- Automation snapshots remember the most recent `see` run automatically, but you can also pin explicit snapshot IDs and run `.peekaboo.json` scripts via `peekaboo run` to reproduce complex workflows with one command.
- Rounded out the CLI command surface so every capture, interaction, and maintenance workflow is first-class: `image`, `list`, `tools`, `config`, `permissions`, `learn`, `run`, `sleep`, and `clean` cover capture/config glue, while `window`, `app`, `dock`, `dialog`, `space`, `menu`, and `menubar` provide window, app, and UI chrome management alongside the previously mentioned automation commands.
- `peekaboo see --json-output` now includes `description`, `role_description`, and `help` fields for every `ui_elements[]` entry so toolbar icons (like the Wingman extension) and other AX-only descriptions can be located without blind coordinate clicks.
- GPT-5.1, GPT-5.1 Mini, and GPT-5.1 Nano are now fully supported across the CLI, macOS app, and MCP bridge. `peekaboo agent` defaults to `gpt-5.1`, the app’s AI settings expose the new variants, and all MCP tool banners reflect the upgraded default.

### Integrations
- Peekaboo runs as both an MCP server and client: it still exposes its native tools to Claude/Cursor, but v3 now ships the Chrome DevTools MCP by default and lets you add or toggle external MCP servers (`peekaboo mcp list/add/test/enable/disable`), so the agent can mix native Mac automation with remote browser, GitHub, or filesystem tools in a single session.

### Developer Workflow
- Added `pnpm` shortcuts for common Swift workflows (`pnpm build`, `pnpm build:cli:release`, `pnpm build:polter`, `pnpm test`, `pnpm test:automation`, `pnpm test:all`, `pnpm lint`, `pnpm format`) so command names match what ships in release docs and both humans and agents rely on the same entry points.
- Automation test suites now launch the freshly built `.build/debug/peekaboo` binary via `CLITestEnvironment.peekabooBinaryURL()` and suppress negative parsing noise, making CI logs far easier to scan.
- Documented the safe vs. automation tagging convention and the new command shorthands inside `docs/swift-testing-playbook.md`, so contributors know exactly which suites to run before tagging.
- `AudioInputService` now relies on Swift observation (`@Observable`) plus structured `Task.sleep` polling instead of Combine timers, keeping v3’s audio capture aligned with Swift 6.2’s concurrency expectations.
- CLI `tools` output now uses `OrderedDictionary`, guaranteeing the same ordering every time you list tools or dump JSON so copy/paste instructions in the README stay accurate.
- Removed the Gemini CLI reusable workflow from CI to eliminate an external check that was blocking pull requests when no Gemini credentials are configured.

### Changed
- Provider configuration now prefers environment overrides while still loading stored credentials, matching the latest Tachikoma behavior and keeping CI/config files in sync.
- Commands invoked without arguments (for example `peekaboo agent` or `peekaboo see`) now print their detailed help, including argument/flag tables and curated usage examples, so it is obvious why input is required.
- CLI help output now hides compatibility aliases such as `--jsonOutput` while still documenting the primary short/long names (`-j`, `--json`), matching the new alias metadata exported by the Commander submodule.

### Fixed
- `peekaboo capture video` positional input now binds correctly through Commander, preventing “missing input” runtime errors; binder and parsing tests cover the regression.
- Menubar automation uses a bundled LSUIElement helper before CGS fallbacks, improving detection of menu extras on macOS 26+.
- Agent MCP tools (see/click/drag/type/scroll) default to the latest `see` session when none is pinned, so follow-up actions work without re-running `see`.
- MCP Responses image payloads are normalized (URL/base64) to align with the schema; manual testing guidance updated.
- Restored Playground target build on macOS 15 so local examples compile again.
- `peekaboo capture video --sample-fps` now reports frame timestamps from the video timeline (not session wall-clock), fixing bunched `t=XXms` outputs and aligning `metadata.json`; regression test added.
- `peekaboo capture video` now advertises and binds its required input video file in Commander help/registry, preventing missing-input crashes; binder and program-resolution tests cover the regression.
- Anthropic OAuth token exchange now uses standards-compliant form encoding, fixing 400 responses during `peekaboo config login anthropic`; regression test added.
- `peekaboo see --analyze` now honors `aiProviders.providers` when choosing the default model instead of always defaulting to OpenAI; coverage added for configured defaults.
- Added more coverage to ensure AI provider precedence honors provider lists, Anthropic-only keys, and empty/default fallbacks.
- Visualizer “Peekaboo.app is not running” notice now only appears with verbose logging, keeping default runs quieter.
- Visualizer console output is now suppressed unless verbose-level logging is explicitly requested (or forced via `PEEKABOO_VISUALIZER_STDOUT`), preventing non-verbose runs from emitting visualizer chatter.

## [2.0.3] - 2025-07-03

### Fixed
- Fixed `--version` output to include "Peekaboo" prefix for Homebrew formula compatibility
- Now outputs "Peekaboo 2.0.3" instead of just "2.0.3"

## [2.0.2] - 2025-07-03

### Fixed
- Actually fixed compatibility with macOS Sequoia 26 by ensuring LC_UUID load command is generated during linking
- The v2.0.1 fix was incomplete - the binary was still missing LC_UUID
- Verified both x86_64 and arm64 architectures now contain proper LC_UUID load commands

## [2.0.1] - 2025-07-03

### Fixed
- Fixed compatibility with macOS Sequoia 26 (pre-release) by preserving LC_UUID load command during binary stripping

## [2.0.0] - 2025-07-03

### 🎉 Major Features

#### Standalone AI Analysis in CLI
- **Added native AI analysis capability directly to Swift CLI** - analyze images without the MCP server
- Support for multiple AI providers: OpenAI GPT-4 Vision and local Ollama models
- Automatic provider selection and fallback mechanisms
- Perfect for automation, scripts, and CI/CD pipelines
- Example: `peekaboo analyze screenshot.png "What error is shown?"`

#### Configuration File System
- **Added comprehensive JSONC (JSON with Comments) configuration file support**
- Location: `~/.config/peekaboo/config.json`
- Features:
  - Persistent settings across terminal sessions
  - Environment variable expansion using `${VAR_NAME}` syntax
  - Comments support for better documentation
  - Tilde expansion for home directory paths
- New `config` subcommand with init, show, edit, and validate operations
- Configuration precedence: CLI args > env vars > config file > defaults

### 🚀 Improvements

#### Enhanced CLI Experience
- **Completely redesigned help system following Unix conventions**
  - Examples shown first for better discoverability
  - Clear SYNOPSIS sections
  - Common workflows documented
  - Exit status codes for scripting
- **Added standalone CLI build script** (`scripts/build-cli-standalone.sh`)
  - Build without npm/Node.js dependencies
  - System-wide installation support with `--install` flag

#### Code Quality
- Added comprehensive test coverage for AI analysis functionality
- Fixed all SwiftLint violations
- Improved error handling and user feedback
- Better code organization and maintainability

### 📝 Documentation

- Added configuration file documentation to README
- Expanded CLI usage examples
- Documented AI analysis capabilities
- Added example scripts and automation workflows
- Removed outdated tool-description.md

### 🔧 Technical Changes

- Migrated from direct environment variable usage to ConfigurationManager
- Implemented proper JSONC parser with comment stripping
- Added thread-safe configuration loading
- Improved Swift-TypeScript interoperability

### 💥 Breaking Changes

- Version bump to 2.0 reflects the significant expansion from MCP-only to dual CLI/MCP tool
- Configuration file takes precedence over some environment variables (but maintains backward compatibility)

### 🐛 Bug Fixes

- Fixed ArgumentParser command structure for proper subcommand execution
- Resolved configuration loading race conditions
- Fixed help text display issues

### ⬆️ Dependencies

- Swift ArgumentParser 1.5.1
- Maintained all existing npm dependencies

## [1.1.0] - Previous Release

- Initial MCP server implementation
- Basic screenshot capture functionality
- Window and application listing
- Integration with Claude Desktop and Cursor IDE
