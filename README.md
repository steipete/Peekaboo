# Peekaboo MCP: Lightning-fast macOS Screenshots for AI Agents

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D20.0.0-brightgreen.svg)](https://nodejs.org/)

Peekaboo is a macOS-only MCP server that enables AI agents to capture screenshots of applications, windows, or the entire system, with optional visual question answering through local or remote AI models.

## What is Peekaboo?

Peekaboo bridges the gap between AI assistants and visual content on your screen. Without visual capabilities, AI agents are fundamentally limited when debugging UI issues or understanding what's happening on screen. Peekaboo solves this by giving AI agents the ability to:

- **Capture screenshots** of your entire screen, specific applications, or individual windows
- **Analyze visual content** using AI vision models (both local and cloud-based)
- **List running applications** and their windows for targeted captures
- **Work non-intrusively** without changing window focus or interrupting your workflow

## Key Features

- **🚀 Fast & Non-intrusive**: Uses Apple's ScreenCaptureKit for instant captures without focus changes
- **🎯 Smart Window Targeting**: Fuzzy matching finds the right window even with partial names
- **🤖 AI-Powered Analysis**: Ask questions about screenshots using GPT-4o, Claude, or local models
- **🔒 Privacy-First**: Run entirely locally with Ollama, or use cloud providers when needed
- **📦 Easy Installation**: One-click install via Cursor or simple npm/npx commands
- **🛠️ Developer-Friendly**: Clean JSON API, TypeScript support, comprehensive logging

Read more about the design philosophy and implementation details in the [blog post](https://steipete.com/posts/peekaboo-mcp-screenshots-so-fast-theyre-paranormal/).

## Installation

### Requirements

- **macOS 14.0+** (Sonoma or later)
- **Node.js 20.0+**
- **Screen Recording Permission** (you'll be prompted on first use)

### Quick Start

#### For Cursor IDE

<div align="center">
  <a href="cursor://anysphere.cursor-deeplink/mcp/install?name=peekaboo&config=ewogICJjb21tYW5kIjogIm5weCIsCiAgImFyZ3MiOiBbCiAgICAiLXkiLAogICAgIkBzdGVpcGV0ZS9wZWVrYWJvby1tY3AiCiAgXSwKICAiZW52IjogewogICAgIlBFRUtBQk9PX0FJX1BST1ZJREVSUyI6ICJvbGxhbWEvbGxhdmE6bGF0ZXN0IgogIH0KfQ==">
    <img src="https://cursor.com/deeplink/mcp-install-dark.png" alt="Install Peekaboo in Cursor IDE" height="40" />
  </a>
</div>

Or manually add to your Cursor settings:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": [
        "-y",
        "@steipete/peekaboo-mcp"
      ],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "ollama/llava:latest"
      }
    }
  }
}
```

#### For Claude Desktop

Edit your Claude Desktop configuration file:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

Add the Peekaboo configuration and restart Claude Desktop.

### Configuration

Peekaboo can be configured using environment variables:

```json
{
  "PEEKABOO_AI_PROVIDERS": "ollama/llava:latest,openai/gpt-4o",
  "PEEKABOO_LOG_LEVEL": "debug",
  "PEEKABOO_LOG_FILE": "~/Library/Logs/peekaboo-mcp-debug.log",
  "PEEKABOO_DEFAULT_SAVE_PATH": "~/Pictures/PeekabooCaptures",
  "PEEKABOO_CONSOLE_LOGGING": "true",
  "PEEKABOO_CLI_TIMEOUT": "30000",
  "PEEKABOO_CLI_PATH": "/opt/custom/peekaboo"
}
```

#### Available Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PEEKABOO_AI_PROVIDERS` | JSON string defining AI providers for image analysis (see [AI Analysis](#ai-analysis)). | `""` (disabled) |
| `PEEKABOO_LOG_LEVEL` | Logging level (trace, debug, info, warn, error, fatal). | `info` |
| `PEEKABOO_LOG_FILE` | Path to the server's log file. If the specified directory is not writable, falls back to the system temp directory. | `~/Library/Logs/peekaboo-mcp.log` |
| `PEEKABOO_DEFAULT_SAVE_PATH` | Default directory for saving captured images when no path is specified. | System temp directory |
| `PEEKABOO_OLLAMA_BASE_URL` | Base URL for the Ollama API server. Only needed if Ollama is running on a non-default address. | `http://localhost:11434` |
| `PEEKABOO_CONSOLE_LOGGING` | Boolean (`"true"`/`"false"`) for development console logs. | `"false"` |
| `PEEKABOO_CLI_TIMEOUT` | Timeout in milliseconds for Swift CLI operations. Prevents hanging processes. | `30000` (30 seconds) |
| `PEEKABOO_CLI_PATH` | Optional override for the Swift `peekaboo` CLI executable path. | (uses bundled CLI) |

#### AI Provider Configuration

The `PEEKABOO_AI_PROVIDERS` environment variable is your gateway to unlocking Peekaboo\'s analytical abilities for both the dedicated `analyze` tool and the `image` tool (when a `question` is supplied with an image capture). It should be a JSON string defining the AI providers and their default models. For example:

`PEEKABOO_AI_PROVIDERS="ollama/llava:latest,openai/gpt-4o,anthropic/claude-3-haiku-20240307"`

Each entry follows the format `provider_name/model_identifier`.

- **`provider_name`**: Currently supported values are `ollama` (for local Ollama instances) and `openai`. Support for `anthropic` is planned.
- **`model_identifier`**: The specific model to use for that provider (e.g., `llava:latest`, `gpt-4o`).

The `analyze` tool and the `image` tool (when a `question` is provided) will use these configurations. If the `provider_config` argument in these tools is set to `\"auto\"` (the default for `analyze`, and an option for `image`), Peekaboo will try providers from `PEEKABOO_AI_PROVIDERS` in the order they are listed, checking for necessary API keys (like `OPENAI_API_KEY`) or service availability (like Ollama running at `http://localhost:11434` or the URL specified in `PEEKABOO_OLLAMA_BASE_URL`).

You can override the model or pick a specific provider listed in `PEEKABOO_AI_PROVIDERS` using the `provider_config` argument in the `analyze` or `image` tools. (The system will still verify its operational readiness, e.g., API key presence or service availability.)

### Setting Up Local AI with Ollama

Ollama provides powerful local AI models that can analyze your screenshots without sending data to the cloud.

#### Installing Ollama

```bash
# Install via Homebrew
brew install ollama

# Or download from https://ollama.ai

# Start the Ollama service
ollama serve
```

#### Downloading Vision Models

**For powerful machines**, LLaVA (Large Language and Vision Assistant) is the recommended model:

```bash
# Download the latest LLaVA model (recommended for best quality)
ollama pull llava:latest

# Alternative LLaVA versions
ollama pull llava:7b-v1.6
ollama pull llava:13b-v1.6  # Larger, more capable
ollama pull llava:34b-v1.6  # Largest, most powerful (requires significant RAM)
```

**For less beefy machines**, Qwen2-VL provides excellent performance with lower resource requirements:

```bash
# Download Qwen2-VL 7B model (great balance of quality and performance)
ollama pull qwen2-vl:7b
```

**Model Size Guide:**
- `qwen2-vl:7b` - ~4GB download, ~6GB RAM required (excellent for lighter machines)
- `llava:7b` - ~4.5GB download, ~8GB RAM required
- `llava:13b` - ~8GB download, ~16GB RAM required  
- `llava:34b` - ~20GB download, ~40GB RAM required

#### Configuring Peekaboo with Ollama

Add Ollama to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": [
        "-y",
        "@steipete/peekaboo-mcp@beta"
      ],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "ollama/llava:latest"
      }
    }
  }
}
```

**For less powerful machines (using Qwen2-VL):**
```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": [
        "-y",
        "@steipete/peekaboo-mcp@beta"
      ],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "ollama/qwen2-vl:7b"
      }
    }
  }
}
```

**Multiple AI Providers (Ollama + OpenAI):**
```json
{
  "env": {
    "PEEKABOO_AI_PROVIDERS": "ollama/llava:latest,openai/gpt-4o",
    "OPENAI_API_KEY": "your-api-key-here"
  }
}
```


### macOS Permissions

Peekaboo requires specific macOS permissions to function:

#### 1. Screen Recording Permission
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Screen Recording** from the left sidebar
3. Click the **lock icon** and enter your password
4. Click **+** and add your terminal application or MCP client
5. Restart the application

**Applications that need permission:**
- Terminal.app: `/Applications/Utilities/Terminal.app`
- Claude Desktop: `/Applications/Claude.app`
- VS Code: `/Applications/Visual Studio Code.app`
- Cursor: `/Applications/Cursor.app`

#### 2. Accessibility Permission (Optional)

To whisper commands to windows and make them dance:
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility** from the left sidebar
3. Add your terminal/MCP client application

### Testing & Debugging

#### Using MCP Inspector

The easiest way to test Peekaboo is with the [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector):

```bash
# Test with local Ollama
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp

