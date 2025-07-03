# Changelog

All notable changes to Peekaboo CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive test suite with 331 tests achieving 100% pass rate
- Test coverage for all major components including configuration, file handling, error handling, and utility functions
- `flush()` method to Logger for better test synchronization

### Fixed
- All test failures through improved error handling and validation
- ImageSaver crash when paths contain invalid characters
- Logger race conditions in test environment
- PermissionErrorDetector now handles all relevant error domains
- Test isolation issues preventing interference between tests

### Changed
- Logger's `setJsonOutputMode` and `clearDebugLogs` methods are now synchronous for better reliability
- ApplicationFinder tests now correctly handle apps without windows

## [2.1.0] - 2025-01-03

### Added
- **Homebrew Distribution** - Install via `brew install steipete/tap/peekaboo` for easy installation and updates
- **Native AI Analysis** - Swift CLI can now analyze images directly using AI providers (OpenAI, Ollama) without Node.js
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
- **Improved Error Messages** - More descriptive errors for common issues like ambiguous app names
- **DocC Documentation** - Comprehensive API documentation for Swift codebase

### Changed
- **CLI Help Improvements** - Better organized help text following Unix conventions
- **Enhanced Permission Visibility** - Clear indicators when permissions are missing
- **Unified AI Provider Interface** - Consistent API for both OpenAI and Ollama providers

### Fixed
- Configuration precedence (CLI args > env vars > config file > defaults)
- SwiftLint violations across the codebase
- OllamaProvider tests with injected URLSession for better testability
- Various edge cases in error handling and file operations

## [2.0.0] - 2024-12-24

### Added
- **Standalone Swift CLI** - Complete rewrite in Swift for better performance and native macOS integration
- **MCP Server** - Model Context Protocol support for AI assistant integration
- **Multiple Capture Modes**:
  - Window capture (single or all windows)
  - Screen capture (main or specific display)
  - Frontmost window capture
  - Multi-window capture from multiple apps
- **AI Vision Analysis** - Analyze screenshots with OpenAI or Ollama
- **Configuration System** - Environment-based configuration with sensible defaults
- **PID Targeting** - Target applications by process ID with `PID:12345` syntax

### Changed
- Complete architecture redesign separating CLI and MCP server
- Improved performance with native Swift implementation
- Better error handling and permission management
- More intuitive command-line interface

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