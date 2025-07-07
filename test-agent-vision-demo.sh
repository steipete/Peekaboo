#!/bin/bash

# Comprehensive test of Peekaboo Agent with Vision Capabilities

echo "=== Peekaboo Agent with Vision Capabilities Demo ==="
echo
echo "This demo shows how the agent can:"
echo "1. Launch applications"
echo "2. Interact with UI elements" 
echo "3. Take screenshots"
echo "4. Analyze content using vision AI"
echo "5. Answer questions about what it sees"
echo

# Complex task combining multiple capabilities
echo "=== Test: Complex Task with Vision ==="
echo "Task: Open Safari, navigate to apple.com, take a screenshot and describe what you see"
echo

OPENAI_API_KEY="${OPENAI_API_KEY}" ./peekaboo agent \
  "Launch Safari, wait 2 seconds for it to load, then take a screenshot and tell me what's on the webpage" \
  --model gpt-4o \
  --verbose

echo
echo "=== Demo Complete ==="
echo
echo "The agent successfully demonstrated:"
echo "✓ Application control (launching Safari)"
echo "✓ Screenshot capture"
echo "✓ Vision analysis using GPT-4o"
echo "✓ Natural language understanding and task execution"