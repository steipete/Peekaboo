#!/bin/bash

# Test suite for enhanced error messages

echo "=== Enhanced Error Message Test Suite ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Poltergeist is running
echo "Checking Poltergeist status..."
npm run poltergeist:status
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Starting Poltergeist...${NC}"
    npm run poltergeist:haunt &
    sleep 3
fi

echo ""
echo "Running Swift tests for enhanced errors..."
echo ""

# Run unit tests (these use mocks and always run)
echo -e "${GREEN}Running unit tests...${NC}"
cd Apps/CLI
swift test --filter EnhancedErrorTests

# Run integration tests if requested
if [ "$1" == "--integration" ]; then
    echo ""
    echo -e "${GREEN}Running integration tests...${NC}"
    echo "Note: These require OPENAI_API_KEY to be set"
    
    # Check for API key
    if [ -z "$OPENAI_API_KEY" ]; then
        echo -e "${RED}Error: OPENAI_API_KEY not set${NC}"
        echo "Set your OpenAI API key or use: ./peekaboo config set-credential OPENAI_API_KEY <your-key>"
        exit 1
    fi
    
    RUN_INTEGRATION_TESTS=1 swift test --filter EnhancedErrorIntegrationTests
fi

echo ""
echo "=== Test Summary ==="
echo ""
echo "The enhanced error system provides:"
echo "✓ Detailed error context for all tools"
echo "✓ Suggestions for fixing common mistakes"
echo "✓ Available alternatives when items aren't found"
echo "✓ Current vs required state information"
echo "✓ Examples of correct usage"
echo ""

# Run a live demo if requested
if [ "$1" == "--demo" ]; then
    echo -e "${GREEN}Running live demo...${NC}"
    echo ""
    
    # Demo 1: Shell error
    echo "Demo 1: Shell command error with details"
    ./scripts/peekaboo-wait.sh agent "Run shell command 'fake-command --version'" || true
    echo ""
    sleep 2
    
    # Demo 2: App fuzzy match
    echo "Demo 2: App name fuzzy matching"
    ./scripts/peekaboo-wait.sh agent "Launch app 'Safary'" || true
    echo ""
    sleep 2
    
    # Demo 3: Click without session
    echo "Demo 3: Click without capturing screen first"
    ./scripts/peekaboo-wait.sh agent "Click on 'Submit'" || true
    echo ""
    sleep 2
    
    # Demo 4: Invalid hotkey
    echo "Demo 4: Invalid hotkey format"
    ./scripts/peekaboo-wait.sh agent "Press hotkey 'cmd+c'" || true
    echo ""
fi

echo -e "${GREEN}Testing complete!${NC}"