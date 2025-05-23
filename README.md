# Peekaboo MCP Server

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen.svg)](https://nodejs.org/)

A macOS utility exposed via Node.js MCP server for advanced screen captures, image analysis, and window management.

## 🚀 Installation

### Prerequisites

- **macOS 12.0+** (Monterey or later)
- **Node.js 18.0+**

### Quick Start

Add Peekaboo to your Claude Desktop configuration:

1. Open Claude Desktop settings
2. Go to the Developer tab
3. Edit the configuration file and add:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": [
        "-y",
        "@steipete/peekaboo-mcp@beta"
      ]
    }
  }
}
```

4. Restart Claude Desktop

That's it! Peekaboo will be automatically installed and available.

### 🔧 Configuration

#### Environment Variables

You can configure Peekaboo with environment variables in your Claude Desktop configuration:

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
        "AI_PROVIDERS": "[{\"type\":\"ollama\",\"baseUrl\":\"http://localhost:11434\",\"model\":\"llava\",\"enabled\":true}]",
        "LOG_LEVEL": "INFO",
        "PEEKABOO_LOG_FILE": "/tmp/peekaboo-mcp.log",
        "PEEKABOO_DEFAULT_SAVE_PATH": "~/Pictures/Screenshots"
      }
    }
  }
}
```

#### Available Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AI_PROVIDERS` | JSON array of AI provider configurations | `[]` |
| `LOG_LEVEL` | Logging level (DEBUG, INFO, WARN, ERROR) | `INFO` |
| `PEEKABOO_LOG_FILE` | Log file path | `/tmp/peekaboo-mcp.log` |
| `PEEKABOO_DEFAULT_SAVE_PATH` | Default screenshot save location | `~/Pictures/Screenshots` |

#### AI Provider Configuration

Configure AI providers for image analysis:

```json
[
  {
    "type": "ollama",
    "baseUrl": "http://localhost:11434",
    "model": "llava",
    "enabled": true
  },
  {
    "type": "openai",
    "apiKey": "your-openai-api-key",
    "model": "gpt-4-vision-preview",
    "enabled": false
  }
]
```

### 🔐 Permissions Setup

Peekaboo requires specific macOS permissions to function properly:

#### 1. Screen Recording Permission

**Grant permission via System Preferences:**
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Screen Recording** from the left sidebar
3. Click the **lock icon** and enter your password
4. Click **+** and add your terminal application or MCP client
5. Restart the application

**For common applications:**
- **Terminal.app**: `/Applications/Utilities/Terminal.app`
- **Claude Desktop**: `/Applications/Claude.app`
- **VS Code**: `/Applications/Visual Studio Code.app`

#### 2. Accessibility Permission (Optional)

For advanced window management features:
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility** from the left sidebar
3. Add your terminal/MCP client application

### ✅ Verification

Test your installation:

```bash
# Test the Swift CLI directly
./peekaboo --help

# Test server status
./peekaboo list server_status --json-output

# Test screen capture (requires permissions)
./peekaboo image --mode screen --format png

# Start the MCP server for testing
peekaboo-mcp
```

**Expected output for server status:**
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

### 🎯 Quick Start

Once installed and configured:

1. **Capture Screenshot:**
   ```bash
   peekaboo-mcp
   # In your MCP client: "Take a screenshot of my screen"
   ```

2. **List Applications:**
   ```bash
   # In your MCP client: "Show me all running applications"
   ```

3. **Analyze Screenshot:**
```bash
   # In your MCP client: "Take a screenshot and tell me what's on my screen"
   ```

### 🐛 Troubleshooting

**Common Issues:**

| Issue | Solution |
|-------|----------|
| `Permission denied` errors | Grant Screen Recording permission in System Preferences |
| `Swift CLI unavailable` | Rebuild Swift CLI: `cd swift-cli && swift build -c release` |
| `AI analysis failed` | Check AI provider configuration and network connectivity |
| `Command not found: peekaboo-mcp` | Run `npm link` or check global npm installation |

**Debug Mode:**
```bash
# Enable verbose logging
LOG_LEVEL=DEBUG peekaboo-mcp

# Check permissions
./peekaboo list server_status --json-output
```

