# MCP Server Testing Guide

This guide explains how to test the Peekaboo MCP (Model Context Protocol) server during development using various tools and approaches.

## Overview

The Peekaboo MCP server (`@steipete/peekaboo-mcp`) provides AI assistants with direct access to macOS automation capabilities through a standardized protocol. Testing this server effectively requires tools that can simulate MCP client interactions and allow rapid iteration during development.

## Testing Approaches

### 1. MCP Inspector (Official Tool)

The official MCP Inspector provides a web-based interface for testing MCP servers:

```bash
# Test the npm beta version
npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp@beta

# Test your local build
npm run build  # Build the TypeScript server
npx @modelcontextprotocol/inspector node Server/dist/index.js

# Test with specific AI provider
PEEKABOO_AI_PROVIDERS="ollama/llama3.3" npx @modelcontextprotocol/inspector node Server/dist/index.js
```

**Features:**
- Visual interface showing available tools, resources, and prompts
- Interactive tool calling with parameter inputs
- Real-time response visualization
- Session history tracking

### 2. Reloaderoo (Development Proxy)

Reloaderoo is a powerful MCP development tool that provides both CLI testing and hot-reload capabilities. Due to npm package issues, it should be built from source.

#### Installation

```bash
# Clone and build from source
git clone https://github.com/cameroncooke/reloaderoo.git
cd reloaderoo
npm install
npm run build
```

#### CLI Mode (Direct Testing)

```bash
# First, build your local MCP server
npm run build

# List available tools
node reloaderoo/dist/bin/reloaderoo.js inspect list-tools -- node Server/dist/index.js

# Call a specific tool
node reloaderoo/dist/bin/reloaderoo.js inspect call-tool image --params '{"format": "data", "app_target": "Safari"}' -- node Server/dist/index.js

# Get server information
node reloaderoo/dist/bin/reloaderoo.js inspect server-info -- node Server/dist/index.js

# List resources
node reloaderoo/dist/bin/reloaderoo.js inspect list-resources -- node Server/dist/index.js

# List prompts
node reloaderoo/dist/bin/reloaderoo.js inspect list-prompts -- node Server/dist/index.js

# Test with AI provider
PEEKABOO_AI_PROVIDERS="anthropic/claude-opus-4-20250514" node reloaderoo/dist/bin/reloaderoo.js inspect call-tool analyze --params '{"image_path": "/tmp/screenshot.png", "question": "What is shown in this image?"}' -- node Server/dist/index.js
```

#### Proxy Mode (Hot-Reload Development)

```bash
# Start Reloaderoo as a proxy (for manual testing)
node reloaderoo/dist/bin/reloaderoo.js proxy -- node Server/dist/index.js

# Configure in Claude Code for hot-reload development with local build
claude mcp add peekaboo-local node $PWD/reloaderoo/dist/bin/reloaderoo.js proxy -- node $PWD/Server/dist/index.js

# The proxy adds a 'restart_server' tool that can be called from within Claude Code:
# "Please restart the MCP server" - This will reload your local changes without losing session context
```

**Benefits:**
- Test MCP servers without full client setup
- Hot-reload servers during development without losing AI session context
- Direct command-line access for CI/CD integration
- Transparent protocol forwarding with debug logging
- Built-in `restart_server` tool for seamless reloading

### 3. Direct Claude Code Integration

For production-like testing, integrate directly with Claude Code:

```bash
# Add the MCP server to Claude Code (local scope)
claude mcp add peekaboo npx -y @steipete/peekaboo-mcp@beta

# Add with environment variables
claude mcp add peekaboo npx -y @steipete/peekaboo-mcp@beta \
  -e PEEKABOO_AI_PROVIDERS="anthropic/claude-opus-4-20250514"

# List configured servers
claude mcp list

# Remove server
claude mcp remove peekaboo
```

### 4. Manual Testing with curl

For low-level protocol testing, you can interact with the MCP server directly:

```bash
# Start the server in stdio mode
npx @steipete/peekaboo-mcp@beta

# Send JSON-RPC requests via stdin
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | npx @steipete/peekaboo-mcp@beta
```

## Development Workflow

### Recommended Testing Cycle

