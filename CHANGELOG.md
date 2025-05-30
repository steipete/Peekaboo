# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-beta.10] - 2025-01-27

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