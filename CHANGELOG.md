# Changelog

## [Unreleased]

- _Nothing yet._

## [3.0.0-beta1] - 2025-11-25

### Added
- Tool allow/deny filters now log when a tool is hidden, including whether the rule came from environment variables or config, and tests cover the messaging.
- `peekaboo image --retina` captures at native HiDPI scale (2x on Retina) with scale-aware bounds in the capture pipeline, plus docs and tests to lock in the behavior.
- Peekaboo now inherits Tachikoma’s Azure OpenAI provider and refreshed model catalog (GPT‑5.1 family as default, updated Grok/Gemini 2.5 IDs), and the `tk-config` helper is exposed through the provider config flow for easier credential setup.
- Full GUI automation commands—`see`, `click`, `type`, `press`, `scroll`, `hotkey`, and `swipe`—now ship in the CLI with multi-screen capture so you can identify elements on any display and act on them without leaving the terminal.
- Natural-language AI agent flows (`peekaboo agent "…"` or simply `peekaboo "…"`) let you describe multi-step tasks in prose; the agent chains native tools, emits verbose traces, and supports low-level hotkeys when you need to fall back to precise control.
- Dedicated window management, multi-screen, and Spaces commands (`window`, `space`) give you scripted control over closing, moving, resizing, and re-homing macOS apps, including presets like left/right halves and cross-display moves.
- Menu tooling now enumerates every application menu plus system menu extras, enabling zero-click discovery of keyboard shortcuts and scripted menu activation via `menu list`, `menu list-all`, `menu click`, and `menu click-extra`.
- Automation sessions remember the most recent `see` run automatically, but you can also pin explicit session IDs and run `.peekaboo.json` scripts via `peekaboo run` to reproduce complex workflows with one command.
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

### Changed
- Provider configuration now prefers environment overrides while still loading stored credentials, matching the latest Tachikoma behavior and keeping CI/config files in sync.
- Commands invoked without arguments (for example `peekaboo agent` or `peekaboo see`) now print their detailed help, including argument/flag tables and curated usage examples, so it is obvious why input is required.
- CLI help output now hides compatibility aliases such as `--jsonOutput` while still documenting the primary short/long names (`-j`, `--json`), matching the new alias metadata exported by the Commander submodule.

### Fixed
- Menubar automation uses a bundled LSUIElement helper before CGS fallbacks, improving detection of menu extras on macOS 26+.
- Agent MCP tools (see/click/drag/type/scroll) default to the latest `see` session when none is pinned, so follow-up actions work without re-running `see`.
- MCP Responses image payloads are normalized (URL/base64) to align with the schema; manual testing guidance updated.
- Restored Playground target build on macOS 15 so local examples compile again.

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