# Test with OpenAI
OPENAI_API_KEY="your-key" PEEKABOO_AI_PROVIDERS="openai/gpt-4o" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp
```

This launches an interactive web interface where you can test all of Peekaboo's tools and see their responses in real-time.

#### Direct CLI Testing

```bash
# Commune with the Swift spirit directly
./peekaboo --help

# Check the spectral server's pulse
./peekaboo list server_status --json-output

# Capture a soul (requires permission wards)
./peekaboo image --mode screen --format png

# Open the portal for testing
peekaboo-mcp
```

**Expected output:**
```json
{
  "success": true,
  "data": {
    "swift_cli_available": true,
    "permissions": {
      "screen_recording": true
    },
    "system_info": {
      "macos_version": "14.0"
    }
  }
}
```

## Available Tools

Peekaboo provides three main tools for AI agents:

### 1. `image` - Capture Screenshots

Captures macOS screen content with automatic shadow/frame removal.

**Important:** Screen captures **cannot use `format: "data"`** due to the large size of screen images causing JavaScript stack overflow errors. Screen captures always save to files, either to a specified path or a temporary directory. When `format: "data"` is requested for screen captures, the tool automatically falls back to PNG format and saves to a file with a warning message explaining the fallback.

**Examples:**
```javascript
// Capture entire screen (must save to file)
await use_mcp_tool("peekaboo", "image", {
  app_target: "screen:0",
  path: "~/Desktop/screenshot.png"
});

