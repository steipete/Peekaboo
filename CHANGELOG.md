# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-01-08

### 🎉 First Stable Release

Peekaboo MCP is now production-ready! This release marks the culmination of extensive development, testing, and refinement to create a robust macOS screen capture and window management tool for AI agents.

### Key Features
- **Advanced Screen Capture**: Capture entire screens, specific windows, or all windows of an application
- **AI-Powered Image Analysis**: Analyze captured or existing images using multiple AI providers (Ollama, OpenAI)
- **Window Management**: List running applications and their windows with detailed metadata
- **Flexible Output Options**: Save to file or return Base64-encoded data inline
- **Swift 6 Compatibility**: Fully migrated to Swift 6 with strict concurrency for maximum reliability
- **Universal Binary**: Supports both Apple Silicon and Intel Macs

### Recent Improvements (from beta releases)
- Fixed critical MCP server error handling for edge cases
- Complete Swift 6 migration with proper async/await patterns
- Enhanced error messages and debugging capabilities
- Improved window matching with fuzzy search
- Better handling of multi-display setups
- Robust permission handling for Screen Recording and Accessibility

### Requirements
- macOS 14.0 or later (Sonoma)
- Node.js 18 or later
- Screen Recording permission (for capture features)
- Accessibility permission (optional, for foreground window detection)

### Getting Started
```bash
npm install -g @steipete/peekaboo-mcp
```

For detailed documentation, visit: https://github.com/steipete/Peekaboo

## [1.0.0-beta.25] - 2025-01-08

### Fixed
- **Critical MCP server error handling**
  - Fixed issue where unexpected errors would cause "No result received" response
  - All tool execution errors now return proper MCP error responses
  - Handles edge cases with special characters in tool parameters gracefully
  - Prevents server from silently failing on unexpected exceptions

## [1.0.0-beta.24] - 2025-01-08

### Changed
- **Complete Swift 6 migration with strict concurrency**
  - Migrated to Swift 6.0 toolchain with StrictConcurrency enabled
  - All data models and types now conform to Sendable protocol
  - Replaced AsyncParsableCommand with ParsableCommand + async adapter pattern
  - Implemented proper async/sync bridging using DispatchSemaphore for ArgumentParser compatibility
  - Fixed CLI execution issue where commands were showing help instead of executing

### Improved
- Enhanced thread safety with @unchecked Sendable for synchronized state
- Better separation of concerns between async operations and CLI interface
- More robust error handling in async contexts

## [1.0.0-beta.23] - 2025-01-08

### Changed
- Initial Swift 6 migration attempt (had execution issues, fixed in beta.24)

## [1.0.0-beta.22] - 2025-01-08

### Fixed
- **Critical deadlock fix in Swift CLI image capture**
  - Removed DispatchSemaphore usage that violated Swift concurrency rules and caused infinite hangs
  - Implemented RunLoop-based async-to-sync bridging for proper concurrency handling
  - Converted all capture methods to async/await patterns while maintaining CLI compatibility
  - Replaced Thread.sleep with Task.sleep in async contexts
  - Fixed test timeouts by eliminating blocking operations
  - No macOS version requirements added - solution uses standard Foundation APIs

### Added
- **Smart browser helper filtering for improved Chrome/Safari matching**
  - Automatically filters out browser helper processes when searching for common browsers (chrome, safari, firefox, edge, brave, arc, opera)
  - Prevents confusing "no capturable windows" errors when helper processes like "Google Chrome Helper (Renderer)" are matched instead of the main browser
  - Provides browser-specific error messages: "Chrome browser is not running or not found" instead of generic app not found errors
  - Only applies filtering to browser identifiers - other application searches work normally
  - Comprehensive test coverage for browser filtering scenarios

- **Proper frontmost window capture implementation**
  - Added dedicated `frontmost` capture mode that captures the frontmost window of the frontmost application
  - Replaces previous fallback behavior that incorrectly captured all screens
  - Uses `NSWorkspace.shared.frontmostApplication` to detect the currently active application
  - Returns exactly one image with proper metadata (app name, window title, window ID)
  - Generates descriptive filenames like `frontmost_Safari_20250608_083230.png`

### Fixed
- **List tool empty string parameter handling**
  - Fixed issue where `item_type: ""` was not properly defaulting to the correct operation
  - Empty strings and whitespace-only strings now fall back to proper default logic
  - Added comprehensive test coverage for edge cases

## [1.0.0-beta.21] - 2025-06-08

