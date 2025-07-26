#!/bin/bash

echo "Testing o3 reasoning token display..."
echo "This test requires OPENAI_API_KEY to be set"
echo ""

# Enable debug logging to see what's happening
export PEEKABOO_LOG_LEVEL=debug

# Test with a simple reasoning task
echo "Test 1: Simple math problem that should trigger reasoning"
./scripts/peekaboo-wait.sh agent --verbose "What is 15 * 17? Think step by step and show your reasoning."

echo ""
echo "Test 2: Complex reasoning task"
./scripts/peekaboo-wait.sh agent "I have 3 apples. I eat 1, then buy 5 more, then give away half. How many do I have? Explain your reasoning step by step."

echo ""
echo "To see the raw JSON from OpenAI, run with debug logging:"
echo "PEEKABOO_LOG_LEVEL=debug ./scripts/peekaboo-wait.sh agent --verbose \"your task\""