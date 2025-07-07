#!/bin/bash

echo "Testing Hotkey Command Formats"
echo "=============================="
echo ""

cd peekaboo-cli

# Test comma-separated format
echo "1. Testing comma-separated format: 'cmd,c'"
./peekaboo hotkey --keys "cmd,c" --json-output | jq '.data | {keys, keyCount}'
echo ""

echo "2. Testing comma-separated with spaces: 'cmd, shift, t'"
./peekaboo hotkey --keys "cmd, shift, t" --json-output | jq '.data | {keys, keyCount}'
echo ""

# Test space-separated format
echo "3. Testing space-separated format: 'cmd c'"
./peekaboo hotkey --keys "cmd c" --json-output | jq '.data | {keys, keyCount}'
echo ""

echo "4. Testing space-separated multiple: 'cmd shift t'"
./peekaboo hotkey --keys "cmd shift t" --json-output | jq '.data | {keys, keyCount}'
echo ""

# Test single keys
echo "5. Testing single key: 'escape'"
./peekaboo hotkey --keys "escape" --json-output | jq '.data | {keys, keyCount}'
echo ""

echo "6. Testing single key: 'return'"
./peekaboo hotkey --keys "return" --json-output | jq '.data | {keys, keyCount}'
echo ""

# Test edge cases
echo "7. Testing with extra spaces: '  cmd   a  '"
./peekaboo hotkey --keys "  cmd   a  " --json-output | jq '.data | {keys, keyCount}'
echo ""

echo "✅ All hotkey format tests completed!"