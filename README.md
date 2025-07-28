# Peekaboo MCP: Lightning-fast macOS Screenshots & GUI Automation 🚀

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
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

### 🤖 **MCP Server** (For AI Assistants)
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
- **Privacy-first operation** with local AI options via Ollama
- **Non-intrusive capture** without changing window focus
- **Automation scripting** - Chain commands together for complex workflows

### 🏗️ Architecture

Peekaboo uses a modern service-based architecture:

- **PeekabooCore** - Shared services for screen capture, UI automation, window management, and more
- **CLI** - Command-line interface that uses PeekabooCore services directly
- **Mac App** - Native macOS app with 100x+ performance improvement over CLI spawning
- **MCP Server** - Model Context Protocol server for AI assistants

All components share the same core services, ensuring consistent behavior and optimal performance. See [Service API Reference](docs/service-api-reference.md) for detailed documentation.

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

# Analyze images with AI (use image command with --analyze)
peekaboo image --analyze "What error is shown?" --path screenshot.png
peekaboo image --analyze "Find all buttons" --app Safari
peekaboo see --analyze "Describe this UI" --app Chrome

# GUI Automation (v3)
peekaboo see --app Safari               # Identify UI elements
peekaboo click "Submit"                 # Click button by text
peekaboo type "Hello world"             # Type at current focus
peekaboo scroll --direction down --amount 5  # Scroll down 5 ticks

# AI Agent - Natural language automation
peekaboo "Open Safari and search for weather"
peekaboo agent "Fill out the contact form" --verbose
peekaboo hotkey cmd,c                   # Press Cmd+C

# AI Agent Automation (v3) 🤖
peekaboo "Open TextEdit and write Hello World"
peekaboo agent "Take a screenshot of Safari and email it"
peekaboo agent --verbose "Find all Finder windows and close them"

# Window Management (v3)
peekaboo window close --app Safari      # Close Safari window
peekaboo window minimize --app Finder   # Minimize Finder window
peekaboo window move --app TextEdit --x 100 --y 100
peekaboo window resize --app Terminal --width 800 --height 600
peekaboo window focus --app "Visual Studio Code"

# Space (Virtual Desktop) Management
peekaboo space list                      # List all Spaces
peekaboo space switch --to 2             # Switch to Space 2
peekaboo space move-window --app Safari --to 3  # Move Safari to Space 3

# Menu Bar Interaction (v3)
peekaboo menu list --app Calculator     # List all menus and items
peekaboo menu list-all                  # List menus for frontmost app
peekaboo menu click --app Safari --item "New Window"
peekaboo menu click --app TextEdit --path "Format > Font > Bold"
peekaboo menu click-extra --title "WiFi" # Click system menu extras

# Configure settings
peekaboo config init                    # Create config file
peekaboo config edit                    # Edit in your editor
peekaboo config show --effective        # Show current settings
```

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
peekaboo click --on T2                  # No need to specify --session
peekaboo type "password123"
peekaboo click "Sign In"
peekaboo sleep 2000                     # Wait 2 seconds

# Multiple app automation with explicit sessions
SESSION_A=$(peekaboo see --app Safari --json-output | jq -r '.data.session_id')
SESSION_B=$(peekaboo see --app Notes --json-output | jq -r '.data.session_id')
peekaboo click --on B1 --session $SESSION_A  # Click in Safari
peekaboo type "Hello" --session $SESSION_B   # Type in Notes

# Run automation script
peekaboo run login.peekaboo.json
```

