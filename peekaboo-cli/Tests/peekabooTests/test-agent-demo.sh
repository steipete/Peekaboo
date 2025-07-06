#!/bin/bash
# Test script to demonstrate the AI Agent in action

set -e

echo "🤖 Peekaboo AI Agent Test Suite"
echo "================================"
echo ""

# Check for OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable not set"
    echo "Please set it with: export OPENAI_API_KEY='your-key-here'"
    exit 1
fi

# Build the project first
echo "📦 Building Peekaboo..."
cd "$(dirname "$0")/../../.."
npm run build:swift || swift build

# Get the path to the built executable
PEEKABOO="./peekaboo-cli/.build/debug/peekaboo"

echo ""
echo "✅ Build complete. Starting tests..."
echo ""

# Test 1: Direct invocation
echo "Test 1: Direct Invocation"
echo "-------------------------"
echo "Command: peekaboo \"Take a screenshot of the current window\""
echo ""
$PEEKABOO "Take a screenshot of the current window" --dry-run
echo ""

# Test 2: Agent subcommand with verbose
echo "Test 2: Agent with Verbose Output"
echo "---------------------------------"
echo "Command: peekaboo agent \"Open TextEdit and type Hello World\" --verbose --dry-run"
echo ""
$PEEKABOO agent "Open TextEdit and type Hello World" --verbose --dry-run
echo ""

# Test 3: Complex task with max steps
echo "Test 3: Complex Task with Step Limit"
echo "------------------------------------"
echo "Command: peekaboo agent \"Find all open windows and list them\" --max-steps 5 --json-output"
echo ""
$PEEKABOO agent "Find all open windows and list them" --max-steps 5 --json-output --dry-run
echo ""

# Test 4: Window management
echo "Test 4: Window Management"
echo "------------------------"
echo "Command: peekaboo agent \"Minimize Safari if it's open\" --dry-run"
echo ""
$PEEKABOO agent "Minimize Safari if it's open" --dry-run
echo ""

# Test 5: Real execution (if confirmed)
echo "Test 5: Real Execution Demo"
echo "---------------------------"
echo "Would you like to see a real execution (not dry-run)?"
echo "This will actually open TextEdit and type text."
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Command: peekaboo \"Open TextEdit and type 'Peekaboo AI Agent Demo'\""
    echo ""
    $PEEKABOO "Open TextEdit and type 'Peekaboo AI Agent Demo'" --verbose
    echo ""
    echo "✅ Demo complete! Check TextEdit to see the result."
else
    echo "Skipping real execution demo."
fi

echo ""
echo "🎉 All tests complete!"
echo ""
echo "To run the integration test suite:"
echo "  RUN_AGENT_TESTS=true swift test --filter AgentIntegrationTests"
echo ""
echo "To use in your own scripts:"
echo "  export OPENAI_API_KEY='your-key'"
echo "  peekaboo \"Your natural language command here\"
echo """