# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-beta.15] - 2025-01-08

### Improved
- The `list` tool is now more lenient. `item_type` is optional and defaults to `running_applications`. If an `app` is specified without an `item_type`, it intelligently defaults to `application_windows`.

### Fixed
- Fixed a bug where the `list` tool would crash if called with an empty `item_type`.
- Fixed a bug where the `image` tool would fail silently if no path was provided, resulting in a generic "Failed to write file" error. The logic for handling temporary paths is now more robust.

## [1.0.0-beta.14] - 2025-01-08

### Added
- Enhanced test host application with real-time permission status display and CLI availability checking
- Comprehensive test coverage improvements with proper Swift Testing patterns
- Local test execution framework with detailed setup instructions

### Improved
- Swift code quality: Fixed all SwiftLint violations (reduced from 31 to 0 serious violations)
- Test stability: Resolved Swift test compilation errors and improved test reliability
- Code organization: Refactored ImageCommand.swift for better readability and maintainability
- Documentation: Enhanced CLAUDE.md and release documentation with proper testing procedures

### Fixed
- JSON encoding/decoding issues in tests by removing unnecessary snake_case conversions
- Window title validation expectations for system windows without titles
- Swift Testing syntax errors and compiler warnings
- Function and file length violations through strategic refactoring

## [1.0.0-beta.13] - 2025-01-08

### Added
- Comprehensive local-only test framework for testing actual screenshot functionality
- SwiftUI test host application for controlled testing environment
- Screenshot validation tests including content validation and visual regression
- Performance benchmarking tests for capture operations
- Multi-display capture tests
- Test infrastructure for permission dialog testing

### Improved
- The `list` tool with `item_type: 'running_applications'` now intelligently filters its results to only show applications that have one or more windows. This provides a cleaner, more relevant list for a screenshot utility by default, hiding background processes that have no user interface.
- Test coverage with local-only tests that can validate actual capture functionality
- Test organization with new tags: `localOnly`, `screenshot`, `multiWindow`, `focus`

### Fixed
- Fixed a bug where calling the `image` tool without any arguments would incorrectly result in a "Failed to write to file" error. The tool now correctly creates and uses a temporary file, returning the capture as Base64 data as intended.
- The `list` tool's input validation is now more lenient. It will no longer error when an empty `include_window_details: []` array is provided for an `item_type` other than `application_windows`.

## [1.0.0-beta.12] - 2025-01-08

### Added
- Comprehensive Swift Testing framework adoption with enhanced test coverage
- New test files for JSON output validation, logger thread safety, and image capture logic
- Centralized test tagging system for better test organization

### Improved
- CI/CD pipeline now uses macOS-15 runner with Xcode 16.3
- Swift CLI is now built before TypeScript tests to fix integration test failures
- Applied SwiftFormat to all Swift files for consistent code style
- Fixed all SwiftLint violations (31 issues resolved) achieving zero linting issues
- Enhanced thread safety in Logger implementation
- Optimized tests with parameterized testing and async/await patterns

### Fixed
- Fixed a bug where calling the `image` tool without a `path` argument would incorrectly result in a "Failed to write to file" error. The tool now correctly captures the image to a temporary location and returns the image data as Base64, as intended by the specification.
- Fixed Swift test compilation errors with proper Swift Testing syntax
- Fixed TypeScript test expectations after error message improvements
- Resolved CI integration test failures by ensuring Swift CLI availability

## [1.0.0-beta.11] - 2025-01-06

### Improved
- Greatly enhanced error handling for the `image` tool. The Swift CLI now returns distinct exit codes for different error conditions, such as missing Screen Recording or Accessibility permissions, instead of a generic failure code.
- The Node.js server now maps these specific exit codes to clear, user-friendly error messages, guiding the user on how to resolve the issue (e.g., "Screen Recording permission is not granted. Please enable it in System Settings...").
- This replaces the previous generic "Swift CLI execution failed" error, providing a much better user experience, especially during initial setup and permission granting.

## [1.0.0-beta.10] - 2024-07-28

### 🎉 Major Improvements
- **Full MCP Best Practices Compliance**: Implemented all requirements from the MCP best practices guide
- **Enhanced Info Command**: The `server_status` option in the list tool now provides comprehensive diagnostics including:
  - Native binary (Swift CLI) status and version
  - System permissions (screen recording, accessibility)
  - Environment configuration and potential issues
  - Log file accessibility checks
- **Dynamic Version Injection**: Swift CLI version is now automatically synchronized with package.json during build
- **Improved Code Quality**: 
  - Split large image.ts (472 lines) into smaller, focused modules (<250 lines each)
  - Added ESLint configuration with TypeScript support
  - Fixed all critical linting errors and reduced warnings
  - Improved TypeScript types throughout the codebase

### 🔧 Changed
- Default log path updated to `~/Library/Logs/peekaboo-mcp.log` (macOS standard location)
- Updated macOS requirement to v14+ (Sonoma) for better compatibility
- Pino logger now falls back to temp directory if configured path is not writable
- LICENSE and README.md now included in npm package

