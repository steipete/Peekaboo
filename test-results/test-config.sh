#!/bin/bash
set -e

echo "=== Testing Peekaboo Configuration Management ==="
echo

# Create a test config directory
TEST_CONFIG_DIR="$HOME/.config/peekaboo-test"
mkdir -p "$TEST_CONFIG_DIR"

# Test 1: Initialize config
echo "Test 1: Initializing configuration..."
PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config init --force
echo "✓ Config initialized"
echo

# Test 2: Show config
echo "Test 2: Showing configuration..."
echo "  Default config:"
PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config show
echo

# Test 3: Show effective config
echo "Test 3: Showing effective configuration (with env vars)..."
PEEKABOO_AI_PROVIDERS="test/provider" PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config show --effective
echo

# Test 4: Validate config
echo "Test 4: Validating configuration..."
PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config validate
echo "✓ Config validation passed"
echo

# Test 5: Test environment variable expansion
echo "Test 5: Testing environment variable expansion..."
cat > "$TEST_CONFIG_DIR/config.json" << 'EOF'
{
  "aiProviders": {
    "openaiApiKey": "${OPENAI_API_KEY}",
    "providers": "openai/gpt-4o"
  },
  "defaults": {
    "savePath": "${HOME}/Desktop/Screenshots"
  }
}
EOF
echo "  Config with env vars created"
OPENAI_API_KEY="test-key" PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config show --effective | grep -E "(openaiApiKey|savePath)"
echo

# Test 6: Test invalid config
echo "Test 6: Testing invalid configuration..."
cat > "$TEST_CONFIG_DIR/config.json" << 'EOF'
{
  "invalid": "config",
  "with": ["bad", "structure"
}
EOF
PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config validate 2>&1 || echo "✓ Invalid config properly detected"
echo

# Test 7: Test config precedence
echo "Test 7: Testing configuration precedence..."
cat > "$TEST_CONFIG_DIR/config.json" << 'EOF'
{
  "aiProviders": {
    "providers": "config/provider"
  },
  "defaults": {
    "savePath": "/tmp/config-path"
  }
}
EOF
echo "  Config file providers: config/provider"
echo "  Env var providers: env/provider"
echo "  Effective providers:"
PEEKABOO_AI_PROVIDERS="env/provider" PEEKABOO_CONFIG_DIR="$TEST_CONFIG_DIR" ../peekaboo config show --effective | grep "providers"
echo

# Test 8: Test config subcommand help
echo "Test 8: Testing config subcommand help..."
../peekaboo config --help | head -10
echo

# Cleanup
echo "Cleaning up test configuration..."
rm -rf "$TEST_CONFIG_DIR"
echo "✓ Cleanup complete"
echo

echo "=== Configuration Tests Complete ==="