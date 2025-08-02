# Installing Peekaboo MCP in Claude Desktop

This guide explains how to install the Peekaboo MCP server in Claude Desktop application.

## Prerequisites

1. **macOS 14.0 (Sonoma) or later**
2. **Claude Desktop** installed from [claude.ai/download](https://claude.ai/download)
3. **Peekaboo CLI** built and working

## Quick Installation

### Method 1: Direct Binary Installation (Recommended)

1. **Build Peekaboo** (if not already built):
   ```bash
   cd /Users/steipete/Projects/Peekaboo
   npm run build:swift
   ```

2. **Edit Claude Desktop configuration**:
   ```bash
   # Open Claude Desktop config
   code ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. **Add Peekaboo MCP server** to the configuration:
   ```json
   {
     "mcpServers": {
       "peekaboo": {
         "command": "/Users/steipete/Projects/Peekaboo/peekaboo",
         "args": ["mcp", "serve"],
         "env": {
           "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4-20250514,ollama/llava:latest"
         }
       }
     }
   }
   ```

4. **Restart Claude Desktop** to apply changes.

### Method 2: Using NPM Package (When Published)

Once the npm package is published:

```bash
# Install globally
npm install -g @steipete/peekaboo-mcp

# Configure Claude Desktop
```

Then add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "peekaboo-mcp"
    }
  }
}
```

## Configuration Options

### Environment Variables

You can add environment variables to configure Peekaboo:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "/Users/steipete/Projects/Peekaboo/peekaboo",
      "args": ["mcp", "serve"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4-20250514",
        "PEEKABOO_LOG_LEVEL": "info",
        "OPENAI_API_KEY": "sk-...",
        "ANTHROPIC_API_KEY": "sk-ant-...",
        "PEEKABOO_USE_MODERN_CAPTURE": "true"
      }
    }
  }
}
```

### Available Environment Variables

- `PEEKABOO_AI_PROVIDERS`: Comma-separated list of AI providers (e.g., `anthropic/claude-opus-4,openai/gpt-4.1`)
- `PEEKABOO_LOG_LEVEL`: Logging verbosity (debug, info, warn, error)
- `OPENAI_API_KEY`: OpenAI API key for GPT models
- `ANTHROPIC_API_KEY`: Anthropic API key for Claude models
- `X_AI_API_KEY` or `XAI_API_KEY`: xAI API key for Grok models
- `PEEKABOO_OLLAMA_BASE_URL`: Ollama server URL (default: http://localhost:11434)
- `PEEKABOO_USE_MODERN_CAPTURE`: Use modern capture API (true/false)

## Verifying Installation

1. **Check Claude Desktop logs**:
   ```bash
   # Monitor Claude Desktop logs
   tail -f ~/Library/Logs/Claude/mcp*.log
   ```

2. **Check Peekaboo MCP logs**:
   ```bash
   # Monitor Peekaboo logs
   ./scripts/pblog.sh -f
   ```

3. **Test in Claude Desktop**:
   - Open Claude Desktop
   - Start a new conversation
   - Type: "Can you take a screenshot of my desktop?"
   - Claude should use the Peekaboo MCP tools

## Troubleshooting

### Common Issues

1. **"Tool not found" errors**
   - Ensure the binary path is absolute, not relative
   - Check that the binary is executable: `chmod +x /path/to/peekaboo`

2. **Permission errors**
   - Grant Screen Recording permission: System Settings → Privacy & Security → Screen Recording
   - Grant Accessibility permission: System Settings → Privacy & Security → Accessibility

3. **MCP server not starting**
   - Check Claude Desktop logs for errors
   - Try running the command manually: `/path/to/peekaboo mcp serve`
   - Verify the binary exists and is the correct architecture

4. **API key issues**
   - Ensure API keys are properly set in the env section
   - Or configure them globally in `~/.peekaboo/credentials`

### Debug Mode

Enable debug logging to troubleshoot issues:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "/Users/steipete/Projects/Peekaboo/peekaboo",
      "args": ["mcp", "serve", "--log-level", "debug"],
      "env": {
        "PEEKABOO_LOG_LEVEL": "debug"
      }
    }
  }
}
```

## Advanced Configuration

### Multiple Instances

You can run multiple Peekaboo instances with different configurations:

```json
{
  "mcpServers": {
    "peekaboo-local": {
      "command": "/Users/steipete/Projects/Peekaboo/peekaboo",
      "args": ["mcp", "serve"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "ollama/llama3.3"
      }
    },
    "peekaboo-cloud": {
      "command": "/Users/steipete/Projects/Peekaboo/peekaboo",
      "args": ["mcp", "serve"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4,openai/gpt-4.1"
      }
    }
  }
}
```

### Custom Working Directory

Set a custom working directory for file operations:

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "/Users/steipete/Projects/Peekaboo/peekaboo",
      "args": ["mcp", "serve"],
      "cwd": "/Users/steipete/Desktop"
    }
  }
}
```

## Available Tools

Once installed, Claude will have access to all Peekaboo tools:

- **Screen Capture**: `image`, `see`
- **UI Automation**: `click`, `type`, `scroll`, `hotkey`, `swipe`, `drag`
- **Window Management**: `window`, `list`, `space`
- **App Control**: `app`, `menu`, `dock`
- **System**: `permissions`, `sleep`, `dialog`
- **AI Analysis**: `analyze`, `agent`
- **Utilities**: `move`, `clean`

## Security Considerations

1. **API Keys**: Store sensitive API keys in `~/.peekaboo/credentials` (chmod 600)
2. **Permissions**: Only grant necessary system permissions
3. **File Access**: Be aware that MCP tools can read/write files
4. **Screen Content**: Screenshots may contain sensitive information

## Support

- **Issues**: [GitHub Issues](https://github.com/steipete/peekaboo/issues)
- **Documentation**: [Peekaboo Docs](https://github.com/steipete/peekaboo/tree/main/docs)
- **MCP Spec**: [Model Context Protocol](https://modelcontextprotocol.io)