// Capture specific app window with analysis (can use format: "data")
await use_mcp_tool("peekaboo", "image", {
  app_target: "Safari",
  question: "What website is currently open?",
  format: "data"
});

// Capture window by title
await use_mcp_tool("peekaboo", "image", {
  app_target: "Notes:WINDOW_TITLE:Meeting Notes",
  path: "~/Desktop/notes.png"
});
```

### 2. `list` - System Information

Lists running applications, windows, or server status.

**Examples:**

```javascript
// List all running applications
await use_mcp_tool("peekaboo", "list", {
  item_type: "running_applications"
});

// List windows of specific app
await use_mcp_tool("peekaboo", "list", {
  item_type: "application_windows",
  app: "Preview"
});

// Check server status
await use_mcp_tool("peekaboo", "list", {
  item_type: "server_status"
});
```

### 3. `analyze` - AI Vision Analysis

Analyzes existing images using configured AI models.

**Examples:**

```javascript
// Analyze with auto-selected provider
await use_mcp_tool("peekaboo", "analyze", {
  image_path: "~/Desktop/screenshot.png",
  question: "What applications are visible?"
});

// Force specific provider
await use_mcp_tool("peekaboo", "analyze", {
  image_path: "~/Desktop/diagram.jpg",
  question: "Explain this diagram",
  provider_config: {
    type: "ollama",
    model: "llava:13b"
  }
});
```

## Testing

Peekaboo includes comprehensive test suites for both TypeScript and Swift components:

### TypeScript Tests

- **Unit Tests**: Test individual functions and modules in isolation
- **Integration Tests**: Test tool handlers with mocked Swift CLI
- **Platform-Specific Tests**: Some integration tests require macOS and Swift binary

```bash
# Run all tests (requires macOS and Swift binary for integration tests)
npm test

