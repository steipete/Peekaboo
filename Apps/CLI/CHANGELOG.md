# Changelog

All notable changes to Peekaboo CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `peekaboo agent --model` now understands the GPT-5.1 identifiers and defaults to `gpt-5.1`, matching the latest OpenAI release while keeping backward-compatible aliases for GPT-5 and GPT-4o inputs.

### Fixed
- MCP `image` now returns an `isError: true` tool result when Screen Recording permission is missing instead of surfacing an internal server error.
- MCP `analyze` now honors configured AI providers and per-call `provider_config` models instead of hardcoding OpenAI GPT-5.1.
- Peekaboo.app now signs with the AppleEvents automation entitlement so macOS can prompt for Automation permission.
- The CLI bundle metadata and bundled Homebrew formula now advertise the macOS 15 minimum that the SwiftPM package already requires.
- `peekaboo see --annotate` now aligns labels using captured window bounds instead of guessing from the first detected element.
- Window capture on macOS 26 now resolves native Retina scale from `NSScreen.backingScaleFactor` before falling back to ScreenCaptureKit display ratios.
- `peekaboo image --app ... --window-title/--window-index` now captures the resolved window by stable window ID, avoiding mismatches between listed window indexes and ScreenCaptureKit window ordering.
- `peekaboo image --app ...` now prefers titled app windows over untitled helper windows, avoiding blank Chrome captures.
- `peekaboo image --capture-engine` is now accepted by Commander-based live parsing.
- Concurrent ScreenCaptureKit screenshot requests now queue through an in-process and cross-process capture gate instead of racing into continuation leaks or transient TCC-denied failures.
- Concurrent `peekaboo see` calls now queue the local screenshot/detection pipeline across processes, avoiding ReplayKit/ScreenCaptureKit continuation hangs under parallel usage.
- Natural-language automation examples now use `peekaboo agent "..."`.

### Performance
- `peekaboo image --app` avoids redundant application/window-count lookups during screenshot setup and skips auto-focus work when the target app is already frontmost.
- `peekaboo see --app` avoids re-focusing the target window when Accessibility already reports the captured window as focused.
- `peekaboo see` avoids recursive AX child-text lookups for elements whose labels cannot use them, reducing Playground element detection from about 201ms to 134ms in local testing.
- `peekaboo see` batches per-element Accessibility descriptor reads and skips avoidable action/editability probes, reducing local Playground element detection from about 205ms to 176ms.

## [2.0.2] - 2025-07-03

### Fixed
- Actually fixed compatibility with macOS Sequoia 26 by ensuring LC_UUID load command is generated during linking
- The v2.0.1 fix was incomplete - the binary was still missing LC_UUID despite the strip command change
- Added `-Xlinker -random_uuid` to Package.swift to ensure UUID generation
- Verified both x86_64 and arm64 architectures now contain proper LC_UUID load commands

## [2.0.1] - 2025-07-03

### Fixed
- Fixed compatibility with macOS Sequoia 26 (pre-release) by preserving LC_UUID load command during binary stripping
- The strip command now uses the `-u` flag to ensure the LC_UUID load command is retained, which is required by the dynamic linker (dyld) on macOS 26

### Technical Details
- Modified build script to use `strip -Sxu` instead of `strip -Sx` to preserve the LC_UUID load command
- This ensures the binary includes the necessary UUID for debugging, crash reporting, and symbol resolution on newer macOS versions

## [2.0.0] - 2025-07-03

### Added
- **Standalone Swift CLI** - Complete rewrite in Swift for better performance and native macOS integration
- **MCP Server** - Model Context Protocol support for AI assistant integration
- **Multiple Capture Modes**:
  - Window capture (single or all windows)
  - Screen capture (main or specific display)
  - Frontmost window capture
  - Multi-window capture from multiple apps
- **AI Vision Analysis** - Analyze screenshots with OpenAI or Ollama directly from Swift CLI
- **Configuration File Support** - JSONC format configuration at `~/.config/peekaboo/config.json` with:
  - Environment variable expansion (`${HOME}`, `${OPENAI_API_KEY}`)
  - Comments support for better documentation
  - Hierarchical settings for AI providers, defaults, and logging
- **Config Command** - New `peekaboo config` subcommand to manage configuration:
  - `config init` - Create default configuration file
  - `config show` - Display current configuration
  - `config edit` - Open configuration in default editor
  - `config validate` - Validate configuration syntax
- **Permissions Command** - New `peekaboo list permissions` to check system permissions
- **PID Targeting** - Target applications by process ID with `PID:12345` syntax
- **Homebrew Distribution** - Install via `brew install steipete/tap/peekaboo` for easy installation and updates
- **Comprehensive Test Suite** - 331 tests with 100% pass rate covering all major components
- **DocC Documentation** - Comprehensive API documentation for Swift codebase

### Changed
- Complete architecture redesign separating CLI and MCP server
- Improved performance with native Swift implementation
- Better error handling and permission management
- More intuitive command-line interface following Unix conventions
- Enhanced permission visibility with clear indicators when permissions are missing
- Unified AI provider interface for consistent API across OpenAI and Ollama
- Logger's `setJsonOutputMode` and `clearDebugLogs` methods are now synchronous for better reliability

### Fixed
- Configuration precedence (CLI args > env vars > config file > defaults)
- SwiftLint violations across the codebase
- ImageSaver crash when paths contain invalid characters
- Logger race conditions in test environment
- PermissionErrorDetector now handles all relevant error domains
- Test isolation issues preventing interference between tests
- Various edge cases in error handling and file operations

### Removed
- Node.js CLI (replaced with Swift implementation)
- Legacy screenshot methods

## [1.1.0] - 2024-12-20

### Added
- Initial TypeScript implementation
- Basic screenshot capabilities
- Simple MCP integration

### Changed
- Various bug fixes and improvements

## [1.0.0] - 2024-12-19

### Added
- Initial release
- Basic screenshot functionality