### Security
- **Critical security fix for malformed app targets**
  - Fixed vulnerability where malformed app targets with multiple leading colons (e.g., "::::::::::::::::Finder") created empty app names that would match ALL system processes
  - Enhanced input validation to prevent unintended broad process matching
  - Added defensive parsing logic with fallback to screen mode for invalid inputs
  - Comprehensive test coverage for edge cases and malformed inputs

### Changed
- **Multiple exact app matches now capture all windows instead of erroring**
  - When multiple applications have exact matches (e.g., "claude" and "Claude"), the system now captures all windows from all matching applications
  - This replaces the previous behavior of throwing an ambiguous match error
  - Window indices are sequential across all matched applications
  - Each saved file preserves the original application name in `item_label`
  - Only truly ambiguous fuzzy matches still return errors
  - Comprehensive test coverage for various multiple match scenarios

### Fixed
- **Enhanced error handling and user experience**
  - Improved window title matching error messages with available window titles and URL guidance
  - Fixed path traversal error reporting to show correct file system errors instead of permission errors
  - Added case-insensitive handling for window specifiers (WINDOW_TITLE, window_title, etc.)
  - Enhanced backward compatibility with hidden path parameters in analyze tool
- **Format validation improvements**
  - Added defensive format validation with automatic PNG fallback for invalid formats
  - Improved file extension correction when format is changed
  - Better handling of edge cases in image processing

## [1.0.0-beta.20] - 2025-06-08