# Run only unit tests (works on any platform)
npm run test:unit

# Run TypeScript-only tests (skips Swift-dependent tests, works on Linux)
npm run test:typescript

# Watch mode for TypeScript-only tests
npm run test:typescript:watch

# Run with coverage
npm run test:coverage
```

### Swift Tests

```bash
# Run Swift CLI tests (macOS only)
npm run test:swift

# Run full integration tests (TypeScript + Swift)
npm run test:integration
```

### Platform Support

- **macOS**: All tests run (unit, integration, Swift)
- **Linux/CI**: Only TypeScript tests run (Swift-dependent tests are automatically skipped)
- **Environment Variables**:
  - `SKIP_SWIFT_TESTS=true`: Force skip Swift-dependent tests
  - `CI=true`: Automatically skips Swift-dependent tests

## Troubleshooting

### Common Issues

| Haunting | Exorcism |
|-------|----------|
| `Permission denied` errors during image capture | Grant **Screen Recording** permission in System Settings → Privacy & Security. Ensure the correct application (Terminal, Claude, VS Code, etc.) is added and checked. Restart the app after changing permissions. |
| Window capture issues (wrong window, focus problems) | Grant **Accessibility** permission if using `capture_focus: "foreground"` or for more reliable window targeting. |
| `Swift CLI unavailable` or `PEEKABOO_CLI_PATH` issues | Ensure the `peekaboo` binary is at the root of the NPM package, or if `PEEKABOO_CLI_PATH` is set, verify it points to a valid executable. You can test the Swift CLI directly: `path/to/peekaboo --version`. If missing or broken, rebuild: `cd peekaboo-cli && swift build -c release` (then place binary appropriately or update `PEEKABOO_CLI_PATH`). |
| `AI analysis failed` | Check your `PEEKABOO_AI_PROVIDERS` environment variable for correct format and valid provider/model pairs. Ensure API keys (e.g., `OPENAI_API_KEY`) are set if using cloud providers. Verify local services like Ollama are running (`PEEKABOO_OLLAMA_BASE_URL`). Check the server logs (`PEEKABOO_LOG_FILE` or console if `PEEKABOO_CONSOLE_LOGGING="true"`) for detailed error messages from the AI provider. |
| `Command not found: peekaboo-mcp` | If installed globally, ensure your system's PATH includes the global npm binaries directory. If running from a local clone, use `node dist/index.js` or a configured npm script. For `npx`, ensure the package name `@steipete/peekaboo-mcp` is correct. |
| General weirdness or unexpected behavior | Check the Peekaboo MCP server logs! The default location is `/tmp/peekaboo-mcp.log` (or what you set in `PEEKABOO_LOG_FILE`). Set `PEEKABOO_LOG_LEVEL=debug` for maximum detail. |

### Debug Mode

```bash
# Enable debug logging
PEEKABOO_LOG_LEVEL=debug PEEKABOO_CONSOLE_LOGGING=true npx @steipete/peekaboo-mcp

# Check permissions
./peekaboo list server_status --json-output
```

### Getting Help

- 📚 [Documentation](./docs/)
- 🐛 [Report Issues](https://github.com/steipete/peekaboo/issues)
- 💬 [Discussions](https://github.com/steipete/peekaboo/discussions)
- 📖 [Blog Post](https://steipete.com/posts/peekaboo-mcp-screenshots-so-fast-theyre-paranormal/)

## Building from Source

### Development Setup

```bash
# Clone the repository
git clone https://github.com/steipete/peekaboo.git
cd peekaboo

# Install dependencies
npm install

# Build TypeScript
npm run build

# Build Swift CLI
cd peekaboo-cli
swift build -c release
cp .build/release/peekaboo ../peekaboo
cd ..

