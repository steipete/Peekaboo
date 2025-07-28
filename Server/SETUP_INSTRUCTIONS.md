# Peekaboo MCP Server Setup Instructions

The Peekaboo MCP server has been built and is ready to use with Claude Desktop and Claude Code.

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Node.js 18 or later
- Screen Recording and Accessibility permissions granted to Terminal/Claude apps

## Installation Steps

### For Claude Desktop

1. **Open Claude Desktop Settings**
   - Click on Settings from the **menubar** (not the settings button within the app)
   
2. **Navigate to Developer Settings**
   - Click on "Developer" in the left sidebar
   - Click "Edit Config" button

3. **Edit the Configuration File**
   - This opens `claude_desktop_config.json` located at:
     - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
     - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

4. **Add the Peekaboo MCP Server Configuration**:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "node",
      "args": ["/Users/steipete/Projects/Peekaboo/Server/dist/index.js"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4",
        "PEEKABOO_LOG_LEVEL": "info"
      }
    }
  }
}
```

5. **Save and Restart**
   - Save the configuration file
   - Completely quit Claude Desktop (Cmd+Q)
   - Restart Claude Desktop
   - Look for the MCP server indicator in the bottom-right corner of the conversation input box

### For Claude Code

Claude Code uses a CLI-based configuration system. You have two options:

#### Option 1: Using CLI Commands (Recommended for Simple Setup)

```bash
# Add the Peekaboo MCP server
claude mcp add peekaboo node /Users/steipete/Projects/Peekaboo/Server/dist/index.js

# Or with environment variables using JSON configuration
claude mcp add-json peekaboo '{
  "type": "stdio",
  "command": "node",
  "args": ["/Users/steipete/Projects/Peekaboo/Server/dist/index.js"],
  "env": {
    "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4",
    "PEEKABOO_LOG_LEVEL": "info",
    "PEEKABOO_LOG_FILE": "/Users/steipete/Library/Logs/peekaboo-mcp.log"
  }
}'
```

#### Option 2: Direct Configuration File Editing (More Control)

1. **Locate the Configuration File**
   - The configuration is stored in `.claude.json` in your home directory or project directory

2. **Edit the Configuration**:

```json
{
  "mcpServers": {
    "peekaboo": {
      "type": "stdio",
      "command": "node",
      "args": ["/Users/steipete/Projects/Peekaboo/Server/dist/index.js"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4",
        "PEEKABOO_LOG_LEVEL": "info",
        "PEEKABOO_LOG_FILE": "/Users/steipete/Library/Logs/peekaboo-mcp.log"
      }
    }
  }
}
```

3. **Restart Claude Code**
   - Restart Claude Code for changes to take effect

#### Verify Connection

In Claude Code, use the `/mcp` command to check server status:
```
> /mcp
⎿ MCP Server Status ⎿
⎿ • peekaboo: connected ⎿
```

## Configuration Options

### Environment Variables

- `PEEKABOO_AI_PROVIDERS`: AI provider configuration (e.g., `anthropic/claude-opus-4`, `openai/gpt-4.1`)
- `PEEKABOO_LOG_LEVEL`: Logging level (`debug`, `info`, `warn`, `error`)
- `PEEKABOO_LOG_FILE`: Log file location (defaults to `~/Library/Logs/peekaboo-mcp.log`)
- `PEEKABOO_USE_MODERN_CAPTURE`: Set to `false` if screen capture hangs

### API Keys

Set your API keys as environment variables or in `~/.peekaboo/credentials`:

```bash
# For Anthropic
export ANTHROPIC_API_KEY=sk-ant-...

# For OpenAI
export OPENAI_API_KEY=sk-...

# For Grok/xAI
export X_AI_API_KEY=xai-...
```

Or use the Peekaboo CLI to set credentials:

```bash
./peekaboo config set-credential ANTHROPIC_API_KEY sk-ant-...
./peekaboo config set-credential OPENAI_API_KEY sk-...
```

## Available Tools

Once configured, you'll have access to these Peekaboo tools in Claude:

- **image**: Capture screenshots of screen, windows, or apps
- **analyze**: Analyze images with AI vision models
- **list**: List running applications and windows
- **see**: Capture and analyze UI elements for automation
- **click**: Click on UI elements or coordinates
- **type**: Type text into UI elements
- **scroll**: Scroll content in any direction
- **hotkey**: Press keyboard shortcuts
- **app**: Control applications (launch, quit, focus)
- **window**: Manage windows (move, resize, close)
- **menu**: Interact with application menus
- **agent**: Execute complex automation tasks with AI
- And many more...

## Troubleshooting

### Logs

Check the MCP server logs at:
- `~/Library/Logs/peekaboo-mcp.log`

### Permissions

If tools fail with permission errors:
1. Open System Settings → Privacy & Security
2. Grant Screen Recording permission to Terminal/Claude apps
3. Grant Accessibility permission to Terminal/Claude apps

### Testing

Test the MCP server directly:
```bash
cd /Users/steipete/Projects/Peekaboo/Server
npm run inspector
```

## Development

To make changes to the MCP server:

1. Edit TypeScript files in `Server/src/`
2. Rebuild: `npm run build`
3. Test: `npm run inspector`
4. Restart Claude Desktop/Code to load changes

The Peekaboo CLI binary must be present at `Server/peekaboo` for the MCP server to work.