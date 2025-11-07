#!/usr/bin/env node
// Direct launcher for Chrome DevTools MCP
(async () => {
  try {
    await import('chrome-devtools-mcp/build/src/index.js');
  } catch (error) {
    console.error('Failed to start chrome-devtools-mcp:', error);
    process.exit(1);
  }
})();
