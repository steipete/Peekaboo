---
summary: 'Review Peekaboo MCP Client Implementation guidance'
read_when:
  - 'planning work related to peekaboo mcp client implementation'
  - 'debugging or extending features described here'
---

# Peekaboo MCP Client Implementation

<!-- Generated: 2025-08-05 00:15:30 UTC -->

> **✅ IMPLEMENTED**: Peekaboo now functions as both an MCP server and client, enabling consumption of external MCP servers while providing its native automation tools.

This document describes the completed MCP client implementation in Peekaboo, which transforms it from a standalone MCP server into a powerful MCP orchestrator that can consume tools from the entire MCP ecosystem.

## Overview

Peekaboo now operates as both:
- **MCP Server**: Exposing 22+ native Swift automation tools
- **MCP Client**: Consuming tools from external MCP servers with server prefixes

**Default Integration**: Peekaboo ships with [BrowserMCP](https://browsermcp.io) enabled by default, providing lightweight browser automation capabilities. This can be disabled via configuration if not needed.

### Key Features

- **Unified Tool Interface**: All tools accessible through single endpoint
- **Server Prefixes**: External tools prefixed as `github:create_issue`
- **Real-time Health Monitoring**: Live connectivity and tool count checking
- **Comprehensive CLI**: Full lifecycle management for external servers
- **Agent Integration**: External tools work seamlessly with Peekaboo agent

## Architecture

```
┌─────────────────┐     ┌──────────────────────────┐     ┌─────────────────┐
│   MCP Client    │────▶│   Peekaboo MCP Server    │────▶│  External MCP   │
│   (Claude)      │stdio│   + Client Manager       │stdio│    Servers      │
└─────────────────┘     └──────────────────────────┘     └─────────────────┘
                                   │                             │
                                   ▼                             │
                    ┌─────────────────────────────┐              │
                    │     Tool Registry           │              │
                    │ ┌─────────────────────────┐ │              │
                    │ │ Native Tools (22):      │ │              │
                    │ │ • image, click, type    │ │              │
                    │ │ • see, scroll, app      │ │              │
                    │ │ • window, menu, hotkey  │ │              │
                    │ └─────────────────────────┘ │              │
                    │ ┌─────────────────────────┐ │              │
                    │ │ External Tools:         │ │◄─────────────┘
                    │ │ • github:create_issue   │ │
                    │ │ • github:list_repos     │ │
                    │ │ • files:read_file       │ │
                    │ │ • chrome-devtools:click │ │
                    │ └─────────────────────────┘ │
                    └─────────────────────────────┘
```

## Command Reference

### Tools Command

List and filter available tools with comprehensive options:

```bash
# Show all tools (native + external)
peekaboo tools

# Show only native Peekaboo tools
peekaboo tools --native-only

# Show only external MCP tools
peekaboo tools --mcp-only

# Show tools from specific server
peekaboo tools --mcp github

# Detailed information with descriptions
peekaboo tools --verbose

# JSON output for programmatic use
peekaboo tools --json-output

# Group external tools by server
peekaboo tools --group-by-server
```

**Example Output**:
```
Available Tools
===============

Native Tools (22):
  image                     Capture screenshots and images
  click                     Click on UI elements
  type                      Type text into fields
  see                       Analyze screen content with AI
  scroll                    Scroll in windows or elements
  app                       Control applications (launch, quit, focus)
  window                    Manage application windows
  menu                      Interact with application menus
  hotkey                    Send keyboard shortcuts
  ...

External Tools (45):
  github:create_issue       [github] Create a new GitHub issue
  github:list_repos         [github] List repositories
  github:get_file           [github] Get file contents
  files:read_file           [files] Read file from filesystem
  files:write_file          [files] Write file to filesystem
  chrome-devtools:click     [chrome-devtools] Click element on webpage
  chrome-devtools:navigate_page [chrome-devtools] Navigate to URL
  ...

Summary:
  Native tools: 22
  External tools: 45 from 3 servers
  Total: 67 tools
```

### MCP List Command

List configured MCP servers with real-time health checking:

```bash
# List all servers with health check
peekaboo mcp list

# Skip health check for faster results
peekaboo mcp list --skip-health-check

# JSON output
peekaboo mcp list --json-output
```

**Example Output**:
```
Checking MCP server health...

browser: npx -y @agent-infra/mcp-server-browser@latest - ✓ Connected (15 tools, 134ms) [default]
github: npx -y @modelcontextprotocol/server-github - ✓ Connected (12 tools, 145ms)
files: npx -y @modelcontextprotocol/server-filesystem - ✓ Connected (8 tools, 89ms)
weather: /usr/local/bin/weather-mcp - ✗ Failed to connect (Command not found)

Total: 4 servers configured, 3 healthy, 35 external tools available
```

### MCP Server Management

Complete lifecycle management for external MCP servers:

#### Add Server
```bash
# Basic server addition
peekaboo mcp add github -- npx -y @modelcontextprotocol/server-github

# With environment variables
peekaboo mcp add github -e GITHUB_TOKEN=ghp_xxx -- npx -y @modelcontextprotocol/server-github

# With custom settings
peekaboo mcp add files \
  --timeout 15.0 \
  --description "Local filesystem access" \
  -- npx -y @modelcontextprotocol/server-filesystem /Users/me/docs

# Add but keep disabled
peekaboo mcp add weather --disabled -- weather-server --api-key xyz
```

#### Remove Server
```bash
# Remove with confirmation
peekaboo mcp remove github

# Force removal without confirmation
peekaboo mcp remove github --force
```

#### Test Connection
```bash
# Basic connection test
peekaboo mcp test github

# Test with tool listing
peekaboo mcp test github --show-tools --timeout 30
```

#### Server Information
```bash
# Human-readable info
peekaboo mcp info github

# JSON output for scripts
peekaboo mcp info github --json-output
```

#### Enable/Disable
```bash
# Enable disabled server
peekaboo mcp enable weather

# Disable server without removing
peekaboo mcp disable weather
```

## Configuration

MCP client settings are stored in `~/.peekaboo/config.json`. Peekaboo ships with BrowserMCP enabled by default, but you can disable it or add additional servers:

### Default Server Configuration

To disable the default BrowserMCP server:
```json
{
  "mcpClients": {
    "browser": {
      "enabled": false
    }
  }
}
```

### Custom Server Configuration

Full configuration example with additional servers:

```json
{
  "mcpClients": {
    "github": {
      "transport": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      },
      "enabled": true,
      "timeout": 10.0,
      "autoReconnect": true,
      "description": "GitHub repository management"
    },
    "files": {
      "transport": "stdio",
      "command": "npx", 
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/Documents"],
      "enabled": true,
      "timeout": 5.0,
      "autoReconnect": true,
      "description": "Filesystem operations"
    },
    "chrome-devtools": {
      "transport": "stdio",
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"],
      "enabled": true,
      "timeout": 15.0,
      "autoReconnect": false,
      "description": "Chrome DevTools automation"
    }
  },
  "toolDisplay": {
    "showMcpToolsByDefault": true,
    "useServerPrefixes": true,
    "groupByServer": false
  }
}
```

### Environment Variable Expansion

The configuration supports environment variable expansion:
- `${VAR_NAME}` - Required variable, fails if not set
- `${VAR_NAME:-default}` - Optional variable with default value

### Configuration Options

#### MCPClientConfig
- `transport` - Transport type ("stdio", "http", "sse") 
- `command` - Executable to run the MCP server
- `args` - Command line arguments
- `env` - Environment variables as key-value pairs
- `enabled` - Whether server is active (default: true)
- `timeout` - Connection timeout in seconds (default: 10.0)
- `autoReconnect` - Attempt reconnection on failure (default: true)
- `description` - Human-readable description

#### ToolDisplayConfig
- `showMcpToolsByDefault` - Include external tools in listings (default: true)
- `useServerPrefixes` - Show server prefixes on external tools (default: true)
- `groupByServer` - Group external tools by server in displays (default: false)

## Agent Integration

External tools work seamlessly with the Peekaboo agent system:

```bash
# Agent automatically uses both native and external tools
peekaboo agent "Create a GitHub issue titled 'MCP integration complete', then take a screenshot of the issue page and save it to ~/Desktop/issue.png"
```

This workflow uses:
1. `github:create_issue` - Create the GitHub issue (external tool)
2. `image` - Take screenshot (native tool)
3. Native file handling to save the screenshot

The agent system automatically:
- Discovers all available tools (native + external)
- Uses appropriate tools based on task requirements
- Provides unified error handling and response formatting
- Maintains tool attribution in responses

## Popular MCP Servers

### BrowserMCP (Default)
```bash
# Included by default, or add manually:
peekaboo mcp add browser -- npx -y @agent-infra/mcp-server-browser@latest
```
**Tools**: navigate, click, type, screenshot, get_url, get_title, wait_for_selector, evaluate_js, fill_form, close_tab, new_tab
**Description**: Lightweight browser automation via Puppeteer for web interaction tasks.

### GitHub Server
```bash
peekaboo mcp add github -e GITHUB_TOKEN=ghp_xxx -- npx -y @modelcontextprotocol/server-github
```
**Tools**: create_issue, list_repos, get_file, create_file, update_file, delete_file, create_pull_request, list_pull_requests, get_pull_request, merge_pull_request

### Filesystem Server
```bash
peekaboo mcp add files -- npx -y @modelcontextprotocol/server-filesystem /allowed/directory
```
**Tools**: read_file, write_file, create_directory, list_directory, move_file, delete_file, get_file_info

### Playwright Server
```bash
peekaboo mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```
**Tools**: navigate, click, type, screenshot, pdf, wait_for_selector, get_text, get_attribute, evaluate

### Database Servers
```bash
# SQLite
peekaboo mcp add sqlite -- npx -y @modelcontextprotocol/server-sqlite /path/to/database.db

# PostgreSQL  
peekaboo mcp add postgres -e DATABASE_URL=postgresql://... -- npx -y @modelcontextprotocol/server-postgres
```

## Health Monitoring

The MCP client system provides comprehensive health monitoring:

### Health States
- **✓ Connected** - Server reachable, tools available
- **✗ Disconnected** - Connection failed, shows error reason
- **⏳ Connecting** - Connection attempt in progress
- **⏸ Disabled** - Server disabled in configuration
- **? Unknown** - Server not configured or status unclear

### Health Information
- **Tool Count** - Number of tools available from server
- **Response Time** - Connection latency in milliseconds
- **Error Details** - Specific error messages for failed connections
- **Last Connected** - Timestamp of last successful connection

### Automatic Monitoring
- Health checks run automatically for `mcp list` command
- Background health monitoring for agent tool discovery
- Connection pooling and automatic reconnection
- Timeout handling with configurable limits

## Error Handling

### Connection Failures
- **Command not found**: Server executable not in PATH
- **Permission denied**: Insufficient permissions to run server
- **Connection timeout**: Server takes too long to respond
- **Protocol errors**: Server doesn't speak MCP protocol correctly

### Tool Execution Failures
- **Tool not found**: Requested tool not available on server
- **Invalid arguments**: Tool called with incorrect parameters
- **Server error**: Server returned error response
- **Network issues**: Connection lost during execution

### Graceful Degradation
- Continue operation when external servers are unavailable
- Clear error messages with troubleshooting hints
- Fallback to native tools when external tools fail
- Agent system handles mixed success/failure scenarios

## Performance Considerations

### Connection Management
- **Connection Pooling**: Reuse connections across tool calls
- **Lazy Loading**: Connect to servers only when tools are needed  
- **Timeout Control**: Configurable timeouts prevent hanging
- **Parallel Health Checks**: Check multiple servers concurrently

### Tool Discovery
- **Caching**: Cache tool lists to avoid repeated server queries
- **Background Refresh**: Update tool lists periodically in background
- **Selective Loading**: Load tools only from enabled servers
- **Error Recovery**: Retry failed connections with exponential backoff

### Memory Usage
- **Lightweight Proxies**: External tools are thin wrappers
- **Efficient Serialization**: Optimized message passing
- **Connection Cleanup**: Automatic cleanup of unused connections
- **Resource Limits**: Prevent runaway resource consumption

## Troubleshooting

### Common Issues

#### Server Not Starting
```bash
# Check if command exists
which npx
npm list -g @modelcontextprotocol/server-github

# Test server manually
npx -y @modelcontextprotocol/server-github
```

#### Permission Errors
```bash
# Check file permissions
ls -la /path/to/server/executable

# Environment variable issues
echo $GITHUB_TOKEN
export GITHUB_TOKEN=your_token_here
```

#### Connection Timeouts  
```bash
# Increase timeout
peekaboo mcp add github --timeout 30.0 -- npx -y @modelcontextprotocol/server-github

# Test connection manually
peekaboo mcp test github --timeout 60
```

#### Tools Not Appearing
```bash
# Refresh tool registry
peekaboo mcp test github --show-tools

# Check server health
peekaboo mcp list

# Verify server configuration
peekaboo mcp info github
```

### Debug Commands

```bash
# Verbose health checking
peekaboo mcp list --json-output | jq

# Test specific server with details
peekaboo mcp test github --show-tools --timeout 30

# Show all tools with server attribution
peekaboo tools --verbose --group-by-server

# Agent debug mode (if available)
peekaboo agent --verbose "list available tools"
```

### Log Analysis

Check Peekaboo logs for MCP client activity:
```bash
# Monitor MCP client logs
./scripts/pblog.sh -c MCPClientManager

# Monitor external tool execution
./scripts/pblog.sh -s "external tool"

# Check for connection errors
./scripts/pblog.sh -e | grep -i mcp
```

## Best Practices

### Server Configuration
1. **Use Descriptive Names**: Clear server names aid debugging
2. **Set Appropriate Timeouts**: Balance responsiveness vs reliability
3. **Environment Variables**: Use env vars for secrets, not hardcoded values
4. **Test Before Deployment**: Always test servers before production use

### Tool Organization
1. **Server Prefixes**: Keep prefixes enabled for clarity
2. **Logical Grouping**: Group related servers (e.g., `github-prod`, `github-staging`)
3. **Regular Health Checks**: Monitor server health in automated systems
4. **Graceful Degradation**: Design workflows to handle server failures

### Performance Optimization
1. **Selective Servers**: Enable only needed servers
2. **Connection Reuse**: Avoid unnecessary reconnections
3. **Reasonable Timeouts**: Don't set timeouts too high/low
4. **Resource Monitoring**: Watch memory/CPU usage with many servers

## Future Enhancements

### Advanced Features
- **Server Discovery**: Automatic discovery of MCP servers on network
- **Load Balancing**: Distribute requests across multiple server instances
- **Caching Layer**: Cache tool responses for performance
- **Metrics Collection**: Detailed performance and usage metrics

### UI Improvements
- **Interactive Configuration**: CLI wizard for server setup
- **Rich Terminal Output**: Enhanced formatting and colors
- **Progress Indicators**: Visual feedback for long-running operations
- **Tool Documentation**: Inline help for external tools

### Enterprise Features
- **Authentication**: OAuth and API key management
- **Authorization**: Role-based access control for tools
- **Audit Logging**: Comprehensive logging for compliance
- **Rate Limiting**: Prevent abuse of external services

## Implementation Details

### Core Components

**MCPClientManager** (`Core/PeekabooCore/Sources/PeekabooCore/MCP/Client/MCPClientManager.swift`)
- Actor-based manager for external MCP servers
- Handles connection lifecycle and health monitoring
- Provides thread-safe access to server operations

**ExternalMCPTool** (`Core/PeekabooCore/Sources/PeekabooCore/MCP/Client/ExternalMCPTool.swift`)
- Proxy tool implementation with server prefixes
- Forwards tool calls to appropriate external servers
- Provides unified error handling and response formatting

**Enhanced MCPToolRegistry** (`Core/PeekabooCore/Sources/PeekabooCore/MCP/Server/MCPToolRegistry.swift`)
- Extended to manage both native and external tools
- Provides categorization and filtering capabilities
- Maintains tool discovery and registration

### CLI Integration

**ToolsCommand** (`Apps/CLI/Sources/peekaboo/Commands/Core/ToolsCommand.swift`)
- New command for listing and filtering tools
- Supports multiple output formats and filtering options
- Integrates with tool categorization system

**Enhanced MCPCommand** (`Apps/CLI/Sources/peekaboo/Commands/MCP/MCPCommand.swift`)
- Extended with client management subcommands
- Provides comprehensive server lifecycle operations
- Includes health checking and diagnostic capabilities

### Testing Coverage

- **120+ test cases** covering all components
- Unit tests for core functionality and error handling
- Integration tests for CLI command parsing
- Configuration system validation tests
- Mock-based testing for external server scenarios

## Conclusion

The MCP client implementation transforms Peekaboo into a powerful MCP orchestrator that provides:

1. **Unified Access**: Single interface to entire MCP ecosystem
2. **Production Ready**: Comprehensive error handling and monitoring
3. **Developer Friendly**: Rich CLI with extensive filtering and formatting
4. **Performance Optimized**: Direct Swift implementation with connection pooling
5. **Extensible Architecture**: Easy addition of new external servers

Peekaboo now serves as both a provider and consumer in the MCP ecosystem, enabling users to leverage the full power of Model Context Protocol while maintaining the high-performance native Swift automation capabilities that make Peekaboo unique.
