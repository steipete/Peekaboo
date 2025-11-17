# Peekaboo MCP: Lightning-fast macOS Screenshots & GUI Automation 🚀

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS (Sonoma)](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D20.0.0-brightgreen.svg)](https://nodejs.org/)
[![Download for macOS](https://img.shields.io/badge/Download-macOS-black?logo=apple)](https://github.com/steipete/peekaboo/releases/latest)
[![Homebrew](https://img.shields.io/badge/Homebrew-steipete%2Ftap-tan?logo=homebrew)](https://github.com/steipete/homebrew-tap)
<a href="https://deepwiki.com/steipete/peekaboo"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>

> 🎉 **NEW in v3**: Complete GUI automation framework with AI Agent! Click, type, scroll, and automate any macOS application using natural language. Plus comprehensive menu bar extraction without clicking! See the [GUI Automation section](#-gui-automation-with-peekaboo-v3) and [AI Agent section](#-ai-agent-automation) for details.

Peekaboo is a powerful macOS utility for capturing screenshots, analyzing them with AI vision models, and now automating GUI interactions. It works both as a **standalone CLI tool** (recommended) and as an **MCP server** for AI assistants like Claude Desktop and Cursor.

## 🎯 Choose Your Path

### 🖥️ **CLI Tool** (Recommended for Most Users)
Perfect for:
- Command-line workflows and automation
- Shell scripts and CI/CD pipelines  
- Quick screenshots and AI analysis
- System administration tasks

### 👻 **MCP Server** (For AI Assistants)
Perfect for:
- Claude Desktop integration
- Cursor IDE workflows
- AI agents that need visual context
- Interactive AI debugging sessions

## What is Peekaboo?

Peekaboo bridges the gap between visual content on your screen and AI understanding. It provides:

- **Lightning-fast screenshots** of screens, applications, or specific windows
- **AI-powered image analysis** using GPT-4.1 Vision, Claude, Grok, or local models (Ollama)
- **Complete GUI automation** (v3) - Click, type, scroll, and interact with any macOS app
- **Natural language automation** (v3) - AI agent that understands tasks like "Open TextEdit and write a poem"
- **Smart UI element detection** - Automatically identifies buttons, text fields, links, and more with precise coordinate mapping
- **Menu bar extraction** (v3) - Discover all menus and keyboard shortcuts without clicking or opening menus
- **Automatic session resolution** - Commands intelligently use the most recent session (no manual tracking!)
- **Window and application management** with smart fuzzy matching
- **Multi-screen support** - List which screen windows are on and move them between displays
- **Privacy-first operation** with local AI options via Ollama
- **Non-intrusive capture** without changing window focus
- **Automation scripting** - Chain commands together for complex workflows

### 🏗️ Architecture

Peekaboo now composes three focused SwiftPM targets plus a thin umbrella:

- **PeekabooAutomation** – Screen capture, permissions, accessibility services, menu/window helpers, and every strongly typed model shared across apps.
- **PeekabooAgentRuntime** – Tool registry, MCP server tooling, streaming/agent glue. Nothing here touches AppKit directly; it consumes the automation protocols.
- **PeekabooVisualizer** – Event serialization and UI feedback for the macOS app + CLI visual overlays.
- **PeekabooCore** – `_exported` shim that re-exports the three modules so downstream targets can continue to `import PeekabooCore` while opting into narrower modules when desired.
- **CLI** – Command-line interface that injects a `PeekabooServices()` instance into commander commands and agents.
- **Mac App** – Native macOS GUI that keeps a long-lived `@State private var services = PeekabooServices()` and passes it through SwiftUI scenes.
- **MCP Server** – Model Context Protocol server for AI assistants (Claude Desktop, Cursor, etc.) built entirely on `PeekabooAgentRuntime`.
- **Commander** (in-repo) – Lightweight Swift 6 parsing helpers used by the CLI runtime (swift-tools-version 6.0, no Swift 6.2+ features).

The CLI command structs remain `@MainActor` so they run on the main thread, but the static `commandDescription` can just be a normal `static let` constant—no `nonisolated(unsafe)` or extra `@MainActor` wrappers are necessary when describing the command metadata.

All components share the same core services, ensuring consistent behavior and optimal performance. See [Service API Reference](docs/service-api-reference.md) for detailed documentation.

#### Embedding Peekaboo services

The legacy singleton is gone—if you construct `PeekabooServices()` yourself (e.g., tests, daemon, or a new host), call `services.installAgentRuntimeDefaults()` **once** after initialization so MCP tools, the ToolRegistry, and `PeekabooAgentService` share that instance:

```swift
@MainActor
let services = PeekabooServices()
services.installAgentRuntimeDefaults()

let agent = try PeekabooAgentService(services: services)
```

Skipping the install step will cause MCP/ToolRegistry APIs to fatal with “default factory not configured” because there’s no hidden global anymore.

### Git Submodules

Peekaboo vendors three shared dependencies as top-level git submodules:

| Path        | Purpose                               |
|-------------|---------------------------------------|
| `AXorcist/` | Accessibility automation primitives   |
| `Commander/`| Swift command parser used by the CLI  |
| `Tachikoma/`| AI provider + MCP integrations        |

Clone with `git clone --recursive` or run `git submodule update --init --recursive` after pulling to ensure all three are present.

#### Submodule Details (updated)
- `AXorcist` is our accessibility engine: it wraps the macOS AX APIs with type-safe Swift helpers so every command (and agent) can discover UI elements, grant permissions, and drive buttons/text fields without reinventing accessibility plumbing. Because the underlying APIs are macOS-only we keep AXorcist’s CI and release targets scoped to macOS 14+.
- `Commander` is the shared parser/runtime that replaces Swift Argument Parser across Peekaboo. It provides property-wrapper metadata, a central router, standard CLI flags, and binders that hydrate existing command structs while keeping the runtime @MainActor-friendly. Commander’s CI spans macOS, Linux, Apple simulators (iOS/tvOS/watchOS/visionOS), and Android (via `--swift-sdk android`).
- `Tachikoma` is the AI provider SDK plus MCP adapters. It now owns all credential/OAuth handling via `TKAuthManager` and exposes the standalone `tk-config` CLI (add/login/status) so hosts can reuse the same auth + validation flows. Peekaboo’s CLI delegates provider auth to Tachikoma; set `TachikomaConfiguration.profileDirectoryName` to `.peekaboo` to share credentials.

## 🧩 Platform Support

| Component | Supported OS targets | Notes |
| --- | --- | --- |
| Peekaboo CLI + Mac app | macOS 14.0+ | Everything ships as a native macOS product; CI only runs on macOS runners so we can exercise ScreenCaptureKit and Accessibility APIs. |
| AXorcist | macOS 14.0+ | Accessibility frameworks are macOS-only, so both the library and its CLI stay scoped to macOS. |
| Commander | macOS, Linux, Apple simulators (iOS/tvOS/watchOS/visionOS), Android (aarch64) | CI installs Swift toolchains via Swiftly, runs `xcodebuild` against each simulator platform, and cross-compiles with `--swift-sdk android` so Commander stays portable on the platforms we actively test. |
| Tachikoma | macOS, Linux, Apple simulators (iOS/tvOS/watchOS/visionOS), Android (aarch64) | Matches Commander’s matrix and additionally runs the Android cross-compilation plus the Apple destination builds for provider SDK validation. |

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

### Command Catalog

Peekaboo ships many focused commands. Each entry below links to a short doc in `docs/commands/` with complete flag tables, workflows, and troubleshooting notes.

#### Vision & Capture
- [`see`](docs/commands/see.md) – Capture annotated UI maps, produce session IDs, and optionally run inline analysis.
- [`image`](docs/commands/image.md) – Grab raw PNG/JPG screenshots (screens, windows, menu bar) and feed them into AI with `--analyze`.

#### Core Utilities
- [`list`](docs/commands/list.md) – Subcommands: `apps`, `windows`, `screens`, `menubar`, `permissions`.
- [`tools`](docs/commands/tools.md) – Enumerate native + MCP tools; filter by server/source.
- [`config`](docs/commands/config.md) – Subcommands: `init`, `show`, `edit`, `validate`, `set-credential`, `add-provider`, `list-providers`, `test-provider`, `remove-provider`, `models`.
- [`permissions`](docs/commands/permissions.md) – `status` (default) and `grant` helpers for Screen Recording, Accessibility, etc.
- [`learn`](docs/commands/learn.md) – Emit the full agent guide/system prompt/Commander signature dump.
- [`run`](docs/commands/run.md) – Execute `.peekaboo.json` automation scripts (`--output`, `--no-fail-fast`).
- [`sleep`](docs/commands/sleep.md) – Millisecond delays between scripted steps.
- [`clean`](docs/commands/clean.md) – Prune session caches via `--all-sessions`, `--older-than`, or `--session`.

#### Interaction
- [`click`](docs/commands/click.md) – Element IDs, fuzzy queries, or coordinates; built-in wait/focus helpers.
- [`type`](docs/commands/type.md) – Text + escape sequences, `--clear`, tab/return/escape/delete flags.
- [`press`](docs/commands/press.md) – Special key sequences with repeat counts.
- [`hotkey`](docs/commands/hotkey.md) – Modifier combos such as `cmd,shift,t` (terminal-safe parsing).
- [`scroll`](docs/commands/scroll.md) – Directional scrolls with optional element targets.
- [`swipe`](docs/commands/swipe.md) – Smooth drags between IDs or coordinates (`--duration`, `--steps`).
- [`drag`](docs/commands/drag.md) – Drag-and-drop, modifiers, Dock/Trash targets.
- [`move`](docs/commands/move.md) – Cursor placement (coords, element IDs, queries, or screen center).

#### Windows, Menus, Apps, Spaces
- [`window`](docs/commands/window.md) – Subcommands: `close`, `minimize`, `maximize`, `move`, `resize`, `set-bounds`, `focus`, `list`.
- [`menu`](docs/commands/menu.md) – `click`, `click-extra`, `list`, `list-all` for app menus and menu extras.
- [`menubar`](docs/commands/menubar.md) – `list`/`click` status-bar items by name or index.
- [`app`](docs/commands/app.md) – `launch`, `quit`, `relaunch`, `hide`, `unhide`, `switch`, `list`.
- [`open`](docs/commands/open.md) – macOS-style `open` with Peekaboo focus/failure handling.
- [`dock`](docs/commands/dock.md) – `launch`, `right-click`, `hide`, `show`, `list` for Dock entries.
- [`dialog`](docs/commands/dialog.md) – `click`, `input`, `file`, `dismiss`, `list` system dialogs.
- [`space`](docs/commands/space.md) – `list`, `switch`, `move-window` (Spaces/virtual desktops).

#### Agents & Integrations
- [`agent`](docs/commands/agent.md) – Natural-language automation (`--dry-run`, `--resume`, `--model`, audio options, session caching).
- [`mcp`](docs/commands/mcp.md) – `serve`, `list`, `add`, `remove`, `enable`, `disable`, `info`, `test`, `call`, `inspect` (stub) for Model Context Protocol workflows.

Each doc contains exhaustive flag descriptions and examples; the README only covers intent and grouping. Use `peekaboo <command> --help` for inline summaries.

### Debugging with Verbose Mode

All Peekaboo commands support the `--verbose` or `-v` flag for detailed logging:

```bash
# See what's happening under the hood
peekaboo image --app Safari --verbose
peekaboo see --app Terminal -v
peekaboo click --on B1 --verbose

# Verbose output includes:
# - Application search details
# - Window discovery information
# - UI element detection progress
# - Timing information
# - Session management operations
```

Verbose logs are written to stderr with timestamps:
```
[2025-01-06T08:05:23Z] VERBOSE: Searching for application: Safari
[2025-01-06T08:05:23Z] VERBOSE: Found exact bundle ID match: Safari
[2025-01-06T08:05:23Z] VERBOSE: Capturing window for app: Safari
[2025-01-06T08:05:23Z] VERBOSE: Found 3 windows for application
```

This is invaluable for:
- Debugging automation scripts
- Understanding why elements aren't found
- Performance optimization
- Learning Peekaboo's internals

### Configuration

Peekaboo uses a unified configuration directory at `~/.peekaboo/` for better discoverability:

```bash
# Create default configuration
peekaboo config init

# Files created:
# ~/.peekaboo/config.json     - Main configuration (JSONC format)
# ~/.peekaboo/credentials     - API keys (chmod 600)
```

#### Managing API Keys Securely

```bash
# Set API key securely (stored in ~/.peekaboo/credentials)
peekaboo config set-credential OPENAI_API_KEY sk-...

# View current configuration (keys shown as ***SET***)
peekaboo config show --effective
```

#### Example Configuration

`~/.peekaboo/config.json`:
```json
{
  // AI Provider Settings
  "aiProviders": {
    "providers": "openai/gpt-4.1,anthropic/claude-opus-4,grok/grok-4,ollama/llava:latest",
    // NOTE: API keys should be in ~/.peekaboo/credentials
    "ollamaBaseUrl": "http://localhost:11434"
  },
  
  // Default Settings
  "defaults": {
    "savePath": "~/Desktop/Screenshots",
    "imageFormat": "png",
    "captureMode": "window",
    "captureFocus": "auto"
  },
  
  // Logging
  "logging": {
    "level": "info",
    "path": "~/.peekaboo/logs/peekaboo.log"
  }
}
```

`~/.peekaboo/credentials` (auto-created with proper permissions):
```
# Peekaboo credentials file
# This file contains sensitive API keys and should not be shared
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
X_AI_API_KEY=xai-...
```

### Common Workflows

```bash
# Capture and analyze in one command
peekaboo image --app Safari --analyze "What's on this page?" --path /tmp/page.png

# Monitor active window changes
while true; do
  peekaboo image --mode frontmost --json-output | jq -r '.data.saved_files[0].window_title'
  sleep 5
done

# Batch analyze screenshots
for img in ~/Screenshots/*.png; do
  peekaboo image --analyze "Summarize this screenshot" --path "$img"
done

# Automated login workflow (v3 with automatic session resolution)
peekaboo see --app MyApp                # Creates new session
peekaboo click --on T1                  # Automatically uses session from 'see'
peekaboo type "user@example.com"        # Still using same session
peekaboo press tab                      # Press Tab to move to next field
peekaboo type "password123"
peekaboo press return                   # Press Enter to submit
peekaboo sleep 2000                     # Wait 2 seconds

# Multiple app automation with explicit sessions
SESSION_A=$(peekaboo see --app Safari --json-output | jq -r '.data.session_id')
SESSION_B=$(peekaboo see --app Notes --json-output | jq -r '.data.session_id')
peekaboo click --on B1 --session $SESSION_A  # Click in Safari
peekaboo type "Hello" --session $SESSION_B   # Type in Notes

# Run automation script
peekaboo run login.peekaboo.json
```

## 👻 MCP Server Setup

For AI assistants like Claude Desktop and Cursor, Peekaboo provides a Model Context Protocol (MCP) server.

### For Claude Desktop

1. Open Claude Desktop Settings (from the **menubar**, not the in-app settings)
2. Navigate to Developer → Edit Config
3. Add the Peekaboo MCP server configuration:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": ["-y", "@steipete/peekaboo-mcp@beta"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4,openai/gpt-4.1,ollama/llava:latest",
        "OPENAI_API_KEY": "your-openai-api-key-here"
      }
    }
  }
}
```

4. Save and restart Claude Desktop

### For Claude Code

Run the following command:

```bash
claude mcp add-json peekaboo '{
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@steipete/peekaboo-mcp"],
  "env": {
    "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4,openai/gpt-4.1,ollama/llava:latest",
    "OPENAI_API_KEY": "your-openai-api-key-here"
  }
}'
```

Alternatively, if you've already installed the server via Claude Desktop, you can import it:

```bash
claude mcp add-from-claude-desktop
```

### Local Development

For local development, use the built MCP server directly:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "node",
      "args": ["/path/to/peekaboo/Server/dist/index.js"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4"
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
      "args": ["-y", "@steipete/peekaboo-mcp@beta"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "openai/gpt-4.1,ollama/llava:latest",
        "OPENAI_API_KEY": "your-openai-api-key-here"
      }
    }
  }
}
```

## 🔗 MCP Client Integration

Peekaboo v3 now functions as both an MCP server (exposing its tools) and an MCP client (consuming external tools). This enables powerful workflows that combine Peekaboo's native automation with tools from the broader MCP ecosystem.

### Default Integration: Chrome DevTools MCP

Peekaboo ships with the [Chrome DevTools MCP](https://chrome-devtools-mcp.modelcontextprotocol.io) enabled by default, providing Chromium automation via the DevTools protocol:

```bash
# Chrome DevTools tools are available immediately
peekaboo tools --mcp-only                     # List only external MCP tools  
peekaboo tools --mcp chrome-devtools          # Show Chrome DevTools MCP tools specifically
peekaboo agent "Navigate to github.com and click the sign up button"  # Uses chrome-devtools:navigate_page + click
```

### Managing External MCP Servers

```bash
# List all configured servers with health status
peekaboo mcp list

# Add popular MCP servers
peekaboo mcp add github -e GITHUB_TOKEN=ghp_xxx -- npx -y @modelcontextprotocol/server-github
peekaboo mcp add files -- npx -y @modelcontextprotocol/server-filesystem ~/Documents

# Test server connection
peekaboo mcp test github --show-tools

# Enable/disable servers
peekaboo mcp disable chrome-devtools    # Disable default Chrome DevTools MCP
peekaboo mcp enable github              # Re-enable a server
```

### Configuration

External servers are configured in `~/.peekaboo/config.json`. To disable Chrome DevTools MCP:

```json
{
  "mcpClients": {
    "chrome-devtools": {
      "enabled": false
    }
  }
}
```

### Available External Tools

All external tools are prefixed with their server name:

- **chrome-devtools:navigate_page** - Navigate to URL (Chrome DevTools MCP)
- **chrome-devtools:click** - Click elements on webpage (Chrome DevTools MCP)  
- **chrome-devtools:screenshot** - Take webpage screenshot (Chrome DevTools MCP)
- **github:create_issue** - Create GitHub issues (GitHub server)
- **files:read_file** - Read files (Filesystem server)

The AI agent automatically uses the best combination of native and external tools for each task.

See [docs/mcp-client.md](docs/mcp-client.md) for complete documentation.

### MCP Tools Available

#### Core Tools
1. **`image`** - Capture screenshots (with optional AI analysis via question parameter)
2. **`list`** - List applications, windows, or check server status
3. **`analyze`** - Analyze existing images with AI vision models (MCP-only tool, use `peekaboo image --analyze` in CLI)

#### UI Automation Tools
4. **`see`** - Capture screen and identify UI elements
5. **`click`** - Click on UI elements or coordinates
6. **`type`** - Type text into UI elements (supports escape sequences)
7. **`press`** - Press individual keys (return, tab, escape, arrows, etc.)
8. **`scroll`** - Scroll content in any direction
9. **`hotkey`** - Press keyboard shortcuts
10. **`swipe`** - Perform swipe/drag gestures
11. **`move`** - Move mouse cursor to specific position or element
12. **`drag`** - Perform drag and drop operations

#### Application & Window Management
13. **`app`** - Launch, quit, focus, hide, and manage applications
14. **`window`** - Manipulate windows (close, minimize, maximize, move, resize, focus)
15. **`menu`** - Interact with application menus and system menu extras
16. **`dock`** - Launch apps from dock and manage dock items
17. **`dialog`** - Handle dialog windows (click buttons, input text)
18. **`space`** - Manage macOS Spaces (virtual desktops)

#### Utility Tools
19. **`run`** - Execute automation scripts from .peekaboo.json files
20. **`sleep`** - Pause execution for specified duration
21. **`clean`** - Clean up session cache and temporary files
22. **`permissions`** - Check system permissions (screen recording, accessibility)
23. **`agent`** - Execute complex automation tasks using AI

## 📟 CLI Command Reference

Full command descriptions now live in [docs/cli-command-reference.md](docs/cli-command-reference.md).

## 🚀 GUI Automation with Peekaboo v3

Peekaboo v3 introduces powerful GUI automation capabilities, transforming it from a screenshot tool into a complete UI automation framework for macOS. This enables AI assistants to interact with any application through natural language commands.

### How It Works

The v3 automation system uses a **see-then-interact** workflow:

1. **See** - Capture the screen and identify UI elements
2. **Interact** - Click, type, scroll, or perform other actions
3. **Verify** - Capture again to confirm the action succeeded

### 🎯 The `see` Tool - UI Element Discovery

The `see` tool is the foundation of GUI automation. It captures a screenshot and identifies all interactive UI elements, assigning them unique Peekaboo IDs.

```typescript
// Example: See what's on screen
await see({ app_target: "Safari" })

// Multi-screen support - capture all screens
await see({ app_target: "" })  // Empty string captures all screens

// Capture specific screen by index
await see({ app_target: "screen:0" })  // Primary screen
await see({ app_target: "screen:1" })  // Second screen

// Returns:
{
  screenshot_path: "/tmp/peekaboo_123.png",
  session_id: "session_456",
  elements: {
    buttons: [
      { id: "B1", label: "Submit", bounds: { x: 100, y: 200, width: 80, height: 30 } },
      { id: "B2", label: "Cancel", bounds: { x: 200, y: 200, width: 80, height: 30 } }
    ],
    text_fields: [
      { id: "T1", label: "Email", value: "", bounds: { x: 100, y: 100, width: 200, height: 30 } },
      { id: "T2", label: "Password", value: "", bounds: { x: 100, y: 150, width: 200, height: 30 } }
    ],
    links: [
      { id: "L1", label: "Forgot password?", bounds: { x: 100, y: 250, width: 120, height: 20 } }
    ],
    // ... other elements
  }
}
```

#### Discovering Available Screens

Before capturing specific screens, you can list all connected displays:

```bash
# List all screens with details
peekaboo list screens

# Example output:
# Screens (3 total):
# 
# 0. Built-in Display (Primary)
#    Resolution: 3008×1692
#    Position: 0,0
#    Scale: 2.0x (Retina)
#    Visible Area: 3008×1612
# 
# 1. External Display
#    Resolution: 3840×2160
#    Position: 3008,0
#    Scale: 2.0x (Retina)
# 
# 2. Studio Display
#    Resolution: 5120×2880
#    Position: -5120,0
#    Scale: 2.0x (Retina)
# 
# 💡 Use 'peekaboo see --screen-index N' to capture a specific screen

# Get JSON output for scripting
peekaboo list screens --json-output
```

This command shows:
- **Screen index**: Use with `see --screen-index` or `image --screen-index`
- **Display name**: Built-in, External, or specific model names
- **Resolution**: Full screen resolution
- **Position**: Coordinates in the unified desktop space
- **Scale factor**: Retina display information
- **Visible area**: Usable area (excluding menu bar on primary screen)

#### Multi-Screen Capture
When capturing multiple screens, Peekaboo automatically saves each screen as a separate file:
- Primary screen: `screenshot.png`
- Additional screens: `screenshot_screen1.png`, `screenshot_screen2.png`, etc.

Display information (name, resolution) is shown for each captured screen:
```
📸 Captured 3 screens:
   🖥️  Display 0: Built-in Retina Display (2880×1800) → screenshot.png
   🖥️  Display 1: LG Ultra HD (3840×2160) → screenshot_screen1.png
   🖥️  Display 2: Studio Display (5120×2880) → screenshot_screen2.png
```

**Note**: Annotation is automatically disabled for full screen captures due to performance constraints.

#### Element ID Format
- **B1, B2...** - Buttons
- **T1, T2...** - Text fields/areas
- **L1, L2...** - Links
- **G1, G2...** - Groups/containers
- **I1, I2...** - Images
- **S1, S2...** - Sliders
- **C1, C2...** - Checkboxes/toggles
- **M1, M2...** - Menu items

### 🖱️ The `click` Tool

Click on UI elements using various targeting methods:

```typescript
// Click by element ID from see command
await click({ on: "B1" })

// Click by query (searches button labels)
await click({ query: "Submit" })

// Click by coordinates
await click({ coords: "450,300" })

// Double-click
await click({ on: "I1", double: true })

// Right-click
await click({ query: "File", right: true })

// With custom wait timeout
await click({ query: "Save", wait_for: 10000 })
```

### ⌨️ The `type` Tool

Type text with support for escape sequences:

```typescript
// Type into a specific field
await type({ text: "user@example.com", on: "T1" })

// Type at current focus
await type({ text: "Hello world" })

// Clear existing text first
await type({ text: "New text", on: "T2", clear: true })

// Use escape sequences
await type({ text: "Line 1\nLine 2\nLine 3" })         // Newlines
await type({ text: "Name:\tJohn\tDoe" })                // Tabs
await type({ text: "Path: C:\\data\\file.txt" })        // Literal backslash

// Press return after typing
await type({ text: "Submit", press_return: true })

// Adjust typing speed
await type({ text: "Slow typing", delay: 100 })
```

#### Supported Escape Sequences
- `\n` - Newline/return
- `\t` - Tab
- `\b` - Backspace/delete
- `\e` - Escape
- `\\` - Literal backslash

### 🔑 The `press` Tool

Press individual keys or key sequences:

```typescript
// Press single keys
await press({ key: "return" })                          // Press Enter
await press({ key: "tab", count: 3 })                   // Press Tab 3 times
await press({ key: "escape" })                          // Press Escape

// Navigation keys
await press({ key: "up" })                             // Arrow up
await press({ key: "down", count: 5 })                 // Arrow down 5 times
await press({ key: "home" })                           // Home key
await press({ key: "end" })                            // End key

// Function keys
await press({ key: "f1" })                             // F1 help key
await press({ key: "f11" })                            // F11 full screen

// Special keys
await press({ key: "forward_delete" })                 // Forward delete (fn+delete)
await press({ key: "caps_lock" })                      // Caps Lock
```

#### Available Keys
- **Navigation**: up, down, left, right, home, end, pageup, pagedown
- **Editing**: delete (backspace), forward_delete, clear
- **Control**: return, enter, tab, escape, space
- **Function**: f1-f12
- **Special**: caps_lock, help

### 📜 The `scroll` Tool

Scroll content in any direction:

```typescript
// Scroll down 3 ticks (default)
await scroll({ direction: "down" })

// Scroll up 5 ticks
await scroll({ direction: "up", amount: 5 })

// Scroll on a specific element
await scroll({ direction: "down", on: "G1", amount: 10 })

// Smooth scrolling
await scroll({ direction: "down", smooth: true })

// Horizontal scrolling
await scroll({ direction: "right", amount: 3 })
```

### ⌨️ The `hotkey` Tool

Press keyboard shortcuts:

```typescript
// Common shortcuts
await hotkey({ keys: "cmd,c" })        // Copy
await hotkey({ keys: "cmd,v" })        // Paste
await hotkey({ keys: "cmd,tab" })      // Switch apps
await hotkey({ keys: "cmd,shift,t" })  // Reopen closed tab

// Function keys
await hotkey({ keys: "f11" })          // Full screen

// Custom hold duration
await hotkey({ keys: "cmd,space", hold_duration: 100 })
```

### 👆 The `swipe` Tool

Perform swipe or drag gestures:

```typescript
// Basic swipe
await swipe({ from: "100,200", to: "300,200" })

// Slow drag
await swipe({ from: "50,50", to: "200,200", duration: 2000 })

// Precise movement with more steps
await swipe({ from: "0,0", to: "100,100", steps: 50 })
```

### 🖱️ The `move` Tool

Move the mouse cursor to specific positions or UI elements:

```typescript
// Move to absolute coordinates
await move({ coordinates: "500,300" })

// Move to center of screen
await move({ center: true })

// Move to a specific UI element
await move({ id: "B1" })

// Smooth movement with animation
await move({ coordinates: "100,200", smooth: true, duration: 1000 })
```

### 🎯 The `drag` Tool

Perform drag and drop operations between UI elements or coordinates:

```typescript
// Drag from one element to another
await drag({ from: "B1", to: "T1" })

// Drag using coordinates
await drag({ from_coords: "100,100", to_coords: "500,500" })

// Drag with modifiers (e.g., holding shift)
await drag({ from: "I1", to: "G2", modifiers: "shift" })

// Cross-application drag
await drag({ from: "T1", to_app: "Finder", to_coords: "300,400" })
```

### 🔐 The `permissions` Tool

Check macOS system permissions required for automation:

```typescript
// Check all permissions
await permissions({})

// Returns permission status for:
// - Screen Recording (required for screenshots)
// - Accessibility (required for UI automation)
```

### 📝 The `run` Tool - Automation Scripts

Execute complex automation workflows from JSON script files:

```typescript
// Run a script
await run({ script_path: "/path/to/login.peekaboo.json" })

// Continue on error
await run({ script_path: "test.peekaboo.json", no_fail_fast: true })
```

#### Script Format (.peekaboo.json)

```json
{
  "name": "Login to Website",
  "description": "Automated login workflow",
  "commands": [
    {
      "command": "see",
      "args": { "app_target": "Safari" },
      "comment": "Capture current state"
    },
    {
      "command": "click",
      "args": { "query": "Email" },
      "comment": "Click email field"
    },
    {
      "command": "type",
      "args": { "text": "user@example.com" }
    },
    {
      "command": "click",
      "args": { "query": "Password" }
    },
    {
      "command": "type",
      "args": { "text": "secure_password" }
    },
    {
      "command": "click",
      "args": { "query": "Sign In" }
    },
    {
      "command": "sleep",
      "args": { "duration": 2000 },
      "comment": "Wait for login"
    }
  ]
}
```

### 🎯 Automatic Window Focus Management

Peekaboo v3 includes intelligent window focus management that ensures your automation commands target the correct window, even across different macOS Spaces (virtual desktops).

#### How Focus Management Works

All interaction commands (`click`, `type`, `scroll`, `menu`, `hotkey`, `drag`) automatically:
1. **Track window identity** - Using stable window IDs that persist across interactions
2. **Detect window location** - Find which Space contains the target window
3. **Switch Spaces if needed** - Automatically switch to the window's Space
4. **Focus the window** - Ensure the window is frontmost before interaction
5. **Verify focus** - Confirm the window is ready before proceeding

#### Focus Options

All interaction commands support these focus-related flags:

```bash
# Disable automatic focus (not recommended)
peekaboo click "Submit" --no-auto-focus

# Set custom focus timeout (default: 5 seconds)
peekaboo type "Hello" --focus-timeout 10

# Set retry count for focus operations (default: 3)
peekaboo menu click --app Safari --item "New Tab" --focus-retry-count 5

# Control Space switching behavior
peekaboo click "Login" --space-switch          # Force Space switch
peekaboo type "text" --bring-to-current-space  # Move window to current Space
```

#### Space Management Commands

Peekaboo provides dedicated commands for managing macOS Spaces:

```bash
# List all Spaces
peekaboo space list

# Switch to a specific Space
peekaboo space switch --to 2

# Move windows between Spaces
peekaboo space move-window --app Safari --to 3

# Use list to see which Space contains windows
peekaboo space list  # Shows all Spaces and their windows
```

#### Window Focus Command

For explicit window focus control:

```bash
# Focus a window (switches Space if needed)
peekaboo window focus --app Safari

# Focus without switching Spaces (space-switch is a flag, not an option with value)
peekaboo window focus --app Terminal  # Default is to not switch spaces unless needed

# Move window to current Space and focus
peekaboo window focus --app "VS Code" --bring-to-current-space
```

#### Focus Behavior

By default, Peekaboo:
- **Automatically focuses windows** before any interaction
- **Switches Spaces** when the target window is on a different desktop
- **Waits for focus** to ensure the window is ready
- **Retries if needed** with exponential backoff

This ensures reliable automation across complex multi-window, multi-Space workflows without manual window management.

## 👻 AI Agent Automation

Peekaboo v3 introduces an AI-powered agent that can understand and execute complex automation tasks using natural language. The agent uses OpenAI's Chat Completions API with streaming support to break down your instructions into specific Peekaboo commands.

### Setting Up the Agent

```bash
# Set your API key (OpenAI, Anthropic, or Grok)
export OPENAI_API_KEY="your-openai-key-here"
# OR
export ANTHROPIC_API_KEY="your-anthropic-key-here"
# OR
export X_AI_API_KEY="your-grok-key-here"

# Or save it securely in Peekaboo's config
peekaboo config set-credential OPENAI_API_KEY your-api-key-here
peekaboo config set-credential ANTHROPIC_API_KEY your-anthropic-key-here
peekaboo config set-credential X_AI_API_KEY your-grok-key-here

# Now you can use natural language automation!
peekaboo "Open Safari and search for weather"
peekaboo agent "Fill out the form" --model grok-4-fast-reasoning
peekaboo agent "Create a document" --model claude-opus-4
```

### Two Ways to Use the Agent

#### 1. Direct Natural Language (Default)
When you provide a text argument without a subcommand, Peekaboo automatically uses the agent:

```bash
# These all invoke the agent directly
peekaboo "Click the Submit button"
peekaboo "Open TextEdit and write Hello"
peekaboo "Take a screenshot of Safari"
```

#### 2. Explicit Agent Command
Use the `agent` subcommand for more control and options:

```bash
# With options and flags
peekaboo agent "Fill out the contact form" --verbose
peekaboo agent "Close all Finder windows" --dry-run
peekaboo agent "Install this app" --max-steps 30 --json-output
```

### How the Agent Works

1. **Understands Your Intent** - The AI agent analyzes your natural language request
2. **Plans the Steps** - Breaks down the task into specific actions
3. **Executes Commands** - Uses Peekaboo's automation tools to perform each step
4. **Verifies Results** - Takes screenshots to confirm actions succeeded
5. **Handles Errors** - Can retry failed actions or adjust approach

### Real-World Examples

```bash
# Web Automation
peekaboo "Go to github.com and search for peekaboo"
peekaboo "Click the first search result"
peekaboo "Star this repository"

# Document Creation
peekaboo "Open Pages and create a new blank document"
peekaboo "Type 'Meeting Agenda' as the title and make it bold"
peekaboo "Add bullet points for Introduction, Main Topics, and Action Items"

# File Management
peekaboo "Open Finder and navigate to Downloads"
peekaboo "Select all PDF files and move them to Documents"
peekaboo "Create a new folder called 'Archived PDFs'"

# Application Testing
peekaboo "Launch Calculator and calculate 42 * 17"
peekaboo "Take a screenshot of the result"
peekaboo "Clear the calculator and close it"

# System Tasks
peekaboo "Open System Settings and go to Display settings"
peekaboo "Change the display resolution to 1920x1080"
peekaboo "Take a screenshot to confirm the change"
```

### Agent Options

- `--verbose` - See the agent's reasoning and planning process
- `--dry-run` - Preview what the agent would do without executing
- `--max-steps <n>` - Limit the number of actions (default: 20)
- `--model <model>` - Choose OpenAI model (default: gpt-4-turbo)
- `--json-output` - Get structured JSON output
- `--resume` - Resume the latest unfinished agent session
- `--resume <session-id>` - Resume a specific session by ID

### Agent Capabilities

The agent has access to all Peekaboo commands:
- **Visual Understanding** - Can see and understand what's on screen
- **UI Interaction** - Click buttons, fill forms, navigate menus
- **Text Entry** - Type text, use keyboard shortcuts
- **Window Management** - Open, close, minimize, arrange windows
- **Application Control** - Launch apps, switch between them
- **File Operations** - Save files, handle dialogs
- **Complex Workflows** - Chain multiple actions together
- **Multiple AI Models** - Supports OpenAI (GPT-4o, o3), Anthropic (Claude), and Grok (xAI)

### Understanding Agent Execution

When you run an agent command, here's what happens behind the scenes:

```bash
# Your command:
peekaboo "Click the Submit button"

# Agent breaks it down into:
peekaboo see                    # Capture screen and identify elements
peekaboo click "Submit"         # Click the identified button
```

### Example Workflow

```bash
# Complex multi-step task
peekaboo agent --verbose "Create a new document in Pages with the title 'Meeting Notes' and add today's date"

# Agent will execute commands like:
# 1. peekaboo see --app Pages              # Check if Pages is open
# 2. peekaboo app launch Pages             # Launch if needed
# 3. peekaboo sleep --duration 2000        # Wait for app to load
# 4. peekaboo click "Create Document"      # Click new document
# 5. peekaboo type "Meeting Notes"         # Enter title
# 6. peekaboo hotkey cmd+b                 # Make text bold
# 7. peekaboo hotkey return                # New line
# 8. peekaboo type "Date: $(date)"         # Add current date

# Relaunch an application (useful for applying settings or fixing issues)
peekaboo app relaunch Safari              # Quit and restart Safari
peekaboo app relaunch "Visual Studio Code" --wait 3 --wait-until-ready

# Open URLs or documents via Peekaboo (instead of raw `open`)
peekaboo open https://example.com --json-output
peekaboo open ~/Documents/report.pdf --app "Preview" --wait-until-ready

# Launch an app and hand it documents/URLs immediately
peekaboo app launch "Safari" \
  --open https://news.ycombinator.com \
  --open https://example.com/status \
  --no-focus
```

### Debugging Agent Actions

Use `--verbose` to see exactly what the agent is doing:

```bash
peekaboo agent --verbose "Find and click the login button"

# Output will show:
# [Agent] Analyzing request...
# [Agent] Planning steps:
#   1. Capture current screen
#   2. Identify login button
#   3. Click on the button
# [Agent] Executing: peekaboo see
# [Agent] Found elements: button "Login" at (834, 423)
# [Agent] Executing: peekaboo click "Login"
# [Agent] Action completed successfully
```

### Tips for Best Results

1. **Be Specific** - "Click the blue Submit button" works better than "submit"
2. **One Task at a Time** - Break complex workflows into smaller tasks
3. **Verify State** - The agent works best when it can see the current screen
4. **Use Verbose Mode** - Add `--verbose` to understand what the agent is doing
5. **Set Reasonable Limits** - Use `--max-steps` to prevent runaway automation

### Resuming Agent Sessions

The agent supports resuming interrupted or incomplete sessions, maintaining full conversation context:

```bash
# Start a complex task
peekaboo agent "Help me write a document about automation"
# Agent creates document, starts writing...
# <Interrupted by Ctrl+C or error>

# Resume the latest session with context
peekaboo agent --resume "Continue where we left off"

# Or resume a specific session
peekaboo agent --resume session_abc123 "Add a conclusion section"

# List available sessions
peekaboo agent --list-sessions

# Note: There is no show-session command, use list-sessions to see all sessions
```

#### How Resume Works

1. **Session Persistence** - Each agent run creates a session with a unique ID
2. **Thread Continuity** - Uses OpenAI's thread persistence to maintain conversation history
3. **Context Preservation** - The AI remembers all previous interactions in the session
4. **Smart Recovery** - Can continue from any point, understanding what was already done

#### Resume Examples

```bash
# Scenario 1: Continue an interrupted task
peekaboo agent "Create a presentation about AI"
# <Interrupted after creating first slide>
peekaboo agent --resume "Add more slides about machine learning"

# Scenario 2: Iterative refinement
peekaboo agent "Fill out this form with test data"
# <Agent completes task>
peekaboo agent --resume "Actually, change the email to test@example.com"

# Scenario 3: Debugging automation
peekaboo agent --verbose "Login to the portal"
# <Login fails>
peekaboo agent --resume --verbose "Try clicking the other login button"
```

### ⏸️ The `sleep` Tool

Pause execution between actions:

```typescript
// Sleep for 1 second
await sleep({ duration: 1000 })

// Sleep for 500ms
await sleep({ duration: 500 })
```

### 🪟 The `window` Tool

Comprehensive window manipulation for any application:

```typescript
// Close window
await window({ action: "close", app: "Safari" })
await window({ action: "close", app: "Safari", title: "Downloads" })

// Minimize/Maximize
await window({ action: "minimize", app: "Finder" })
await window({ action: "maximize", app: "Terminal" })

// Move window
await window({ action: "move", app: "TextEdit", x: 100, y: 100 })

// Resize window
await window({ action: "resize", app: "Notes", width: 800, height: 600 })

// Set exact bounds (move + resize)
await window({ action: "set-bounds", app: "Safari", x: 50, y: 50, width: 1200, height: 800 })

// Focus window
await window({ action: "focus", app: "Visual Studio Code" })
await window({ action: "focus", app: "Safari", index: 0 })  // Focus first window

// List all windows (Note: window tool doesn't have a list action)
// Use the list tool instead: await list({ item_type: "application_windows", app: "Finder" })
```

#### Window Actions
- **close** - Close the window (animated if has close button)
- **minimize** - Minimize to dock
- **maximize** - Maximize/zoom window
- **move** - Move to specific coordinates
- **resize** - Change window dimensions
- **set-bounds** - Set position and size in one operation
- **focus** - Bring window to front and focus

#### Targeting Options
- **app** - Target by application name (fuzzy matching supported)
- **title** - Target by window title (substring matching)
- **index** - Target by index (0-based, front to back order)

### 🖥️ Multi-Screen Support

Peekaboo v3 includes comprehensive multi-screen support for window management across multiple displays. When listing windows, Peekaboo shows which screen each window is on, and provides powerful options for moving windows between screens.

#### Screen Identification
When listing windows, each window shows its screen location:
```bash
# Windows now show their screen in the output
peekaboo list windows --app Safari
# Output includes: "Screen: Built-in Display" or "Screen: External Display"
```

#### Moving Windows Between Screens

**Using Screen Index (0-based):**
```bash
# Move window to specific screen by index
peekaboo window resize --app Safari --target-screen 0    # Primary screen
peekaboo window resize --app Terminal --target-screen 1  # Second screen
peekaboo window resize --app Notes --target-screen 2     # Third screen
```

**Using Screen Presets:**
```bash
# Move to next/previous screen
peekaboo window resize --app Safari --screen-preset next
peekaboo window resize --app Terminal --screen-preset previous

# Move to primary screen (with menu bar)
peekaboo window resize --app Notes --screen-preset primary

# Keep on same screen (useful with other resize options)
peekaboo window resize --app TextEdit --screen-preset same --preset left_half
```

#### Combined Screen and Window Operations

You can combine screen movement with window positioning:
```bash
# Move to screen 1 and maximize
peekaboo window resize --app Safari --target-screen 1 --preset maximize

# Move to next screen and position on left half
peekaboo window resize --app Terminal --screen-preset next --preset left_half

# Move to screen 0 at specific coordinates
peekaboo window resize --app Notes --target-screen 0 --x 100 --y 100

# Move to primary screen with custom size
peekaboo window resize --app TextEdit --screen-preset primary --width 1200 --height 800
```

#### How It Works

- **Unified Coordinate System**: macOS uses a single coordinate space across all screens
- **Smart Positioning**: When moving windows between screens without explicit coordinates, windows maintain their relative position (e.g., a window at 25% from the left edge stays at 25% on the new screen)
- **Screen Detection**: Windows are assigned to screens based on their center point
- **0-Based Indexing**: Screens are indexed starting from 0, matching macOS's internal ordering

#### Multi-Screen with AI Agent

The AI agent understands multi-screen commands:
```bash
peekaboo agent "Move all Safari windows to the external display"
peekaboo agent "Put Terminal on my second screen"
peekaboo agent "Arrange windows with Safari on the left screen and Notes on the right"
```

### 📋 The `menu` Tool

Interact with application menu bars and system menu extras:

```typescript
// List all menus and items for an app
await menu({ action: "list", app: "Calculator" })

// Click a simple menu item
await menu({ action: "click", app: "Safari", item: "New Window" })

// Navigate nested menus with path
await menu({ action: "click", app: "TextEdit", path: "Format > Font > Bold" })

// Click system menu extras (WiFi, Bluetooth, etc.)
await menu({ action: "click-extra", title: "WiFi" })
```

#### Menu Subcommands
- **list** - List all menus and their items (including keyboard shortcuts)
- **list-all** - List menus for the frontmost application
- **click** - Click a menu item (default if not specified)
- **click-extra** - Click system menu extras in the status bar

#### Key Features
- **Pure Accessibility** - Extracts menu structure without clicking or opening menus
- **Full Hierarchy** - Discovers all submenus and nested items
- **Keyboard Shortcuts** - Shows all available keyboard shortcuts
- **Smart Discovery** - AI agents can use list to discover available options

### 🚀 The `app` Tool

Control applications - launch, quit, focus, hide, and switch between apps:

```typescript
// Launch an application
await app({ action: "launch", name: "Safari" })

// Quit an application
await app({ action: "quit", name: "TextEdit" })

// Force quit
await app({ action: "quit", name: "Notes", force: true })

// Focus/switch to app
await app({ action: "focus", name: "Google Chrome" })

// Hide/unhide apps
await app({ action: "hide", name: "Finder" })
await app({ action: "unhide", name: "Finder" })
```

### 🎯 The `dock` Tool

Interact with the macOS Dock:

```typescript
// List all dock items
await dock({ action: "list" })

// Launch app from dock
await dock({ action: "launch", app: "Safari" })

// Right-click on dock item
await dock({ action: "right-click", app: "Finder" })

// Show/hide dock
await dock({ action: "hide" })
await dock({ action: "show" })
```

### 💬 The `dialog` Tool

Handle system dialogs and alerts:

```typescript
// List open dialogs
await dialog({ action: "list" })

// Click dialog button
await dialog({ action: "click", button: "OK" })

// Input text in dialog field
await dialog({ action: "input", text: "filename.txt" })

// Select file in open/save dialog
await dialog({ action: "file", path: "/Users/me/Documents/file.pdf" })

// Dismiss dialog
await dialog({ action: "dismiss" })
```

### 🧹 The `clean` Tool

Clean up session cache and temporary files:

```typescript
// Clean all sessions
await clean({})

// Clean sessions older than 7 hours
await clean({ older_than: 7 })

// Clean specific session
await clean({ session: "session_123" })

// Dry run to see what would be cleaned
await clean({ dry_run: true })
```

### Session Management

Peekaboo v3 uses sessions to maintain UI state across commands:

- Sessions are created automatically by the `see` tool
- Each session stores screenshot data and element mappings
- Sessions persist in `~/.peekaboo/session/<PID>/`
- Element IDs remain consistent within a session
- Sessions are automatically cleaned up on process exit

### Best Practices

1. **Always start with `see`** - Capture the current UI state before interacting
2. **Use element IDs when possible** - More reliable than coordinate clicking
3. **Add delays for animations** - Use `sleep` after actions that trigger animations
4. **Verify actions** - Call `see` again to confirm actions succeeded
5. **Handle errors gracefully** - Check if elements exist before interacting
6. **Clean up sessions** - Use the `clean` tool periodically

### Example Workflows

#### Login Automation
```typescript
// 1. See the login form
const { elements } = await see({ app_target: "MyApp" })

// 2. Fill in credentials
await click({ on: "T1" })  // Click email field
await type({ text: "user@example.com" })

await click({ on: "T2" })  // Click password field  
await type({ text: "password123" })

// 3. Submit
await click({ query: "Sign In" })

// 4. Wait and verify
await sleep({ duration: 2000 })
await see({ app_target: "MyApp" })  // Verify logged in
```

#### Web Search
```typescript
// 1. Focus browser
await see({ app_target: "Safari" })

// 2. Open new tab
await hotkey({ keys: "cmd,t" })

// 3. Type search
await type({ text: "Peekaboo MCP automation" })
await type({ text: "{return}" })

// 4. Wait for results
await sleep({ duration: 3000 })

// 5. Click first result
await see({ app_target: "Safari" })
await click({ on: "L1" })
```

#### Form Filling
```typescript
// 1. Capture form
const { elements } = await see({ app_target: "Forms" })

// 2. Fill each field
for (const field of elements.text_fields) {
  await click({ on: field.id })
  await type({ text: "Test data", clear: true })
}

// 3. Check all checkboxes
for (const checkbox of elements.checkboxes) {
  if (!checkbox.checked) {
    await click({ on: checkbox.id })
  }
}

// 4. Submit
await click({ query: "Submit" })
```

### Troubleshooting

1. **Elements not found** - Ensure the UI is visible and not obscured
2. **Clicks not working** - Try increasing `wait_for` timeout
3. **Wrong element clicked** - Use specific element IDs instead of queries
4. **Session errors** - Run `clean` tool to clear corrupted sessions
5. **Permissions denied** - Grant Accessibility permission in System Settings

### Debugging with Logs

Peekaboo uses macOS's unified logging system. Use `pblog` to monitor logs:

```bash
# View recent logs
./scripts/pblog.sh

# Stream logs continuously
./scripts/pblog.sh -f

# Debug specific issues
./scripts/pblog.sh -c ClickService -d
```

**Note**: macOS redacts log values by default, showing `<private>`. 
See [docs/pblog-guide.md](docs/pblog-guide.md) and [docs/logging-profiles/README.md](docs/logging-profiles/README.md) for solutions.

## 🔧 Configuration

For full configuration + environment variable tables, see [docs/configuration.md](docs/configuration.md).

## 🎨 Setting Up Local AI with Ollama

Need fully local models or Ultrathink experimentation? Follow the dedicated playbook in [docs/ollama.md](docs/ollama.md) for installation, recommended models, environment variables, and troubleshooting tips. At runtime you can point Peekaboo at your Ollama server with `PEEKABOO_AI_PROVIDERS="ollama/llama3.3" peekaboo agent "…"`.

## 📋 Requirements

Peekaboo needs macOS 14.0+, Screen Recording permission, and (ideally) Accessibility access. Follow [docs/permissions.md](docs/permissions.md) for step-by-step instructions plus performance tips.

## 🏗️ Building from Source

See [docs/building.md](docs/building.md) for prerequisites, pnpm build commands, and release script pointers.

## 👻 Poltergeist

Use the watcher by following [docs/poltergeist.md](docs/poltergeist.md); it covers start/stop commands, tuning, and queue behavior.

## 🧪 Testing

### Running Tests

Peekaboo uses Swift Testing framework (Swift 6.0+) for all test suites:

```bash
# Run all tests
swift test

# Run specific test target
swift test --filter PeekabooTests

# Run tests with verbose output
swift test --verbose
```

### Testing the CLI

```bash
# Test CLI directly
peekaboo list server_status
peekaboo image --mode screen --path test.png
peekaboo image --analyze "What is shown?" --path test.png

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

For step-by-step debugging, use the verbose flag:
```bash
peekaboo image --app Safari --verbose 2>&1 | less
```

## 🛠️ Development

### Poltergeist - Automatic CLI Builder

Peekaboo includes **Poltergeist**, an automatic build system that watches Swift source files and rebuilds the CLI in the background. This ensures your CLI binary is always up-to-date during development.

```bash
# Start Poltergeist (runs in background)
npm run poltergeist:haunt

# Check status
npm run poltergeist:status

# Stop Poltergeist
npm run poltergeist:rest
```

**Key features:**
- Watches all Swift source files automatically
- Smart wrapper script (`./scripts/peekaboo-wait.sh`) handles build coordination
- Exit code 42 indicates build failure - fix immediately
- See [Poltergeist repository](https://github.com/steipete/poltergeist) for full documentation

### Building from Source

```bash
# Build everything
npm run build:all

# Build CLI only
npm run build:swift

# Build TypeScript server
npm run build
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

## 📊 Coverage

| Date       | Command                                                            | Scope                                  | Line Coverage |
| ---------- | ------------------------------------------------------------------ | -------------------------------------- | ------------- |
| 2025-11-13 | ``cd Apps/CLI && swift test -Xswiftc -DPEEKABOO_SKIP_AUTOMATION --enable-code-coverage && xcrun llvm-profdata merge -sparse .build/arm64-apple-macosx/debug/codecov/*.profraw -o .build/arm64-apple-macosx/debug/codecov/default.profdata && xcrun llvm-cov report .build/arm64-apple-macosx/debug/peekabooPackageTests.xctest/Contents/MacOS/peekabooPackageTests -instr-profile .build/arm64-apple-macosx/debug/codecov/default.profdata`` | CLI + Core services under `PEEKABOO_SKIP_AUTOMATION` (non-interactive subset) | 9.82 %        |
| 2025-11-12 | `./runner swift test --package-path Apps/CLI --enable-code-coverage` | Entire workspace (Peekaboo + subrepos) | 8.38 %        |

> Coverage generated via `xcrun llvm-cov report Apps/CLI/.build/arm64-apple-macosx/debug/peekabooPackageTests.xctest/Contents/MacOS/peekabooPackageTests -instr-profile Apps/CLI/.build/arm64-apple-macosx/debug/codecov/default.profdata`. Because the CLI target depends on AXorcist, Commander, Tachikoma, and TauTUI, the figure reflects the aggregate workspace, even though automation-heavy suites remain disabled during headless runs.
