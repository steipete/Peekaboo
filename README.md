# Peekaboo MCP: Lightning-fast macOS Screenshots 🚀

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D20.0.0-brightgreen.svg)](https://nodejs.org/)

Peekaboo is a powerful macOS utility for capturing screenshots and analyzing them with AI vision models. It works both as a **standalone CLI tool** (recommended) and as an **MCP server** for AI assistants like Claude Desktop and Cursor.

## 🎯 Choose Your Path

### 🖥️ **CLI Tool** (Recommended for Most Users)
Perfect for:
- Command-line workflows and automation
- Shell scripts and CI/CD pipelines  
- Quick screenshots and AI analysis
- System administration tasks

### 🤖 **MCP Server** (For AI Assistants)
Perfect for:
- Claude Desktop integration
- Cursor IDE workflows
- AI agents that need visual context
- Interactive AI debugging sessions

## What is Peekaboo?

Peekaboo bridges the gap between visual content on your screen and AI understanding. It provides:

- **Lightning-fast screenshots** of screens, applications, or specific windows
- **AI-powered image analysis** using GPT-4 Vision, Claude, or local models
- **Window and application management** with smart fuzzy matching
- **Privacy-first operation** with local AI options via Ollama
- **Non-intrusive capture** without changing window focus

## 🚀 Quick Start: CLI Tool

### Installation

```bash
# Option 1: Homebrew (Recommended)
brew tap steipete/tap
brew install peekaboo

# Option 2: Direct Download
curl -L https://github.com/steipete/peekaboo/releases/latest/download/peekaboo-macos-universal.tar.gz | tar xz
sudo mv peekaboo-macos-universal/peekaboo /usr/local/bin/

# Option 3: npm (includes MCP server)
npm install -g @steipete/peekaboo-mcp

# Option 4: Build from source
git clone https://github.com/steipete/peekaboo.git
cd peekaboo
./scripts/build-cli-standalone.sh --install
```

### Basic Usage

```bash
# Capture screenshots
peekaboo image --app Safari --path screenshot.png
peekaboo image --mode frontmost
peekaboo image --mode screen --screen-index 0

# List applications and windows
peekaboo list apps
peekaboo list windows --app "Visual Studio Code"

# Analyze images with AI
peekaboo analyze screenshot.png "What error is shown?"
peekaboo analyze ui.png "Find all buttons" --provider ollama

# Configure settings
peekaboo config init                    # Create config file
peekaboo config edit                    # Edit in your editor
peekaboo config show --effective        # Show current settings
```

### Configuration

Create a persistent configuration file at `~/.config/peekaboo/config.json`:

```bash
peekaboo config init
```

Example configuration:
```json
{
  // AI Provider Settings
  "aiProviders": {
    "providers": "openai/gpt-4o,ollama/llava:latest",
    "openaiApiKey": "${OPENAI_API_KEY}",  // Supports env var expansion
    "ollamaBaseUrl": "http://localhost:11434"
  },
  
  // Default Settings
  "defaults": {
    "savePath": "~/Desktop/Screenshots",
    "imageFormat": "png",
    "captureMode": "window",
    "captureFocus": "auto"
  }
}
```

### Common Workflows

```bash
# Capture and analyze in one command
peekaboo image --app Safari --path /tmp/page.png && \
  peekaboo analyze /tmp/page.png "What's on this page?"

# Monitor active window changes
while true; do
  peekaboo image --mode frontmost --json-output | jq -r '.data.saved_files[0].window_title'
  sleep 5
done

# Batch analyze screenshots
for img in ~/Screenshots/*.png; do
  peekaboo analyze "$img" "Summarize this screenshot"
done
```

## 🤖 MCP Server Setup

For AI assistants like Claude Desktop and Cursor, Peekaboo provides a Model Context Protocol (MCP) server.

### For Claude Desktop

Edit your Claude Desktop configuration:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": ["-y", "@steipete/peekaboo-mcp"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "openai/gpt-4o,ollama/llava:latest",
        "OPENAI_API_KEY": "your-openai-api-key-here"
      }
    }
  }
}
```

### For Cursor IDE

Add to your Cursor settings:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": ["-y", "@steipete/peekaboo-mcp"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "openai/gpt-4o,ollama/llava:latest",
        "OPENAI_API_KEY": "your-openai-api-key-here"
      }
    }
  }
}
```

