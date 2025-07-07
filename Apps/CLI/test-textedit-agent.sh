#!/bin/bash

# Test script to demonstrate TextEdit automation with the Agent

set -e

echo "Testing TextEdit automation with Peekaboo Agent..."
echo "========================================="

# Set up environment
export OPENAI_API_KEY="${OPENAI_API_KEY}"

# Build the Swift CLI if not already built
if [ ! -f "./.build/debug/peekaboo" ]; then
    echo "Building Swift CLI..."
    swift build
fi

# Test the improved commands first
echo -e "\n1. Testing improved commands..."
echo "   - Launching TextEdit"
./.build/debug/peekaboo app launch TextEdit --json-output | jq '.'

sleep 2

echo -e "\n   - Taking screenshot"
./.build/debug/peekaboo see --app TextEdit --json-output | jq '.data | {window_title, element_count, session_id}'

echo -e "\n   - Testing fast typing (5ms delay)"
./.build/debug/peekaboo type "Testing fast typing with 5ms delay!" --json-output | jq '.'

echo -e "\n   - Testing space-separated hotkey format"
./.build/debug/peekaboo hotkey --keys "cmd a" --json-output | jq '.data | {keys, keyCount}'

echo -e "\n   - Testing comma-separated hotkey format"
./.build/debug/peekaboo hotkey --keys "cmd,b" --json-output | jq '.data | {keys, keyCount}'

# Now test with the Agent
echo -e "\n2. Testing Agent automation..."
echo "   Running: Open TextEdit, type a message, make it bold and italic, then save it"

./.build/debug/peekaboo agent \
    "Open TextEdit if not already open. Type 'Hello from Peekaboo Agent! This text was typed automatically.' Then select all text, make it bold and italic. Change the font size to 24. Finally save the document." \
    --verbose \
    --json-output | jq '.'

echo -e "\nTextEdit automation test completed!"