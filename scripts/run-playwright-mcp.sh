#!/bin/bash
# Simple wrapper that doesn't trigger PTY detection
cd /Users/steipete/Projects/Peekaboo
export TERM=dumb
export NO_COLOR=1
exec /Users/steipete/.nvm/versions/node/v24.4.1/bin/npx @playwright/mcp@latest "$@"