### MCP Tools Available

1. **`image`** - Capture screenshots
2. **`list`** - List applications, windows, or check status
3. **`analyze`** - Analyze images with AI vision models

## 🔧 Configuration

### Configuration Precedence

Settings follow this precedence (highest to lowest):
1. Command-line arguments
2. Environment variables
3. Configuration file (`~/.config/peekaboo/config.json`)
4. Built-in defaults

### Available Options

| Setting | Config File | Environment Variable | Description |
|---------|-------------|---------------------|-------------|
| AI Providers | `aiProviders.providers` | `PEEKABOO_AI_PROVIDERS` | Comma-separated list (e.g., "openai/gpt-4o,ollama/llava:latest") |
| OpenAI API Key | `aiProviders.openaiApiKey` | `OPENAI_API_KEY` | Required for OpenAI provider |
| Anthropic API Key | `aiProviders.anthropicApiKey` | `ANTHROPIC_API_KEY` | For Claude Vision (coming soon) |
| Ollama URL | `aiProviders.ollamaBaseUrl` | `PEEKABOO_OLLAMA_BASE_URL` | Default: http://localhost:11434 |
| Default Save Path | `defaults.savePath` | `PEEKABOO_DEFAULT_SAVE_PATH` | Where screenshots are saved (default: current directory) |
| Log Level | `logging.level` | `PEEKABOO_LOG_LEVEL` | trace, debug, info, warn, error, fatal |
| Log Path | `logging.path` | `PEEKABOO_LOG_FILE` | Log file location |
| CLI Binary Path | - | `PEEKABOO_CLI_PATH` | Override bundled Swift CLI path (advanced usage) |

### Environment Variable Details

#### AI Provider Configuration

- **`PEEKABOO_AI_PROVIDERS`**: Comma-separated list of AI providers to use for image analysis
  - Format: `provider/model,provider/model`
  - Example: `"openai/gpt-4o,ollama/llava:latest"`
  - The first available provider will be used
  - Default: `"openai/gpt-4o,ollama/llava:latest"`

- **`OPENAI_API_KEY`**: Your OpenAI API key for GPT-4 Vision
  - Required when using the `openai` provider
  - Get your key at: https://platform.openai.com/api-keys

- **`ANTHROPIC_API_KEY`**: Your Anthropic API key for Claude Vision
  - Will be required when Claude Vision support is added
  - Currently not implemented

- **`PEEKABOO_OLLAMA_BASE_URL`**: Base URL for your Ollama server
  - Default: `http://localhost:11434`
  - Use for custom Ollama installations or remote servers

#### Default Behavior

- **`PEEKABOO_DEFAULT_SAVE_PATH`**: Default directory for saving screenshots
  - Default: Current working directory
  - Supports tilde expansion (e.g., `~/Desktop/Screenshots`)
  - Created automatically if it doesn't exist

#### Logging and Debugging

- **`PEEKABOO_LOG_LEVEL`**: Control logging verbosity
  - Options: `trace`, `debug`, `info`, `warn`, `error`, `fatal`
  - Default: `info`
  - Use `debug` or `trace` for troubleshooting

- **`PEEKABOO_LOG_FILE`**: Custom log file location
  - Default: `/tmp/peekaboo-mcp.log` (MCP server)
  - For CLI, logs are written to stderr by default

#### Advanced Options

- **`PEEKABOO_CLI_PATH`**: Override the bundled Swift CLI binary path
  - Only needed if using a custom-built CLI binary
  - Default: Uses the bundled binary

### Using Environment Variables

Environment variables can be set in multiple ways:

