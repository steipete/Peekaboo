#!/bin/bash

# Test the agent with vision capabilities

echo "=== Testing Peekaboo Agent with Vision Capabilities ==="
echo

# Test 1: Take a screenshot and analyze it
echo "Test 1: Screenshot with vision analysis"
echo "Command: Take a screenshot and describe what you see on the screen"
OPENAI_API_KEY="${OPENAI_API_KEY}" ./peekaboo agent "Take a screenshot using the see command with analyze=true and tell me what applications are visible" --verbose --model gpt-4o

echo
echo "=== Test Complete ==="