## 🤖 MCP Server Setup

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
  "args": ["-y", "@steipete/peekaboo-mcp@beta"],
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
      "args": ["-y", "@steipete/peekaboo-mcp"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "openai/gpt-4.1,ollama/llava:latest",
        "OPENAI_API_KEY": "your-openai-api-key-here"
      }
    }
  }
}
```

### MCP Tools Available

#### Core Tools
1. **`image`** - Capture screenshots (with optional AI analysis via question parameter)
2. **`list`** - List applications, windows, or check server status
3. **`analyze`** - Analyze existing images with AI vision models (MCP-only tool, use `peekaboo image --analyze` in CLI)

#### UI Automation Tools
4. **`see`** - Capture screen and identify UI elements
5. **`click`** - Click on UI elements or coordinates
6. **`type`** - Type text into UI elements
7. **`scroll`** - Scroll content in any direction
8. **`hotkey`** - Press keyboard shortcuts
9. **`swipe`** - Perform swipe/drag gestures
10. **`move`** - Move mouse cursor to specific position or element
11. **`drag`** - Perform drag and drop operations

#### Application & Window Management
12. **`app`** - Launch, quit, focus, hide, and manage applications
13. **`window`** - Manipulate windows (close, minimize, maximize, move, resize, focus)
14. **`menu`** - Interact with application menus and system menu extras
15. **`dock`** - Launch apps from dock and manage dock items
16. **`dialog`** - Handle dialog windows (click buttons, input text)
17. **`space`** - Manage macOS Spaces (virtual desktops)

#### Utility Tools
18. **`run`** - Execute automation scripts from .peekaboo.json files
19. **`sleep`** - Pause execution for specified duration
20. **`clean`** - Clean up session cache and temporary files
21. **`permissions`** - Check system permissions (screen recording, accessibility)
22. **`agent`** - Execute complex automation tasks using AI

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

Type text with support for special keys:

```typescript
// Type into a specific field
await type({ text: "user@example.com", on: "T1" })

// Type at current focus
await type({ text: "Hello world" })

// Clear existing text first
await type({ text: "New text", on: "T2", clear: true })

// Use special keys
await type({ text: "Select all{cmd+a}Copy{cmd+c}" })
await type({ text: "Line 1{return}Line 2{tab}Indented" })

// Adjust typing speed
await type({ text: "Slow typing", delay: 100 })
```

#### Supported Special Keys
- `{return}` or `{enter}` - Return/Enter key
- `{tab}` - Tab key
- `{escape}` or `{esc}` - Escape key
- `{delete}` or `{backspace}` - Delete key
- `{space}` - Space key
- `{cmd+a}`, `{cmd+c}`, etc. - Command combinations
- `{arrow_up}`, `{arrow_down}`, `{arrow_left}`, `{arrow_right}` - Arrow keys
- `{f1}` through `{f12}` - Function keys

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

## 🤖 AI Agent Automation

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
peekaboo agent "Fill out the form" --model grok-4-0709
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

## 🔧 Configuration

### Configuration Precedence

Settings follow this precedence (highest to lowest):
1. Command-line arguments
2. Environment variables
3. Credentials file (`~/.peekaboo/credentials`)
4. Configuration file (`~/.peekaboo/config.json`)
5. Built-in defaults

### Available Options

| Setting | Config File | Environment Variable | Description |
|---------|-------------|---------------------|-------------|
| AI Providers | `aiProviders.providers` | `PEEKABOO_AI_PROVIDERS` | Comma-separated list (e.g., "openai/gpt-4.1,anthropic/claude,grok/grok-4,ollama/llava:latest") |
| OpenAI API Key | Use `credentials` file | `OPENAI_API_KEY` | Required for OpenAI provider |
| Anthropic API Key | Use `credentials` file | `ANTHROPIC_API_KEY` | Required for Claude models |
| Grok API Key | Use `credentials` file | `X_AI_API_KEY` or `XAI_API_KEY` | Required for Grok (xAI) models |
| Ollama URL | `aiProviders.ollamaBaseUrl` | `PEEKABOO_OLLAMA_BASE_URL` | Default: http://localhost:11434 |
| Default Save Path | `defaults.savePath` | `PEEKABOO_DEFAULT_SAVE_PATH` | Where screenshots are saved (default: current directory) |
| Log Level | `logging.level` | `PEEKABOO_LOG_LEVEL` | trace, debug, info, warn, error, fatal |
| Log Path | `logging.path` | `PEEKABOO_LOG_FILE` | Log file location |
| CLI Binary Path | - | `PEEKABOO_CLI_PATH` | Override bundled Swift CLI path (advanced usage) |

### Environment Variable Details

#### API Key Storage Best Practices

For security, Peekaboo supports three methods for API key storage (in order of recommendation):

1. **Environment Variables** (Most secure for automation)
   ```bash
   export OPENAI_API_KEY="sk-..."
   ```

2. **Credentials File** (Best for interactive use)
   ```bash
   peekaboo config set-credential OPENAI_API_KEY sk-...
   # Stored in ~/.peekaboo/credentials with chmod 600
   ```

3. **Config File** (Not recommended - use credentials file instead)

#### AI Provider Configuration

- **`PEEKABOO_AI_PROVIDERS`**: Comma-separated list of AI providers to use for image analysis
  - Format: `provider/model,provider/model`
  - Example: `"openai/gpt-4.1,anthropic/claude-opus-4,grok/grok-4,ollama/llava:latest"`
  - The first available provider will be used
  - Default: `"openai/gpt-4.1,ollama/llava:latest"`
  - Supported providers: `openai`, `anthropic`, `grok`, `ollama`

- **`OPENAI_API_KEY`**: Your OpenAI API key for GPT-4.1 Vision
  - Required when using the `openai` provider
  - Get your key at: https://platform.openai.com/api-keys

- **`ANTHROPIC_API_KEY`**: Your Anthropic API key for Claude models
  - Required when using the `anthropic` provider
  - Get your key at: https://console.anthropic.com/

- **`X_AI_API_KEY`** or **`XAI_API_KEY`**: Your xAI API key for Grok models
  - Required when using the `grok` provider
  - Get your key at: https://console.x.ai/
  - Both environment variable names are supported

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
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" peekaboo image --analyze "What is this?" --path image.png

# Export for the current session
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export X_AI_API_KEY="xai-..."
export PEEKABOO_DEFAULT_SAVE_PATH="~/Desktop/Screenshots"

# Add to your shell profile (~/.zshrc or ~/.bash_profile)
echo 'export OPENAI_API_KEY="sk-..."' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc
echo 'export X_AI_API_KEY="xai-..."' >> ~/.zshrc
```

