#!/bin/bash
# Wrapper script for Chrome DevTools MCP server that disables TTY detection
# This helps avoid hanging issues with npx
cd /Users/steipete/Projects/Peekaboo
export TERM=dumb
export NO_COLOR=1
exec npx -y chrome-devtools-mcp@latest "$@"
