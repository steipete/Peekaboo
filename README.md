# 👻 Peekaboo MCP: Screenshots so fast they’re paranormal

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen.svg)](https://nodejs.org/)

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
- **🎨 Design Reviews**: Let AI roast your CSS crimes with visual evidence
- **📊 Data Analysis**: "What's in this chart?" AI can now divine the answer
- **🖼️ UI Testing**: Verify your app looks right without the "works on my machine" curse
- **📱 Multi-Screen Sorcery**: Capture any window, any app, any time
- **🤖 Automation Magic**: Let AI see what you see, then fix what you broke

Think of Peekaboo as supernatural contact lenses for your coding assistant. No more explaining where the "Submit" button is for the 47th time! 🙄

## 🦇 Summoning Peekaboo

### Ritual Requirements

- **macOS 12.0+** (Monterey or later)
- **Node.js 18.0+**

### 🕯️ Quick Summoning Ritual

Summon Peekaboo into your Claude Desktop realm:

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

That's it! Peekaboo will materialize from the digital ether, ready to haunt your screen! 👻

### 🔮 Mystical Configuration

#### Enchantment Variables

Cast powerful spells upon Peekaboo using mystical environment variables:

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
        "LOG_LEVEL": "info",
        "LOG_FILE": "/tmp/peekaboo-mcp.log",
        "DEFAULT_SAVE_PATH": "~/Pictures/Screenshots",
        "CONSOLE_LOGGING": "true",
        "CLI_PATH": "/usr/local/bin/peekaboo_custom"
      }
    }
  }
}
```

#### 🎭 Available Enchantments

| Variable | Description | Default |
|----------|-------------|---------|
| `AI_PROVIDERS` | JSON array of AI provider configurations | `[]` |
| `LOG_LEVEL` | Logging level (debug, info, warn, error) | `info` |
| `LOG_FILE` | Path to the server's log file. | `path.join(os.tmpdir(), 'peekaboo-mcp.log')` |
| `DEFAULT_SAVE_PATH` | Default base absolute path for saving images captured by `peekaboo.image` if not specified in the tool input. If this ENV is also not set, the Swift CLI will use its own temporary directory logic. | (none, Swift CLI uses temp paths) |
| `CONSOLE_LOGGING` | Boolean (`"true"`/`"false"`) for dev console logs. | `"false"` |
| `CLI_PATH` | Optional override for Swift `peekaboo` CLI path. | (bundled CLI) |

#### 🧙 AI Spirit Guide Configuration

Summon AI spirit guides to divine the meaning of captured visions:

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

Once the portal is open and Peekaboo lurks in the shadows:

1. **🖼️ Capture Ghostly Visions:**
   ```bash
   peekaboo-mcp
   # Whisper: "Capture the essence of my screen"
   ```

2. **💀 Reveal Hidden Spirits:**
   ```bash
   # Whisper: "Reveal all digital spirits dwelling here"
   ```

3. **🔮 Divine the Captured Essence:**
```bash
   # Whisper: "Divine the visions upon my ethereal display"
   ```

### 🕸️ Exorcising Demons

**Common Hauntings:**

| Haunting | Exorcism |
|-------|----------|
| `Permission denied` errors | Grant Screen Recording permission in System Preferences |
| `Swift CLI unavailable` | Rebuild Swift CLI: `cd swift-cli && swift build -c release` |
| `AI analysis failed` | Check AI provider configuration and network connectivity |
| `Command not found: peekaboo-mcp` | Run `npm link` or check global npm installation |

**Ghost Hunter Mode:**
```bash
# Unleash the ghost hunters
LOG_LEVEL=debug peekaboo-mcp

# Divine the permission wards
./peekaboo list server_status --json-output
```

**Summon the Spirit Guides:**
- 📚 [Documentation](./docs/)
- 🐛 [Issues](https://github.com/yourusername/peekaboo/issues)
- 💬 [Discussions](https://github.com/yourusername/peekaboo/discussions)

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
cd swift-cli
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
        "LOG_LEVEL": "debug",
        "CONSOLE_LOGGING": "true"
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
        "LOG_LEVEL": "debug",
        "CONSOLE_LOGGING": "true"
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
      "AI_PROVIDERS": "[{\"type\":\"ollama\",\"baseUrl\":\"http://localhost:11434\",\"model\":\"llava\",\"enabled\":true}]"
    }
  }
}
```

---

## 🎭 Spectral Powers

Once summoned, Peekaboo grants you three supernatural abilities:

### 🖼️ `image` - Soul Capture

**Parameters:**
- `mode`: `"screen"` | `"window"` | `"multi"` (default: "screen")
- `app`: Application identifier for window/multi modes
- `path`: Custom save path (optional)

**Example:**
```json
{
  "name": "image", 
  "arguments": {
    "mode": "window",
    "app": "Safari"
  }
}
```

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
- **Oracle agnostic**: Channels Ollama, OpenAI, and other mystical seers
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
cd swift-cli && swift build
```

## 🕸️ Known Curses

- **FileHandle warning**: Non-critical Swift warning about TextOutputStream conformance
- **AI Provider Config**: Requires `AI_PROVIDERS` environment variable for analysis features

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
