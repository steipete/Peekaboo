#!/bin/bash

echo "=== Testing Peekaboo Agent - Final Test ==="
echo

# Test 1: Direct command tests
echo "Test 1: Verifying commands work directly"
echo "1a. List apps:"
./peekaboo list apps --json-output | jq -r '.data.applications[] | .app_name' | head -5
echo

echo "1b. Launch app:"
./peekaboo app launch Calculator --json-output | jq '.success'
echo

echo "1c. See command:"
./peekaboo see --app Calculator --json-output | jq '.success'
echo

# Test 2: Agent with list
echo "Test 2: Agent listing apps"
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 30 ./peekaboo agent "Use the list tool with target='apps' to show running applications" --model gpt-4o || echo "Timeout or error"
echo

# Test 3: Agent with app launch
echo "Test 3: Agent launching app"
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 30 ./peekaboo agent "Launch Calculator application" --model gpt-4o || echo "Timeout or error"
echo

echo "=== Tests Complete ==="