#!/bin/bash

# Peekaboo GUI Test Runner
# This script runs the Swift Testing tests with various configurations

set -e

echo "🧪 Peekaboo GUI Test Runner"
echo "=========================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}Error: Package.swift not found. Please run from the Peekaboo GUI directory.${NC}"
    exit 1
fi

# Parse command line arguments
RUN_MODE="all"
if [ "$1" = "unit" ]; then
    RUN_MODE="unit"
elif [ "$1" = "integration" ]; then
    RUN_MODE="integration"
elif [ "$1" = "fast" ]; then
    RUN_MODE="fast"
elif [ "$1" = "help" ]; then
    echo "Usage: $0 [unit|integration|fast|all]"
    echo ""
    echo "Options:"
    echo "  unit         Run only unit tests"
    echo "  integration  Run only integration tests"
    echo "  fast         Run only fast tests"
    echo "  all          Run all tests (default)"
    exit 0
fi

# Run tests based on mode
case $RUN_MODE in
    unit)
        echo -e "${YELLOW}Running unit tests...${NC}"
        swift test --filter .unit
        ;;
    integration)
        echo -e "${YELLOW}Running integration tests...${NC}"
        swift test --filter .integration
        ;;
    fast)
        echo -e "${YELLOW}Running fast tests...${NC}"
        swift test --filter .fast
        ;;
    all)
        echo -e "${YELLOW}Running all tests...${NC}"
        swift test
        ;;
esac

# Check test results
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Some tests failed.${NC}"
    exit 1
fi

# Optional: Generate coverage report (requires additional tools)
if command -v xcrun &> /dev/null && [ "$GENERATE_COVERAGE" = "1" ]; then
    echo -e "${YELLOW}Generating coverage report...${NC}"
    swift test --enable-code-coverage
    xcrun llvm-cov report \
        .build/debug/PeekabooPackageTests.xctest/Contents/MacOS/PeekabooPackageTests \
        -instr-profile=.build/debug/codecov/default.profdata \
        -ignore-filename-regex=".build|Tests"
fi