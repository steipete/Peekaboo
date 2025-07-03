# Peekaboo: Lightning-fast macOS Screenshots & AI Vision Analysis

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
# Build from source (recommended)
git clone https://github.com/steipete/peekaboo.git
cd peekaboo
./scripts/build-cli-standalone.sh --install

# Or install via npm (includes both CLI and MCP server)
npm install -g @steipete/peekaboo-mcp
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
| Ollama URL | `aiProviders.ollamaBaseUrl` | `PEEKABOO_OLLAMA_BASE_URL` | Default: http://localhost:11434 |
| Default Save Path | `defaults.savePath` | `PEEKABOO_DEFAULT_SAVE_PATH` | Where screenshots are saved |
| Log Level | `logging.level` | `PEEKABOO_LOG_LEVEL` | trace, debug, info, warn, error, fatal |
| Log Path | `logging.path` | `PEEKABOO_LOG_FILE` | Log file location |

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

```bash
# Clone the repository
git clone https://github.com/steipete/peekaboo.git
cd peekaboo

# Build everything (CLI + MCP server)
npm install
npm run build:all

# Build CLI only
./scripts/build-cli-standalone.sh

# Install CLI system-wide
./scripts/build-cli-standalone.sh --install
```

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
- [Architecture Overview](./docs/architecture.md)
- [Contributing Guide](./CONTRIBUTING.md)
- [Blog Post](https://steipete.com/posts/peekaboo-mcp-screenshots-so-fast-theyre-paranormal/)

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