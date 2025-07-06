#!/bin/bash
# Peekaboo AI Agent Demo Script

echo "🤖 Peekaboo AI Agent Demo"
echo "========================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  Warning: OPENAI_API_KEY not set${NC}"
    echo "The agent requires an OpenAI API key to function."
    echo ""
    echo "To set it temporarily for this demo:"
    echo "  export OPENAI_API_KEY='your-api-key-here'"
    echo ""
    echo "Or add it to your shell profile for permanent use."
    exit 1
fi

# Path to peekaboo binary
PEEKABOO="./peekaboo-cli/.build/debug/peekaboo"

# Check if binary exists
if [ ! -f "$PEEKABOO" ]; then
    echo "Building Peekaboo first..."
    npm run build:swift
fi

echo -e "${GREEN}✅ OpenAI API key found${NC}"
echo ""

# Demo 1: Direct invocation
echo -e "${BLUE}Demo 1: Direct Invocation (Dry Run)${NC}"
echo "Command: peekaboo \"Take a screenshot of the current window\" --dry-run"
echo "----------------------------------------"
$PEEKABOO "Take a screenshot of the current window" --dry-run --json-output | jq '.'
echo ""

# Demo 2: Agent subcommand with verbose
echo -e "${BLUE}Demo 2: Agent Command with Verbose (Dry Run)${NC}"
echo "Command: peekaboo agent \"List all open windows\" --verbose --dry-run"
echo "----------------------------------------"
$PEEKABOO agent "List all open windows" --verbose --dry-run
echo ""

# Demo 3: Complex task
echo -e "${BLUE}Demo 3: Complex Task Planning (Dry Run)${NC}"
echo "Command: peekaboo agent \"Open TextEdit and type Hello World\" --dry-run --json-output"
echo "----------------------------------------"
$PEEKABOO agent "Open TextEdit and type Hello World" --dry-run --json-output | jq '.'
echo ""

# Demo 4: Interactive execution
echo -e "${YELLOW}Demo 4: Real Execution (Interactive)${NC}"
echo "----------------------------------------"
echo "The following command will actually interact with your system:"
echo "  peekaboo \"Take a screenshot and save it to Desktop\""
echo ""
read -p "Would you like to run this? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Executing..."
    $PEEKABOO "Take a screenshot and save it to Desktop" --verbose
    echo -e "${GREEN}✅ Done! Check your Desktop for the screenshot.${NC}"
else
    echo "Skipped real execution."
fi

echo ""
echo -e "${GREEN}🎉 Demo complete!${NC}"
echo ""
echo "Try these commands yourself:"
echo "  peekaboo \"Open Safari and search for weather\""
echo "  peekaboo agent \"Minimize all windows\" --dry-run"
echo "  peekaboo agent \"Click on the Apple menu\" --verbose"
echo ""