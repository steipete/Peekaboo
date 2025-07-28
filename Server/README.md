# Peekaboo MCP Server

This directory contains the Model Context Protocol (MCP) server implementation for Peekaboo, enabling integration with Claude Desktop and Claude Code.

## What is MCP?

The Model Context Protocol allows AI assistants like Claude to interact with external tools and services. This MCP server exposes all of Peekaboo's macOS automation capabilities to Claude.

## Quick Start

1. **Build the server**:
   ```bash
   npm install
   npm run build
   ```

2. **Configure Claude Desktop or Claude Code**:
   - See [SETUP_INSTRUCTIONS.md](./SETUP_INSTRUCTIONS.md) for detailed configuration steps

## Available Tools

The MCP server exposes 20+ tools for macOS automation:
- Screen capture and image analysis
- UI element detection and interaction
- Application and window management
- Keyboard and mouse automation
- System dialog interaction
- And much more...

## Development

- `npm run dev` - Watch mode for TypeScript changes
- `npm run inspector` - Test with MCP Inspector
- `npm test` - Run tests

## Requirements

- macOS 14.0+ (Sonoma)
- Node.js 18+
- Peekaboo CLI binary (built from parent project)
- Screen Recording and Accessibility permissions

See the main [Peekaboo README](../README.md) for more information about the project.