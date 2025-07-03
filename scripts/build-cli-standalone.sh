#!/bin/bash

# Build the Peekaboo Swift CLI as a standalone binary
# This script builds the CLI independently of the Node.js MCP server

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building Peekaboo Swift CLI...${NC}"

# Change to the CLI directory
cd "$(dirname "$0")/../peekaboo-cli"

# Build for release with optimizations
echo -e "${BLUE}Building release version...${NC}"
swift build -c release

# Get the build output path
BUILD_PATH=".build/release/peekaboo"

if [ -f "$BUILD_PATH" ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${BLUE}Binary location: $(pwd)/$BUILD_PATH${NC}"
    
    # Show binary info
    echo -e "\n${BLUE}Binary info:${NC}"
    file "$BUILD_PATH"
    echo "Size: $(du -h "$BUILD_PATH" | cut -f1)"
    
    # Optionally copy to a more convenient location
    if [ "$1" == "--install" ]; then
        echo -e "\n${BLUE}Installing to /usr/local/bin...${NC}"
        sudo cp "$BUILD_PATH" /usr/local/bin/peekaboo
        echo -e "${GREEN}✅ Installed to /usr/local/bin/peekaboo${NC}"
    else
        echo -e "\n${BLUE}To install system-wide, run:${NC}"
        echo "  $0 --install"
        echo -e "\n${BLUE}Or copy manually:${NC}"
        echo "  sudo cp $BUILD_PATH /usr/local/bin/peekaboo"
    fi
    
    echo -e "\n${BLUE}To see usage:${NC}"
    echo "  $BUILD_PATH --help"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi