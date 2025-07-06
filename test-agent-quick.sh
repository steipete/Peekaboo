#!/bin/bash
# Quick test of the AI agent functionality

echo "🤖 Testing Peekaboo AI Agent"
echo "=========================="
echo ""

# Test 1: Without API key
echo "Test 1: Error handling without API key"
unset OPENAI_API_KEY
.build/arm64-apple-macosx/debug/peekaboo agent "Test task" --json-output
echo ""

# Test 2: Direct invocation
echo "Test 2: Direct invocation (requires API key)"
if [ -n "$OPENAI_API_KEY" ]; then
    .build/arm64-apple-macosx/debug/peekaboo "List all windows"
else
    echo "Skipping - OPENAI_API_KEY not set"
fi
echo ""

# Test 3: Help output
echo "Test 3: Agent help"
.build/arm64-apple-macosx/debug/peekaboo agent --help 2>&1 || true
echo ""

echo "✅ Tests complete"