```bash
# For a single command
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" peekaboo analyze image.png "What is this?"

# Export for the current session
export OPENAI_API_KEY="sk-..."
export PEEKABOO_DEFAULT_SAVE_PATH="~/Desktop/Screenshots"

# Add to your shell profile (~/.zshrc or ~/.bash_profile)
echo 'export OPENAI_API_KEY="sk-..."' >> ~/.zshrc
```

## 🎨 Setting Up Local AI with Ollama

For privacy-focused local AI analysis:

```bash
# Install Ollama
brew install ollama
ollama serve

# Download vision models
ollama pull llava:latest       # Recommended
ollama pull qwen2-vl:7b        # Lighter alternative

# Configure Peekaboo
peekaboo config edit
# Set providers to: "ollama/llava:latest"
```

## 📋 Requirements

- **macOS 14.0+** (Sonoma or later)
- **Screen Recording Permission** (required)
- **Accessibility Permission** (optional, for window focus control)

### Granting Permissions

1. **Screen Recording** (Required):
   - System Settings → Privacy & Security → Screen & System Audio Recording
   - Enable for Terminal, Claude Desktop, or your IDE

2. **Accessibility** (Optional):
   - System Settings → Privacy & Security → Accessibility
   - Enable for better window focus control

## 🏗️ Building from Source

### Prerequisites

- macOS 14.0+ (Sonoma or later)
- Node.js 20.0+ and npm
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+ (included with Xcode)

### Build Commands

```bash
# Clone the repository
git clone https://github.com/steipete/peekaboo.git
cd peekaboo

# Install dependencies
npm install

# Build everything (CLI + MCP server)
npm run build:all

# Build options:
npm run build         # TypeScript only
npm run build:swift   # Swift CLI only (universal binary)
./scripts/build-cli-standalone.sh         # Quick CLI build
./scripts/build-cli-standalone.sh --install # Build and install to /usr/local/bin
```

### Creating Release Binaries

```bash
# Run all pre-release checks and create release artifacts
./scripts/release-binaries.sh

# Skip checks (if you've already run them)
./scripts/release-binaries.sh --skip-checks

# Create GitHub release draft
./scripts/release-binaries.sh --create-github-release

# Full release with npm publish
./scripts/release-binaries.sh --create-github-release --publish-npm
```

The release script creates:
- `peekaboo-macos-universal.tar.gz` - Standalone CLI binary (universal)
- `@steipete-peekaboo-mcp-{version}.tgz` - npm package
- `checksums.txt` - SHA256 checksums for verification

## 🧪 Testing

```bash
# Test CLI directly
peekaboo list server_status
peekaboo image --mode screen --path test.png
peekaboo analyze test.png "What is shown?"

# Test MCP server
npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp
```

## 📚 Documentation

- [API Documentation](./docs/spec.md)
- [Contributing Guide](https://github.com/steipete/Peekaboo?tab=readme-ov-file#-contributing)
- [Blog Post](https://steipete.me/posts/2025/peekaboo-2-freeing-the-cli-from-its-mcp-shackles/)

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| `Permission denied` | Grant Screen Recording permission in System Settings |
| `Window not found` | Try using fuzzy matching or list windows first |
| `AI analysis failed` | Check API keys and provider configuration |
| `Command not found` | Ensure Peekaboo is in your PATH or use full path |

Enable debug logging for more details:
```bash
export PEEKABOO_LOG_LEVEL=debug
peekaboo list server_status
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📝 License

MIT License - see [LICENSE](./LICENSE) file for details.

## 👤 Author

Created by [Peter Steinberger](https://steipete.com) - [@steipete](https://github.com/steipete)

## 🙏 Acknowledgments

- Apple's ScreenCaptureKit for blazing-fast captures
- The MCP team for the Model Context Protocol
- The Swift and TypeScript communities

---

**Note**: This is Peekaboo v2.0, which introduces standalone CLI functionality alongside the original MCP server. For users upgrading from v1.x, see the [CHANGELOG](./CHANGELOG.md) for migration details.