#!/bin/bash

echo "=== Testing Improved Calculator Agent ==="
echo "Now the agent can see button labels!"
echo

# First, show the button mapping
echo "1. Button Label Mapping:"
echo "========================"
./peekaboo see --app Calculator --json-output | jq '.data.ui_elements[] | select(.role == "AXButton") | select(.label | test("^[0-9]$")) | {button: .label, id: .id}' | jq -s 'sort_by(.button | tonumber)'
echo

# Test simple calculation
echo "2. Test Calculation: 7 * 9"
echo "=========================="
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 30 ./peekaboo agent "Clear Calculator and calculate 7 * 9" --model gpt-4o

echo
echo "3. Test Calculation: 123 + 456"
echo "=============================="
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 30 ./peekaboo agent "Calculate 123 + 456" --model gpt-4o

echo
echo "=== Tests Complete ==="