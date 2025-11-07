#!/bin/bash
# Simple wrapper for Chrome DevTools MCP that doesn't trigger PTY detection
cd /Users/steipete/Projects/Peekaboo
export TERM=dumb
export NO_COLOR=1
exec /Users/steipete/.nvm/versions/node/v24.4.1/bin/npx -y chrome-devtools-mcp@latest "$@"
