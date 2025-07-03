# Changelog

All notable changes to Peekaboo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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