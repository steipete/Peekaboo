#!/bin/bash
# MCP Playwright server wrapper that works around stdio buffering issues
# This script ensures proper process handling for Swift Process class

# Set up environment to avoid TTY detection issues
export TERM=dumb
export NO_COLOR=1
export FORCE_COLOR=0

# Ensure PATH includes node locations
export PATH="/Users/steipete/.nvm/versions/node/v24.4.1/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Use stdbuf to disable buffering on stdout/stderr
# This is critical to prevent hanging with pipes
exec stdbuf -o0 -e0 /Users/steipete/.nvm/versions/node/v24.4.1/bin/node \
  /Users/steipete/.nvm/versions/node/v24.4.1/lib/node_modules/@playwright/mcp/cli.js "$@"