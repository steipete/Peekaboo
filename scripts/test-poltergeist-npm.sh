#!/bin/bash

# Script to test Poltergeist as if it were installed from npm
# This simulates the final experience before publishing

echo "🧪 Testing Poltergeist npm package simulation..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test each command
echo -e "${BLUE}Testing poltergeist:status...${NC}"
npm run poltergeist:status
echo ""

echo -e "${BLUE}Testing poltergeist:haunt (starting in background)...${NC}"
npm run poltergeist:haunt &
HAUNT_PID=$!
sleep 3

echo -e "${BLUE}Testing poltergeist:status (should show running)...${NC}"
npm run poltergeist:status
echo ""

echo -e "${BLUE}Testing poltergeist:stop...${NC}"
npm run poltergeist:stop
echo ""

echo -e "${BLUE}Testing poltergeist:status (should show stopped)...${NC}"
npm run poltergeist:status
echo ""

echo -e "${GREEN}✅ All tests completed!${NC}"
echo ""
echo "To switch to the real npm package after publishing:"
echo '  "poltergeist:start": "npx @steipete/poltergeist@latest start"'
echo ""
echo "Current setup uses local path which is perfect for testing!"