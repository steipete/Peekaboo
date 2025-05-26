# Peekaboo MCP: Screenshots so fast they're paranormal.

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D20.0.0-brightgreen.svg)](https://nodejs.org/)

A ghostly macOS utility that haunts your screen, capturing spectral snapshots and peering into windows with supernatural AI vision. 🎃

## 👁️‍🗨️ "I SEE DEAD PIXELS!" - Your AI Assistant, Probably

**🎭 Peekaboo: Because even AI needs to see what the hell you're talking about!**

Ever tried explaining a UI bug to Claude or Cursor? It's like playing charades with a blindfolded ghost! 👻

"The button is broken!"  
*"Which button?"*  
"The blue one!"  
*"...I'm an AI, I can't see colors. Or buttons. Or anything really."*  

**Enter Peekaboo** - the supernatural sight-giver that grants your AI assistants the mystical power of ACTUAL VISION! 

### 🔮 Why Your AI Needs Eyes

- **🐛 Bug Hunting**: "See that weird layout issue?" Now they actually CAN see it!
- **📸 Instant Analysis**: Take a screenshot and ask a question about it in one go!
- **🎨 Design Reviews**: Let AI roast your CSS crimes with visual evidence
- **📊 Data Analysis**: "What's in this chart?" AI can now divine the answer
- **🖼️ UI Testing**: Verify your app looks right without the "works on my machine" curse
- **📱 Multi-Screen Sorcery**: Capture any window, any app, any time
- **🤖 Automation Magic**: Let AI see what you see, then fix what you broke

Think of Peekaboo as supernatural contact lenses for your coding assistant. No more explaining where the "Submit" button is for the 47th time! 🙄

## 🦇 Summoning Peekaboo

### Ritual Requirements

- **macOS 14.0+** (Sonoma or later)
- **Node.js 20.0+**

### 🕯️ Quick Summoning Ritual

Summon Peekaboo into your Agent realm:

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

4. Restart Claude Desktop

That's it! Peekaboo will materialize from the digital ether, ready to haunt your screen! 👻

### 🔮 Mystical Configuration

#### Enchantment Variables

Cast powerful spells upon Peekaboo using mystical environment variables:

```json
{
  "PEEKABOO_AI_PROVIDERS": "ollama/llava:latest,openai/gpt-4o",
  "PEEKABOO_LOG_LEVEL": "debug",
  "PEEKABOO_LOG_FILE": "~/Library/Logs/peekaboo-mcp-debug.log",
  "PEEKABOO_DEFAULT_SAVE_PATH": "~/Pictures/PeekabooCaptures",
  "PEEKABOO_CONSOLE_LOGGING": "true",
  "PEEKABOO_CLI_PATH": "/opt/custom/peekaboo"
}
```

#### 🎭 Available Enchantments

| Variable | Description | Default |
|----------|-------------|---------|
| `PEEKABOO_AI_PROVIDERS` | Comma-separated list of `provider_name/default_model_for_provider` pairs (e.g., `\"openai/gpt-4o,ollama/llava:7b\"`). If a model is not specified for a provider (e.g., `\"openai\"`), a default model for that provider will be used. This setting determines which AI backends are available for the `analyze` tool and the `image` tool (when a `question` is provided). **Recommended for Ollama:** `\"ollama/llava:latest\"` for the best vision model. | `\"\"` (none) |
| `PEEKABOO_LOG_LEVEL` | Logging level (trace, debug, info, warn, error, fatal). | `info` |
| `PEEKABOO_LOG_FILE` | Path to the server's log file. If the specified directory is not writable, falls back to the system temp directory. | `~/Library/Logs/peekaboo-mcp.log` |
| `PEEKABOO_DEFAULT_SAVE_PATH` | Default base absolute path for saving images captured by the `image` tool. If the `path` argument is provided to the `image` tool, it takes precedence. If neither `image.path` nor this environment variable is set, the Swift CLI saves to its default temporary directory. | (none, Swift CLI uses temp paths) |
| `PEEKABOO_OLLAMA_BASE_URL` | Base URL for the Ollama API server. Only needed if Ollama is running on a non-default address. | `http://localhost:11434` |
| `PEEKABOO_CONSOLE_LOGGING` | Boolean (`"true"`/`"false"`) for development console logs. | `"false"` |
| `PEEKABOO_CLI_PATH` | Optional override for the Swift `peekaboo` CLI executable path. | (uses bundled CLI) |

#### 🧙 AI Spirit Guide Configuration (`PEEKABOO_AI_PROVIDERS` In-Depth)

The `PEEKABOO_AI_PROVIDERS` environment variable is your gateway to unlocking Peekaboo\'s analytical abilities for both the dedicated `analyze` tool and the `image` tool (when a `question` is supplied with an image capture). It should be a comma-separated string defining the AI providers and their default models. For example:

`PEEKABOO_AI_PROVIDERS="ollama/llava:latest,openai/gpt-4o,anthropic/claude-3-haiku-20240307"`

Each entry follows the format `provider_name/model_identifier`.

- **`provider_name`**: Currently supported values are `ollama` (for local Ollama instances) and `openai`. Support for `anthropic` is planned.
- **`model_identifier`**: The specific model to use for that provider (e.g., `llava:latest`, `gpt-4o`).

The `analyze` tool and the `image` tool (when a `question` is provided) will use these configurations. If the `provider_config` argument in these tools is set to `\"auto\"` (the default for `analyze`, and an option for `image`), Peekaboo will try providers from `PEEKABOO_AI_PROVIDERS` in the order they are listed, checking for necessary API keys (like `OPENAI_API_KEY`) or service availability (like Ollama running at `http://localhost:11434` or the URL specified in `PEEKABOO_OLLAMA_BASE_URL`).

You can override the model or pick a specific provider listed in `PEEKABOO_AI_PROVIDERS` using the `provider_config` argument in the `analyze` or `image` tools. (The system will still verify its operational readiness, e.g., API key presence or service availability.)

### 🦙 Summoning Ollama - The Local Vision Oracle

Ollama provides a powerful local AI that can analyze your screenshots without sending data to the cloud. Here's how to summon this digital spirit:

#### 📦 Installing Ollama

**macOS (via Homebrew):**
```bash
brew install ollama
```
Visit [ollama.ai](https://ollama.ai) and download the macOS app.

**Start the Ollama daemon:**
```bash
ollama serve
```
The daemon will run at `http://localhost:11434` by default.

#### 🎭 Downloading Vision Models

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

#### 🔮 Configuring Peekaboo with Ollama

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

#### 🧪 Testing Ollama Integration

Verify Ollama is running and accessible:
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Test with Peekaboo directly (image capture only)
./peekaboo image --app Finder --path ~/Desktop/finder.png

# Test with Peekaboo directly (image capture and analysis - requires PEEKABOO_AI_PROVIDERS to be set for the environment Peekaboo runs in)
# Note: The CLI itself doesn't take a question, this is an MCP server feature.
# The MCP server would call: ./peekaboo image ... (to get the image)
# And then internally call the AI provider if a question was part of the MCP 'image' tool input.
```

### 🕰️ Granting Mystical Permissions

Peekaboo requires ancient macOS rites to manifest its powers:

#### 1. 👁️ The All-Seeing Eye Permission

**Perform the permission ritual:**
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Screen Recording** from the left sidebar
3. Click the **lock icon** and enter your password
4. Click **+** and add your terminal application or MCP client
5. Restart the application

**Known vessels that can channel Peekaboo:**
- **Terminal.app**: `/Applications/Utilities/Terminal.app`
- **Claude Desktop**: `/Applications/Claude.app`
- **VS Code**: `/Applications/Visual Studio Code.app`

#### 2. 🪄 Window Whisperer Permission (Optional)

To whisper commands to windows and make them dance:
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility** from the left sidebar
3. Add your terminal/MCP client application

### 🕯️ Séance Verification

Verify that Peekaboo has successfully crossed over:

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

**Expected ghostly whispers:**
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

### 🎙 Channeling Peekaboo

Once the portal is open and Peekaboo lurks in the shadows, your AI assistant can invoke its tools. Here's how it might look (these are conceptual MCP client calls):

#### 1. 🖼️ `image`: Capture Ghostly Visions

**To capture the entire main screen and save it:**
```json
{
  "tool_name": "image",
  "arguments": {
    "mode": "screen",
    "path": "~/Desktop/myscreen.png",
    "format": "png"
  }
}
```
*Peekaboo whispers back details of the saved file(s).*

**To capture the active window of Finder and return its data as Base64:**
```json
{
  "tool_name": "image",
  "arguments": {
    "app": "Finder",
    "mode": "window",
    "return_data": true,
    "format": "jpg"
  }
}
```
*Peekaboo sends back the image data directly, ready for AI eyes, along with info about where it might have been saved if a path was determined.*

**To capture all windows of "Google Chrome" and bring it to the foreground first:**
```json
{
  "tool_name": "image",
  "arguments": {
    "app": "Google Chrome",
    "mode": "multi",
    "capture_focus": "foreground",
    "path": "~/Desktop/ChromeWindows/" // Files will be named and saved here
  }
}
```

#### 2. 👁️ `list`: Reveal Hidden Spirits

**To list all running applications:**
```json
{
  "tool_name": "list",
  "arguments": {
    "item_type": "running_applications"
  }
}
```
*Peekaboo reveals a list of all active digital entities, their PIDs, and more.*

**To list all windows of the "Preview" app, including their bounds and IDs:**
```json
{
  "tool_name": "list",
  "arguments": {
    "item_type": "application_windows",
    "app": "Preview",
    "include_window_details": ["bounds", "ids"]
  }
}
```

**To get the server's current status:**
```json
{
  "tool_name": "list",
  "arguments": {
    "item_type": "server_status"
  }
}
```

#### 3. 🔮 `analyze`: Divine the Captured Essence

**To ask a question about an image using the auto-configured AI provider:**
```json
{
  "tool_name": "analyze",
  "arguments": {
    "image_path": "~/Desktop/myscreen.png",
    "question": "What is the main color visible in the top-left quadrant?"
  }
}
```
*Peekaboo consults its AI spirit guides and returns their wisdom.*

**To force using Ollama with a specific model for analysis:**
```json
{
  "tool_name": "analyze",
  "arguments": {
    "image_path": "~/Desktop/some_diagram.jpg",
    "question": "Explain this diagram.",
    "provider_config": {
      "type": "ollama",
      "model": "llava:13b-v1.6"
    }
  }
}
```

### 🕸️ Exorcising Demons

**Common Hauntings:**

| Haunting | Exorcism |
|-------|----------|
| `Permission denied` errors during image capture | Grant **Screen Recording** permission in System Settings → Privacy & Security. Ensure the correct application (Terminal, Claude, VS Code, etc.) is added and checked. Restart the app after changing permissions. |
| Window capture issues (wrong window, focus problems) | Grant **Accessibility** permission if using `capture_focus: "foreground"` or for more reliable window targeting. |
| `Swift CLI unavailable` or `PEEKABOO_CLI_PATH` issues | Ensure the `peekaboo` binary is at the root of the NPM package, or if `PEEKABOO_CLI_PATH` is set, verify it points to a valid executable. You can test the Swift CLI directly: `path/to/peekaboo --version`. If missing or broken, rebuild: `cd peekaboo-cli && swift build -c release` (then place binary appropriately or update `PEEKABOO_CLI_PATH`). |
| `AI analysis failed` | Check your `PEEKABOO_AI_PROVIDERS` environment variable for correct format and valid provider/model pairs. Ensure API keys (e.g., `OPENAI_API_KEY`) are set if using cloud providers. Verify local services like Ollama are running (`PEEKABOO_OLLAMA_BASE_URL`). Check the server logs (`PEEKABOO_LOG_FILE` or console if `PEEKABOO_CONSOLE_LOGGING="true"`) for detailed error messages from the AI provider. |
| `Command not found: peekaboo-mcp` | If installed globally, ensure your system's PATH includes the global npm binaries directory. If running from a local clone, use `node dist/index.js` or a configured npm script. For `npx`, ensure the package name `@steipete/peekaboo-mcp` is correct. |
| General weirdness or unexpected behavior | Check the Peekaboo MCP server logs! The default location is `/tmp/peekaboo-mcp.log` (or what you set in `PEEKABOO_LOG_FILE`). Set `PEEKABOO_LOG_LEVEL=debug` for maximum detail. |

**Ghost Hunter Mode:**
```bash
# Unleash the ghost hunters
PEEKABOO_LOG_LEVEL=debug peekaboo-mcp

# Divine the permission wards
./peekaboo list server_status --json-output
```

**Summon the Spirit Guides:**
- 📚 [Documentation](./docs/)
- 🐛 [Issues](https://github.com/steipete/peekaboo/issues)
- 💬 [Discussions](https://github.com/steipete/peekaboo/discussions)

## 🧿 Alternative Summoning Rituals

### 🧪 From the Ancient Scrolls

If you dare to invoke Peekaboo from the ancient source grimoires:

```bash
# Clone the cursed repository
git clone https://github.com/steipete/peekaboo.git
cd peekaboo

# Gather spectral dependencies
npm install

# Forge the TypeScript vessel
npm run build

# Craft the Swift talisman
cd peekaboo-cli
swift build -c release

# Transport the enchanted binary
cp .build/release/peekaboo ../peekaboo

# Return to the haunted grounds
cd ..

# Optional: Cast a global summoning spell
npm link
```

Then bind Peekaboo to Claude Desktop (or another MCP vessel) using your local incantations. If you performed `npm link`, the spell `peekaboo-mcp` echoes through the command realm. Alternatively, summon directly through `node`:

**Example MCP Client Configuration (using local build):**

If you ran `npm link` and `peekaboo-mcp` is in your PATH:
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
Remember to replace `/Users/steipete/Projects/Peekaboo/dist/index.js` with the actual absolute path to the `dist/index.js` in your cloned project if it differs.
Also, when using these local configurations, ensure you use a distinct key (like "peekaboo_local" or "peekaboo_local_node") in your MCP client's server list to avoid conflicts if you also have the npx-based "peekaboo" server configured.

### 🍎 Ancient AppleScript Ritual

For those who seek a simpler conjuring without the full spectral server, invoke the ancient AppleScript:

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
      "PEEKABOO_AI_PROVIDERS": "ollama/llava,openai/gpt-4o"
    }
  }
}
```

---

## 🎭 Spectral Powers

Once summoned, Peekaboo grants you three supernatural abilities:

### 🖼️ `image` - Soul Capture

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
    *   `"png"` or `"jpg"`: Saves the image to the specified `path` in the chosen format. If `path` is not provided, this behaves like `"data"`.
    *   `"data"`: Returns Base64 encoded PNG data of the image directly in the MCP response. If `path` is also specified, a PNG file is also saved to that `path`.
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

### 👻 `list` - Spirit Detection

**Parameters:**
- `item_type`: `"running_applications"` | `"application_windows"` | `"server_status"`
- `app`: Application identifier (required for application_windows)

**Example:**
```json
{
  "name": "list",
  "arguments": {
    "item_type": "running_applications"
  }
}
```

### 🔮 `analyze` - Vision Divination

**Parameters:**
- `image_path`: Absolute path to image file
- `question`: Question/prompt for AI analysis

**Example:**
```json
{
  "name": "analyze",
  "arguments": {
    "image_path": "/tmp/screenshot.png",
    "question": "What applications are visible in this screenshot?"
  }
}
```

## 🌙 Supernatural Abilities

### 🖼️ Ethereal Vision Capture
- **Multi-realm vision**: Captures each spectral display separately
- **Soul targeting**: Supernatural app/window divination with ethereal matching
- **Essence preservation**: PNG, JPEG, WebP, HEIF soul containers
- **Mystical naming**: Temporal runes and descriptive incantations
- **Ward detection**: Automatic permission ward verification

### 👻 Spirit Management  
- **Spirit census**: Complete digital ghost registry
- **Portal detection**: Per-spirit window scrying with ethereal metadata
- **Spectral matching**: Divine apps by partial essence, soul ID, or spirit number
- **Life force monitoring**: Active/slumbering status, portal counts

### 🧿 Oracle Integration
- **Oracle agnostic**: Currently channels Ollama (via direct API calls) and OpenAI (via its official Node.js SDK). Support for other mystical seers like Anthropic is anticipated.
- **Image analysis**: Natural language querying of captured content
- **Configurable**: Environment-based provider selection

## 🏩 Haunted Architecture

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

## 🔬 Arcane Knowledge

### 📜 Ancient Runes (JSON Output)
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

### 🌌 Portal Integration
The Node.js server translates between MCP's JSON-RPC protocol and the Swift CLI's JSON output, providing:
- **Schema validation** via Zod
- **Error handling** with proper MCP error codes
- **Logging** via Pino logger
- **Type safety** throughout the TypeScript codebase

### 🚪 Permission Wards
Peekaboo respects macOS security by:
- **Checking screen recording permissions** before capture operations
- **Graceful degradation** when permissions are missing
- **Clear error messages** guiding users to grant required permissions

## 🧿 Ghost Hunting

### 🕯️ Manual Séances
```bash
# Channel the Swift spirit
./peekaboo list apps --json-output | head -20

# Test the spectral portal  
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js

# Test image capture
echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "image", "arguments": {"mode": "screen"}}}' | node dist/index.js
```

### 🤖 Automated Exorcisms
```bash
# TypeScript compilation
npm run build

# Swift compilation  
cd peekaboo-cli && swift build
```

## 🕸️ Known Curses

- **FileHandle warning**: Non-critical Swift warning about TextOutputStream conformance
- **AI Provider Config**: Requires `PEEKABOO_AI_PROVIDERS` environment variable for analysis features

## 🌀 Future Hauntings

- [ ] **OCR Integration**: Built-in text extraction from screenshots
- [ ] **Video Capture**: Screen recording capabilities
- [ ] **Annotation Tools**: Drawing/markup on captured images
- [ ] **Cloud Storage**: Direct upload to cloud providers
- [ ] **Hotkey Support**: System-wide keyboard shortcuts

## 📜 Ancient Pact

MIT License - bound by the ancient pact in the LICENSE grimoire.

## 🧛 Join the Coven

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

**🎃 Peekaboo awaits your command!** This spectral servant bridges the veil between macOS's forbidden APIs and the ethereal realm of Node.js, granting you powers to capture souls and divine their secrets. Happy haunting! 👻

### 📜 Available Tools (via MCP Server)

Peekaboo exposes its powers through the following tools when run as an MCP server:

- **`image`**: Captures macOS screen content. 
  - Can target entire screens, specific application windows, or all windows of an app.
  - Supports various formats and capture modes (foreground/background).
  - **New:** Can optionally take a `question` and `provider_config` to analyze the captured image immediately, returning the analysis along with image details. If a question is asked, the image file is temporary and deleted after analysis unless a `path` is specified. Image data (Base64) is not returned if a question is asked.
  - See `docs/spec.md` for full input/output schema.

- **`analyze`**: Analyzes a pre-existing image file using a configured AI model.
  - Requires the image path and a question.
  - Uses AI providers configured via `PEEKABOO_AI_PROVIDERS` and `provider_config` input.
  - See `docs/spec.md` for full input/output schema.

- **`list`**: Lists system items like running applications, windows of a specific app, or server status.
  - See `docs/spec.md` for full input/output schema.