**Get Help:**
- 📚 [Documentation](./docs/)
- 🐛 [Issues](https://github.com/yourusername/peekaboo/issues)
- 💬 [Discussions](https://github.com/yourusername/peekaboo/discussions)

## 📦 Alternative Installation Methods

### From Source

If you want to build from source or contribute to development:

```bash
# Clone the repository
git clone https://github.com/steipete/peekaboo.git
cd peekaboo

# Install Node.js dependencies
npm install

# Build the TypeScript server
npm run build

# Build the Swift CLI component
cd swift-cli
swift build -c release

# Copy the binary to the project root
cp .build/release/peekaboo ../peekaboo

# Return to project root
cd ..

# Optional: Link for global access
npm link
```

Then configure Claude Desktop to use your local installation:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "peekaboo-mcp",
      "args": []
    }
  }
}
```

### Using AppleScript

For basic screen capture without the full MCP server, you can use the included AppleScript:

```bash
# Run the AppleScript directly
osascript peekaboo.scpt
```

This provides a simple way to capture screenshots but doesn't include the MCP integration or AI analysis features.

### Manual Configuration for Other MCP Clients

For MCP clients other than Claude Desktop:

```json
{
  "server": {
    "command": "node",
    "args": ["/path/to/peekaboo/dist/index.js"],
    "env": {
      "AI_PROVIDERS": "[{\"type\":\"ollama\",\"baseUrl\":\"http://localhost:11434\",\"model\":\"llava\",\"enabled\":true}]"
    }
  }
}
```

---

## 🛠️ Available Tools

Once installed, Peekaboo provides three powerful MCP tools:

### 📸 `peekaboo.image` - Screen Capture

**Parameters:**
- `mode`: `"screen"` | `"window"` | `"multi"` (default: "screen")
- `app`: Application identifier for window/multi modes
- `path`: Custom save path (optional)

**Example:**
```json
{
  "name": "peekaboo.image", 
  "arguments": {
    "mode": "window",
    "app": "Safari"
  }
}
```

### 📋 `peekaboo.list` - Application Listing

**Parameters:**
- `item_type`: `"running_applications"` | `"application_windows"` | `"server_status"`
- `app`: Application identifier (required for application_windows)

**Example:**
```json
{
  "name": "peekaboo.list",
  "arguments": {
    "item_type": "running_applications"
  }
}
```

### 🧩 `peekaboo.analyze` - AI Analysis

**Parameters:**
- `image_path`: Absolute path to image file
- `question`: Question/prompt for AI analysis

**Example:**
```json
{
  "name": "peekaboo.analyze",
  "arguments": {
    "image_path": "/tmp/screenshot.png",
    "question": "What applications are visible in this screenshot?"
  }
}
```

## 🎯 Key Features

### Screen Capture
- **Multi-display support**: Captures each display separately
- **Window targeting**: Intelligent app/window matching with fuzzy search
- **Format flexibility**: PNG, JPEG, WebP, HEIF support
- **Automatic naming**: Timestamps and descriptive filenames
- **Permission handling**: Automatic screen recording permission checks

### Application Management  
- **Running app enumeration**: Complete system application listing
- **Window discovery**: Per-app window enumeration with metadata
- **Fuzzy matching**: Find apps by partial name, bundle ID, or PID
- **Real-time status**: Active/background status, window counts

### AI Integration
- **Provider agnostic**: Support for Ollama, OpenAI, and other providers
- **Image analysis**: Natural language querying of captured content
- **Configurable**: Environment-based provider selection

## 🏛️ Project Structure

```
Peekaboo/
├── src/                      # Node.js MCP Server (TypeScript)
│   ├── index.ts             # Main MCP server entry point
│   ├── tools/               # Individual tool implementations
│   │   ├── image.ts         # Screen capture tool
│   │   ├── analyze.ts       # AI analysis tool  
│   │   └── list.ts          # Application/window listing
│   ├── utils/               # Utility modules
│   │   ├── swift-cli.ts     # Swift CLI integration
│   │   ├── ai-providers.ts  # AI provider management
│   │   └── server-status.ts # Server status utilities
│   └── types/               # Shared type definitions
├── swift-cli/               # Native Swift CLI
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

## 🔧 Technical Details

### Swift CLI JSON Output
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
The Node.js server translates between MCP's JSON-RPC protocol and the Swift CLI's JSON output, providing:
- **Schema validation** via Zod
- **Error handling** with proper MCP error codes
- **Logging** via Pino logger
- **Type safety** throughout the TypeScript codebase

### Permission Model
Peekaboo respects macOS security by:
- **Checking screen recording permissions** before capture operations
- **Graceful degradation** when permissions are missing
- **Clear error messages** guiding users to grant required permissions

## 🧪 Testing

### Manual Testing
```bash
# Test Swift CLI directly
./peekaboo list apps --json-output | head -20

# Test MCP integration  
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js

# Test image capture
echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "peekaboo.image", "arguments": {"mode": "screen"}}}' | node dist/index.js
```

### Automated Testing
```bash
# TypeScript compilation
npm run build

# Swift compilation  
cd swift-cli && swift build
```

## 🐛 Known Issues

- **FileHandle warning**: Non-critical Swift warning about TextOutputStream conformance
- **AI Provider Config**: Requires `AI_PROVIDERS` environment variable for analysis features

## 🚀 Future Enhancements

- [ ] **OCR Integration**: Built-in text extraction from screenshots
- [ ] **Video Capture**: Screen recording capabilities
- [ ] **Annotation Tools**: Drawing/markup on captured images
- [ ] **Cloud Storage**: Direct upload to cloud providers
- [ ] **Hotkey Support**: System-wide keyboard shortcuts

## 📄 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

**🎉 Peekaboo is ready to use!** The project successfully combines the power of native macOS APIs with modern Node.js tooling to create a comprehensive screen capture and analysis solution.