## 🎨 Setting Up Local AI with Ollama

For privacy-focused local AI analysis:

```bash
# Install Ollama
brew install ollama
ollama serve

# Download recommended models
ollama pull llama3.3           # RECOMMENDED for agent tasks (supports tool calling)
ollama pull llava:latest       # Vision model (no tool support)
ollama pull qwen2-vl:7b        # Lighter vision alternative

# Use with Peekaboo
PEEKABOO_AI_PROVIDERS="ollama/llama3.3" peekaboo agent "Click the Submit button"
PEEKABOO_AI_PROVIDERS="ollama/llama" peekaboo agent "Take a screenshot"  # Defaults to llama3.3

# Configure Peekaboo (optional)
peekaboo config edit
# Set providers to: "ollama/llama3.3" for agent tasks
# Or: "ollama/llava:latest" for image analysis only
```

### Ollama Model Support

**Models with Tool Calling** (✅ Recommended for automation):
- `llama3.3` - Best overall for agent tasks
- `llama3.2` - Good alternative

**Vision Models** (❌ No tool calling):
- `llava` - Image analysis only
- `bakllava` - Alternative vision model

**Note**: For agent automation tasks, use `llama3.3`. Vision models like `llava` can analyze images but cannot perform GUI automation.

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
- Xcode 16.4+ with Command Line Tools (`xcode-select --install`)
- Swift 6.0+ (included with Xcode 16.4+)

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

### Debug Build Staleness Detection

For development, enable automatic staleness detection to ensure you're always using the latest built CLI version: `git config peekaboo.check-build-staleness true`. This is recommended when working with AI assistants that frequently modify source code, as it prevents using outdated binaries.

## 👻 Poltergeist - Swift CLI Auto-rebuild Watcher

Poltergeist is a helpful ghost that watches your Swift files and automatically rebuilds the CLI when they change. Perfect for development workflows!

### Installation

First, install Watchman (required):
```bash
brew install watchman
```

### Usage

Run these commands from the project root:

```bash
# Start the watcher
npm run poltergeist:start
# or the more thematic:
npm run poltergeist:haunt

# Check status
npm run poltergeist:status

# View activity logs
npm run poltergeist:logs

# Stop watching
npm run poltergeist:stop
# or the more thematic:
npm run poltergeist:rest
```

### What It Does

Poltergeist monitors:
- `Core/PeekabooCore/**/*.swift`
- `Core/AXorcist/**/*.swift`
- `Apps/CLI/**/*.swift`
- All `Package.swift` and `Package.resolved` files

When changes are detected, it automatically:
1. Rebuilds the Swift CLI using `npm run build:swift`
2. Copies the binary to the project root for easy access
3. Logs all activity to `.poltergeist.log`

### Features

- 👻 **Smart Rebuilding** - Only rebuilds when Swift files actually change
- 🔒 **Single Instance** - Prevents multiple concurrent builds
- 📝 **Activity Logging** - Track all rebuild activity with timestamps
- ⚡ **Native Performance** - Uses macOS FSEvents for minimal overhead
- 🎯 **Persistent Watches** - Survives terminal sessions

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