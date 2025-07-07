#!/bin/bash

echo "=== Testing Vision Capabilities Directly ==="
echo

# Test 1: Take a screenshot
echo "Step 1: Taking screenshot..."
SCREENSHOT_PATH=$(./peekaboo image --mode frontmost --json-output | jq -r '.data.saved_files[0].path')
echo "Screenshot saved to: $SCREENSHOT_PATH"
echo

# Test 2: Analyze the screenshot
echo "Step 2: Analyzing screenshot with vision..."
PEEKABOO_AI_PROVIDERS="openai/gpt-4o" ./peekaboo analyze "$SCREENSHOT_PATH" "What applications are visible on the screen? List all windows and their content." --json-output | jq -r '.data.analysis.text'
echo

echo "=== Test Complete ==="