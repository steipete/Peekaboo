#!/bin/bash

# Test publishing script for Peekaboo
# This script tests the npm package in a local registry before public release

set -e

echo "🧪 Testing npm package publishing..."
echo ""

# Save current registry
ORIGINAL_REGISTRY=$(npm config get registry)
echo "📦 Original registry: $ORIGINAL_REGISTRY"

# Check if Verdaccio is installed
if ! command -v verdaccio &> /dev/null; then
    echo "❌ Verdaccio not found. Install it with: npm install -g verdaccio"
    exit 1
fi

# Start Verdaccio in background if not already running
if ! curl -s http://localhost:4873/ > /dev/null; then
    echo "🚀 Starting Verdaccio local registry..."
    verdaccio > /tmp/verdaccio.log 2>&1 &
    VERDACCIO_PID=$!
    sleep 3
else
    echo "✅ Verdaccio already running"
fi

# Set to local registry
echo "🔄 Switching to local registry..."
npm set registry http://localhost:4873/

# Create test auth token (Verdaccio accepts any auth on first use)
echo "🔑 Setting up authentication..."
TOKEN=$(echo -n "testuser:testpass" | base64)
npm set //localhost:4873/:_authToken "$TOKEN"

# Build the binary that ships inside the package
echo "🔨 Building arm64 binary..."
npm run build:swift

# Publish to local registry
echo "📤 Publishing to local registry..."
npm publish --registry http://localhost:4873/

echo ""
echo "✅ Package published to local registry!"
echo ""

# Test installation in a temporary directory
TEMP_DIR=$(mktemp -d)
echo "📥 Testing installation in: $TEMP_DIR"
cd "$TEMP_DIR"

# Initialize a test project
npm init -y > /dev/null 2>&1

# Install the package
echo "📦 Installing @steipete/peekaboo from local registry..."
npm install @steipete/peekaboo --registry http://localhost:4873/

# Check if binary exists
if [ -f "node_modules/@steipete/peekaboo/peekaboo" ]; then
    echo "✅ Binary found in package"
    
    # Test the binary
    echo "🧪 Testing binary..."
    if node_modules/@steipete/peekaboo/peekaboo --version; then
        echo "✅ Binary works!"
    else
        echo "❌ Binary failed to execute"
    fi
else
    echo "❌ Binary not found in package!"
fi

# Test the MCP server
echo ""
echo "🧪 Testing MCP server..."
cat > test-mcp.js << 'EOF'
const { spawn } = require('child_process');

const server = spawn('node', ['node_modules/@steipete/peekaboo/peekaboo-mcp.js'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

const request = JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "tools/list"
}) + '\n';

server.stdin.write(request);

server.stdout.on('data', (data) => {
  const lines = data.toString().split('\n').filter(l => l.trim());
  for (const line of lines) {
    try {
      const response = JSON.parse(line);
      if (response.result && response.result.tools) {
        console.log('✅ MCP server responded with tools:', response.result.tools.map(t => t.name).join(', '));
        server.kill();
        process.exit(0);
      }
    } catch (e) {
      // Ignore non-JSON lines
    }
  }
});

setTimeout(() => {
  console.error('❌ Timeout waiting for MCP server response');
  server.kill();
  process.exit(1);
}, 5000);
EOF

if node test-mcp.js; then
    echo "✅ MCP server test passed!"
else
    echo "❌ MCP server test failed"
fi

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"

# Restore original registry
echo ""
echo "🔄 Restoring original registry..."
npm set registry "$ORIGINAL_REGISTRY"
npm config delete //localhost:4873/:_authToken

# Kill Verdaccio if we started it
if [ ! -z "$VERDACCIO_PID" ]; then
    echo "🛑 Stopping Verdaccio..."
    kill $VERDACCIO_PID 2>/dev/null || true
fi

echo ""
echo "✨ Test publish complete!"
echo ""
echo "📋 Next steps:"
echo "1. If all tests passed, you can publish to npm with: npm publish"
echo "2. Remember to tag appropriately if beta: npm publish --tag beta"
echo "3. Create a GitHub release after publishing"