# Optional: Install globally
npm link
```

### Local Development Configuration

For development, you can run Peekaboo locally:
```json
{
  "mcpServers": {
    "peekaboo_local": {
      "command": "peekaboo-mcp",
      "args": [],
      "env": {
        "PEEKABOO_LOG_LEVEL": "debug",
        "PEEKABOO_CONSOLE_LOGGING": "true"
      }
    }
  }
}
```

Alternatively, running directly with `node`:
```json
{
  "mcpServers": {
    "peekaboo_local_node": {
      "command": "node",
      "args": [
        "/Users/steipete/Projects/Peekaboo/dist/index.js"
      ],
      "env": {
        "PEEKABOO_LOG_LEVEL": "debug",
        "PEEKABOO_CONSOLE_LOGGING": "true"
      }
    }
  }
}
```
Remember to use absolute paths and unique server names to avoid conflicts with the npm version.

### Using the AppleScript Version

For simple screenshot capture without MCP integration:

```bash
osascript peekaboo.scpt
```

Note: This legacy version doesn't include AI analysis or MCP features.

### Manual Configuration for Other MCP Clients

For MCP clients other than Claude Desktop:

```json
{
  "server": {
    "command": "node",
    "args": ["/path/to/peekaboo/dist/index.js"],
    "env": {
      "PEEKABOO_AI_PROVIDERS": "ollama/llava,openai/gpt-4o"
    }
  }
}
```

## Tool Documentation

### `image` - Screenshot Capture

Captures macOS screen content and optionally analyzes it. Window shadows/frames are automatically excluded.

**Parameters:**

*   `app_target` (string, optional): Specifies the capture target. If omitted or empty, captures all screens.
    *   Examples:
        *   `"screen:INDEX"`: Captures the screen at the specified zero-based index (e.g., `"screen:0"`). (Note: Index selection from multiple screens is planned for full support in the Swift CLI).
        *   `"frontmost"`: Aims to capture all windows of the current foreground application. (Note: This is a complex scenario; current implementation may default to screen capture if the exact foreground app cannot be reliably determined by the Node.js layer alone).
        *   `"AppName"`: Captures all windows of the application named `AppName` (e.g., `"Safari"`, `"com.apple.Safari"`). Fuzzy matching is used.
        *   `"AppName:WINDOW_TITLE:Title"`: Captures the window of `AppName` that has the specified `Title` (e.g., `"Notes:WINDOW_TITLE:My Important Note"`).
        *   `"AppName:WINDOW_INDEX:Index"`: Captures the window of `AppName` at the specified zero-based `Index` (e.g., `"Preview:WINDOW_INDEX:0"` for the frontmost window of Preview).
*   `path` (string, optional): Base absolute path for saving the captured image(s). If `format` is `"data"` and `path` is also provided, the image is saved to this path (as a PNG) AND Base64 data is returned. If a `question` is provided and `path` is omitted, a temporary path is used for capture, and the file is deleted after analysis.
*   `question` (string, optional): If provided, the captured image will be analyzed. The server automatically selects an AI provider from those configured in the `PEEKABOO_AI_PROVIDERS` environment variable.
*   `format` (string, optional, default: `"png"`): Specifies the output image format or data return type.
    *   `"png"` or `"jpg"`: Saves the image to the specified `path` in the chosen format. For application captures: if `path` is not provided, behaves like `"data"`. For screen captures: always saves to file.
    *   `"data"`: Returns Base64 encoded PNG data of the image directly in the MCP response. If `path` is also specified, a PNG file is also saved to that `path`. **Note: Screen captures cannot use this format and will automatically fall back to PNG file format.**
    *   Invalid values (empty strings, null, or unrecognized formats) automatically fall back to `"png"`.
*   `capture_focus` (string, optional, default: `"background"`): Controls window focus behavior during capture.
    *   `"background"`: Captures without altering the current window focus (default).
    *   `"foreground"`: Attempts to bring the target application/window to the foreground before capture. This might be necessary for certain applications or to ensure a specific window is captured if multiple are open.

**Behavior with `question` (AI Analysis):**

*   If a `question` is provided, the tool will capture the image (saving it to `path` if specified, or a temporary path otherwise).
*   This image is then sent to an AI model for analysis. The AI provider and model are chosen automatically by the server based on your `PEEKABOO_AI_PROVIDERS` environment variable (trying them in order until one succeeds).
*   The analysis result is returned as `analysis_text` in the response. Image data (Base64) is NOT returned in the `content` array when a question is asked.
*   If a temporary path was used for the image, it's deleted after the analysis attempt.

**Output Structure (Simplified):**

*   `content`: Can contain `ImageContentItem` (if `format: "data"` or `path` was omitted, and no `question`) and/or `TextContentItem` (for summaries, analysis text, warnings).
*   `saved_files`: Array of objects, each detailing a file saved to `path` (if `path` was provided).
*   `analysis_text`: Text from AI (if `question` was asked).
*   `model_used`: AI model identifier (if `question` was asked).

For detailed parameter documentation, see [docs/spec.md](./docs/spec.md).

## Technical Features

### Screenshot Capabilities
- **Multi-display support**: Captures each display separately
- **Smart app targeting**: Fuzzy matching for application names
- **Multiple formats**: PNG, JPEG, WebP, HEIF support
- **Automatic naming**: Timestamp-based file naming
- **Permission checking**: Automatic verification of required permissions

### Window Management  
- **Application listing**: Complete list of running applications
- **Window enumeration**: List all windows for specific apps
- **Flexible matching**: Find apps by partial name, bundle ID, or PID
- **Status monitoring**: Active/inactive status, window counts

### AI Integration
- **Provider agnostic**: Supports Ollama and OpenAI (Anthropic coming soon)
- **Natural language**: Ask questions about captured images
- **Configurable**: Environment-based provider selection
- **Fallback support**: Automatic failover between providers

## Architecture

```
Peekaboo/
├── src/                      # Node.js MCP Server (TypeScript)
│   ├── index.ts             # Main MCP server entry point
│   ├── tools/               # Individual tool implementations
│   │   ├── image.ts         # Screen capture tool
│   │   ├── analyze.ts       # AI analysis tool  
│   │   └── list.ts          # Application/window listing
│   ├── utils/               # Utility modules
│   │   ├── peekaboo-cli.ts   # Swift CLI integration
│   │   ├── ai-providers.ts  # AI provider management
│   │   └── server-status.ts # Server status utilities
│   └── types/               # Shared type definitions
├── peekaboo-cli/            # Native Swift CLI
│   └── Sources/peekaboo/    # Swift source files
│       ├── main.swift       # CLI entry point
│       ├── ImageCommand.swift    # Image capture implementation
│       ├── ListCommand.swift     # Application listing
│       ├── Models.swift          # Data structures
│       ├── ApplicationFinder.swift   # App discovery logic
│       ├── WindowManager.swift      # Window management
│       ├── PermissionsChecker.swift # macOS permissions
│       └── JSONOutput.swift        # JSON response formatting
├── package.json             # Node.js dependencies
├── tsconfig.json           # TypeScript configuration
└── README.md               # This file
```

## Technical Details

### JSON Output Format
The Swift CLI outputs structured JSON when called with `--json-output`:

```json
{
  "success": true,
  "data": {
    "applications": [
      {
        "app_name": "Safari",
        "bundle_id": "com.apple.Safari", 
        "pid": 1234,
        "is_active": true,
        "window_count": 2
      }
    ]
  },
  "debug_logs": ["Found 50 applications"]
}
```

### MCP Integration
The Node.js server provides:
- Schema validation via Zod
- Proper MCP error codes
- Structured logging via Pino
- Full TypeScript type safety

### Security
Peekaboo respects macOS security:
- Checks permissions before operations
- Graceful handling of missing permissions
- Clear guidance for permission setup

## Development

### Testing Commands
```bash
# Test Swift CLI directly
./peekaboo list apps --json-output | head -20

# Test MCP server
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js
```

### Building
```bash
# Build TypeScript
npm run build

# Build Swift CLI
cd peekaboo-cli && swift build
```

## Known Issues

- **FileHandle warning**: Non-critical Swift warning about TextOutputStream conformance
- **AI Provider Config**: Requires `PEEKABOO_AI_PROVIDERS` environment variable for analysis features


## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Author

Created by [Peter Steinberger](https://steipete.com) - [@steipete](https://github.com/steipete)

Read more about Peekaboo's design and implementation in the [blog post](https://steipete.com/posts/peekaboo-mcp-screenshots-so-fast-theyre-paranormal/).
