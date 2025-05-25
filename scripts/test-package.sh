#!/bin/bash

# Simple package test script for Peekaboo MCP
# Tests the package locally without publishing

set -e

echo "🧪 Testing npm package locally..."
echo ""

# Build everything
echo "🔨 Building package..."
npm run build:all

# Create package
echo "📦 Creating package tarball..."
PACKAGE_FILE=$(npm pack 2>&1 | tail -1)
PACKAGE_PATH=$(pwd)/$PACKAGE_FILE
echo "Created: $PACKAGE_FILE"

# Get package info
PACKAGE_SIZE=$(du -h "$PACKAGE_FILE" | cut -f1)
echo "Package size: $PACKAGE_SIZE"

# Test installation in a temporary directory
TEMP_DIR=$(mktemp -d)
echo ""
echo "📥 Testing installation in: $TEMP_DIR"
cd "$TEMP_DIR"

# Initialize a test project
npm init -y > /dev/null 2>&1

# Install the package from tarball
echo "📦 Installing from tarball..."
npm install "$PACKAGE_PATH"

# Check installation
echo ""
echo "🔍 Checking installation..."

# Check if binary exists and is executable
if [ -f "node_modules/@steipete/peekaboo-mcp/peekaboo" ]; then
    echo "✅ Binary found"
    
    # Check if executable
    if [ -x "node_modules/@steipete/peekaboo-mcp/peekaboo" ]; then
        echo "✅ Binary is executable"
        
        # Test the binary
        echo ""
        echo "🧪 Testing Swift CLI..."
        if node_modules/@steipete/peekaboo-mcp/peekaboo --version; then
            echo "✅ Swift CLI works!"
        else
            echo "❌ Swift CLI failed"
        fi
    else
        echo "❌ Binary is not executable"
    fi
else
    echo "❌ Binary not found!"
fi

# Check main entry point
if [ -f "node_modules/@steipete/peekaboo-mcp/dist/index.js" ]; then
    echo "✅ Main entry point found"
else
    echo "❌ Main entry point missing!"
fi

# List all files in package
echo ""
echo "📋 Package contents:"
find node_modules/@steipete/peekaboo-mcp -type f -name "*.js" -o -name "*.d.ts" -o -name "peekaboo" | head -20

# Test the MCP server
echo ""
echo "🧪 Testing MCP server startup..."
cat > test-mcp.js << 'EOF'
const { spawn } = require('child_process');
const path = require('path');

const mcpPath = path.join('node_modules', '@steipete', 'peekaboo-mcp', 'dist', 'index.js');
const server = spawn('node', [mcpPath], {
  stdio: ['pipe', 'pipe', 'pipe']
});

const request = JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "tools/list"
}) + '\n';

setTimeout(() => {
  server.stdin.write(request);
}, 100);

let responded = false;
server.stdout.on('data', (data) => {
  const lines = data.toString().split('\n').filter(l => l.trim());
  for (const line of lines) {
    try {
      const response = JSON.parse(line);
      if (response.result && response.result.tools) {
        console.log('✅ MCP server works! Available tools:', response.result.tools.map(t => t.name).join(', '));
        responded = true;
        server.kill();
        process.exit(0);
      }
    } catch (e) {
      // Ignore non-JSON lines
    }
  }
});

server.stderr.on('data', (data) => {
  console.error('Server error:', data.toString());
});

setTimeout(() => {
  if (!responded) {
    console.error('❌ Timeout waiting for MCP server response');
    server.kill();
    process.exit(1);
  }
}, 5000);
EOF

node test-mcp.js

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"
rm -f "$PACKAGE_PATH"

echo ""
echo "✨ Package test complete!"
echo ""
echo "If all tests passed, the package is ready for publishing!"