### 🐛 Fixed
- Swift CLI version synchronization with npm package
- ESLint errors for unused variables and improper types
- Test setup converted from Jest to Vitest syntax
- All trailing spaces and formatting issues

### 📦 Development
- Added Swift compiler warning checks in release preparation
- Enhanced prepare-release script with comprehensive validation
- Added `npm run inspector` for MCP inspector tool

## [1.0.0-beta.9] - 2025-01-25

### 🔧 Changed
- Updated server status formatting to improve readability

## [1.0.0-beta.3] - 2025-01-21

### Added
- Enhanced `image` tool to support optional immediate analysis of the captured screenshot by providing a `question` and `provider_config`.
  - If a `question` is given and no `path` is specified, the image is saved to a temporary location and deleted after analysis.
  - If a `question` is given, Base64 image data is not returned in the `content` array; the analysis result becomes the primary payload, alongside image metadata.

### Changed
- Migrated test runner from Jest to Vitest.
- Updated documentation (`README.md`, `docs/spec.md`) to reflect new `image` tool capabilities.

## [1.0.0-beta.2] - Previous Release Date

### Fixed
- (Summarize fixes from beta.2 if known, otherwise remove or mark as TBD)

### Added
- Initial E2E tests for CLI image capture. 

## [1.0.0-beta.8] - 2025-01-25

### 🔧 Changed
- Updated server status formatting

## [1.0.0-beta.7] - 2025-01-25

### 🔧 Changed
- Minor updates and improvements

## [1.0.0-beta.6] - 2025-01-25

### 📝 Changed
- Updated tool descriptions for better clarity

## [1.0.0-beta.5] - 2025-01-25

### 🔄 Changed
- Version bump for npm release (beta.4 was already published)

## [1.0.0-beta.4] - 2025-01-25

### ✨ Added
- Comprehensive Swift unit tests for all CLI components
- Release preparation script with extensive validation checks
- Swift code linting and formatting with SwiftLint and SwiftFormat
- Enhanced image tool with blur detection, custom formats (PNG/JPG), and naming patterns
- Robust error handling for Swift CLI integration

### 🐛 Fixed
- Swift CLI integration tests now properly handle error output
- Fixed Swift code to comply with SwiftLint rules
- Corrected JSON structure expectations in tests

### 📚 Changed
- Updated all dependencies to latest versions
- Improved test coverage for both TypeScript and Swift code
- Enhanced release process with automated checks
- Swift CLI `image` command: Added `--screen-index <Int>` option to capture a specific display when `--mode screen` is used
- MCP `image` tool: Now fully supports `app_target: "screen:INDEX"` by utilizing the Swift CLI's new `--screen-index` capability

### ♻️ Changed

- **MCP `image` tool API significantly simplified:**
    - Replaced `app`, `mode`, and `window_specifier` parameters with a single `app_target` string (e.g., `"AppName"`, `"AppName:WINDOW_TITLE:Title"`, `"screen:0"`).
    - `format` parameter now includes `"data"` option to return Base64 PNG data directly. If `path` is also given with `format: "data"`, file is saved (as PNG) AND data is returned.
    - If `path` is omitted, `image` tool now defaults to `format: "data"` behavior (returns Base64 PNG data).
    - `return_data` parameter removed (behavior now implied by `format` and `path`).
    - `provider_config` parameter removed. AI provider for analysis (when `question` is supplied) is now automatically selected from `PEEKABOO_AI_PROVIDERS` environment variable.
- **Node.js `imageToolHandler` and `buildSwiftCliArgs`:** Refactored to support the new `image` tool API and `--screen-index`.
- **Tests:** Unit and Integration tests for the `image` tool were extensively updated to reflect the API changes and new functionalities.

### 🐛 Fixed

- Addressed an issue in `src/tools/image.ts` where `logger.debug()` could be called without checking for logger existence (relevant for `buildSwiftCliArgs` if called in an unexpected context, though typically safe). 

### Added
- Add support for `PEEKABOO_DEFAULT_SAVE_PATH` to specify a default directory for saving images.
- The `list` tool now includes a `server_status` item type to retrieve server version and AI provider configuration.
- The server status is now appended to all tool descriptions on `ListToolsRequest`.
- Added comprehensive logging with `pino`, with log level and file path configurable via `PEEKABOO_LOG_LEVEL` and `PEEKABOO_LOG_FILE`.

### Changed
- The `image` tool's `path` argument is now optional. If omitted, the `format` defaults to `"data"` and the image is returned as a Base64 string.
- If an `image` capture is followed by a `question` for analysis and no `path` is given, a temporary file is created and deleted after analysis.

### Fixed
- Resolved an issue where the server could crash if the log file directory was not writable. It now falls back to a temporary directory.
- Ensured the `peekaboo` Swift CLI binary is correctly located when the package is installed globally or used via `npx`. 