1. **Initial Development:**
   - Use MCP Inspector for interactive testing
   - Verify tool schemas and responses
   - Test error handling with invalid inputs

2. **Integration Testing:**
   - Configure in Claude Code for real-world usage
   - Test tool interactions in actual AI conversations
   - Verify resource access and permissions

3. **Continuous Development with Reloaderoo:**
   - Start with Reloaderoo proxy in Claude Code
   - Make changes to your TypeScript server code
   - Run `npm run build` to compile changes
   - In Claude Code, ask: "Please restart the MCP server"
   - The proxy reloads with your new code while maintaining session context
   - Continue testing without losing conversation history

### Hot-Reload Example Workflow

```bash
# Terminal 1: Set up Reloaderoo with local server
cd ~/Projects/Peekaboo
claude mcp add peekaboo-local node $PWD/reloaderoo/dist/bin/reloaderoo.js proxy -- node $PWD/Server/dist/index.js

# Terminal 2: Watch for changes and rebuild
npm run build:watch  # If available, or manually run npm run build after changes

# In Claude Code:
# 1. Test current functionality: "Take a screenshot of Safari"
# 2. Make changes to Server/src/tools/image.ts
# 3. Run: npm run build
# 4. Tell Claude: "Please restart the MCP server"
# 5. Test new functionality without losing context
```

### Environment Configuration

```bash
# Set AI provider for agent tools
export PEEKABOO_AI_PROVIDERS="anthropic/claude-opus-4-20250514"

# Enable debug logging
export DEBUG="peekaboo:*"

# Configure credentials
./scripts/peekaboo-wait.sh config set-credential ANTHROPIC_API_KEY sk-ant-...
```

## Common Testing Scenarios

### 1. Tool Discovery
Test that all tools are properly exposed:
- List all available tools
- Verify tool descriptions are clear
- Check parameter schemas are complete

### 2. Screenshot Capabilities
```javascript
// Expected tool: captureScreen
{
  "app": "Safari",
  "savePath": "/tmp/screenshot.png",
  "format": "png"
}
```

### 3. UI Automation
```javascript
// Expected tool: click
{
  "elementDescription": "Submit button"
}

// Expected tool: type
{
  "text": "Hello, World!"
}
```

### 4. Agent Integration
```javascript
// Expected tool: runAgent
{
  "task": "Take a screenshot of the current window",
  "provider": "anthropic/claude-opus-4-20250514"
}
```

## Troubleshooting

### Server Won't Start
- Check Node.js version (requires 18+)
- Verify all dependencies are installed
- Ensure no port conflicts for SSE/HTTP modes

### Tools Not Available
- Verify Peekaboo CLI is built and accessible
- Check PATH includes Peekaboo binary location
- Ensure proper permissions for screen recording and accessibility

### Connection Issues
- For stdio mode: Ensure proper JSON-RPC formatting
- For SSE mode: Check firewall settings
- For HTTP mode: Verify CORS configuration

## Best Practices

1. **Version Testing:**
   - Always test with specific versions (`@beta`, `@latest`)
   - Document which version was tested
   - Test upgrade paths between versions

2. **Error Handling:**
   - Test with invalid parameters
   - Verify graceful degradation
   - Check timeout handling

3. **Performance Testing:**
   - Monitor response times for tools
   - Test with rapid sequential calls
   - Verify memory usage over time

4. **Security Testing:**
   - Validate input sanitization
   - Test path traversal prevention
   - Verify credential handling

## Future Improvements

1. **Automated Testing Suite:**
   - Create comprehensive test cases
   - Implement CI/CD integration
   - Add performance benchmarks

2. **Mock MCP Client:**
   - Build lightweight testing client
   - Support scripted test scenarios
   - Enable regression testing

3. **Debug Mode Enhancements:**
   - Add detailed protocol logging
   - Implement request/response recording
   - Create replay functionality

## Conclusion

Testing MCP servers effectively requires a combination of tools and approaches. While the MCP Inspector provides excellent interactive testing, tools like Reloaderoo (once installation issues are resolved) will enable more efficient development workflows with hot-reload capabilities. Direct integration with Claude Code remains the gold standard for production testing.