### Added
- **Window count display optimization**: Single-window apps no longer show "Windows: 1" in list output ([#6](https://github.com/steipete/Peekaboo/pull/6))
  - Reduces visual clutter for the common case of apps with only one window
  - Apps with 0, 2, or more windows still display the count
  - Improves readability of the `list apps` command output
- **Timeout handling for Swift CLI operations** ([#2](https://github.com/steipete/Peekaboo/pull/2))
  - Prevents test suite and operations from hanging indefinitely
  - Default timeout of 30 seconds, configurable via `PEEKABOO_CLI_TIMEOUT` environment variable
  - Graceful process termination with SIGTERM followed by SIGKILL if needed
  - Clear timeout error messages indicating when operations exceed time limits

### Fixed
- **Input validation improvements**:
  - Whitespace is now trimmed from `app_target` parameter (e.g., `"   Spotify   "` now works correctly)
  - Format parameter is now case-insensitive (`"PNG"` and `"png"` both work)
  - Added support for `"jpeg"` as an alias for `"jpg"` format
- **Edge case handling**:
  - Float and hex screen indices now parse correctly (e.g., `screen:1.5` → `screen:1`, `screen:0x1` → `screen:0`)
  - Special filesystem characters (|, :, *) in filenames are preserved as-is
  - Empty questions to analyze tool are handled gracefully (analysis is skipped)
- **Swift error handling improvements**:
  - Fixed CaptureError enum compatibility issues in tests
  - Improved error messages with better context for ApplicationFinder errors
- Fixed overly broad permission error detection that incorrectly reported file I/O errors as screen recording permission issues
  - File permission errors (e.g., writing to `/System/`) now correctly report as `FILE_IO_ERROR`
  - Directory not found errors provide clear messages about missing parent directories
  - Added specific error code checking for ScreenCaptureKit and CoreGraphics APIs
  - Only errors containing both "permission" and capture-related terms are now considered screen recording issues
- Enhanced file write error handling with pre-emptive directory checks
- Added debug logging to permission checker for diagnosing intermittent failures
- Improved error propagation from deep system APIs
  - Underlying errors from ScreenCaptureKit and file operations are now captured and logged
  - Debug logs include full error details for better troubleshooting
  - Error messages include the original system error descriptions
- Fixed duplicate error output when ApplicationFinder throws errors
- Enhanced error details for app not found errors to include list of available applications
- Removed complex multi-JSON parsing logic from TypeScript that was only needed due to duplicate error output
- Fixed all test assertions to match the new `executeSwiftCli` signature with timeout parameter

## [1.0.0-beta.19] - 2025-06-08

### Added
- Automatic format fallback for screen captures to prevent JavaScript stack overflow errors
  - When `format: "data"` is specified for screen captures, the tool automatically falls back to PNG format
  - A warning message is included in the response explaining why the fallback occurred
  - Application window captures can still use `format: "data"` without restrictions
  - This prevents agents from encountering "Maximum call stack size exceeded" errors when capturing screens
- Invalid format values now automatically fall back to PNG instead of returning an error
  - Empty strings, null values, and unrecognized format values are converted to PNG
  - This provides a better user experience by gracefully handling invalid inputs
- Enhanced error messages for ambiguous application identifiers
  - When multiple applications match an identifier (e.g., "C" matches Calendar, Console, and Cursor), the error message now lists all matching applications with their bundle IDs
  - This helps users quickly identify the correct application name to use
  - Applies to both `image` and `list` tools

## [1.0.0-beta.18] - 2025-06-08

### Added
- Fuzzy matching for application names using Levenshtein distance algorithm
  - Typos like "Chromee" now correctly match "Google Chrome"
  - Common misspellings are handled intelligently (e.g., "Finderr" → "Finder")
  - Multi-word app names are matched word-by-word for better accuracy
- Smart error messages that suggest similar app names when no exact match is found
- Window-specific labels in analysis results when capturing multiple windows
  - Shows window titles instead of repeating app names
  - Example: 'Analysis for "MCP Inspector":' instead of "Analysis for Google Chrome"

### Fixed
- Error messages now show specific details instead of generic "unknown error"
  - Non-existent apps show: "No running applications found matching identifier: AppName"
  - Properly parses Swift CLI JSON error responses
- Fixed test failures related to error message format changes

### Changed
- Improved application matching scoring to prefer main apps over helper processes
- Enhanced TypeScript error handling to parse JSON responses even on non-zero exit codes

## [1.0.0-beta.21] - 2025-01-10

### Fixed
- The `list` tool no longer returns a generic "unknown error" when a non-existent `app` is specified. It now returns a clear error message: `"List operation failed: The specified application ('AppName') is not running or could not be found."`, improving usability and error diagnosis.

## [1.0.0-beta.20] - 2025-01-09

### Changed
- Improved error message for the `image` tool. When an `app_target` is specified for a running application that has no visible windows, the tool now returns a specific error (`"Image capture failed: The 'AppName' process is running, but it has no capturable windows..."`) instead of a generic "window not found" error. This provides clearer feedback and suggests using `capture_focus: 'foreground'` as a remedy.

## [1.0.0-beta.19] - 2025-01-08

### Changed
- The `image` tool's behavior has been updated. When a `question` is provided for analysis and no `path` is specified, the tool now preserves the captured image(s) in their temporary directory instead of deleting them. The paths to these saved files are now correctly returned in the `saved_files` array, making them accessible after the tool run completes.

## [1.0.0-beta.18] - 2025-01-08

### Fixed
- Fixed a bug where providing an empty string for the `capture_focus` parameter in the `image` tool would cause a validation error. The schema now correctly handles this case and applies the default value ('background'), making the parameter truly optional.

## [1.0.0-beta.17] - 2025-01-08

### Added
- The `image` tool's analysis capability has been significantly enhanced. When a capture results in multiple images (e.g., targeting an application with multiple windows) and a `question` is provided, the tool will now perform an AI analysis for **every single captured image**.
- The analysis results are returned in a single, clearly formatted text block, with each window's analysis presented under a descriptive header.

## [1.0.0-beta.16] - 2025-01-08

### Enhanced
- **Smart Path Handling**: The Swift CLI now intelligently detects whether a provided path is intended as a file or directory:
  - **File paths** (with extensions): Uses exact path for single screen captures, appends screen identifiers for multiple captures
  - **Directory paths** (no extension or trailing `/`): Places generated filenames inside the directory
  - **Auto-Creation**: Automatically creates intermediate directories as needed for both file and directory paths
  - **Edge Cases**: Properly handles special directory indicators (`.`, `..`), hidden files, unicode characters, and paths with spaces

### Improved
- **Enhanced Error Messages**: File write errors now provide detailed, actionable guidance:
  - Permission denied errors include specific directory permission checks
  - Missing directory errors suggest ensuring parent directories exist  
  - Disk space errors clearly indicate insufficient storage
  - Generic I/O errors include underlying system error details

### Added
- **Comprehensive Test Coverage**: Added 52+ new tests covering path handling, error scenarios, and edge cases
- **Path Logic Validation**: Tests for file vs directory detection, multiple format support, and special character handling

### Fixed
- Fixed original issue where `/tmp/screenshot.png` was incorrectly treated as a directory instead of a filename
- Improved file extension preservation when appending screen/window identifiers to filenames
- Enhanced path validation for complex nested directory structures

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
    - `