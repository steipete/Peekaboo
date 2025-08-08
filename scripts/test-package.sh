#!/bin/bash

# Simple package test script for Peekaboo MCP
# Tests the package locally without publishing

set -e

echo "🧪 Testing npm package locally..."
echo ""

# Build everything
echo "🔨 Building package..."
npm run build:swift:all

# Create package
echo "📦 Creating package tarball..."
PACKAGE_FILE=$(npm pack | tail -n 1)
PACKAGE_PATH=$(pwd)/$PACKAGE_FILE
echo "Created: $PACKAGE_FILE"

# Get package info
PACKAGE_SIZE=$(du -h "$PACKAGE_FILE" | cut -f1)
echo "Package size: $PACKAGE_SIZE"

# Test installation in a temporary directory
TEMP_DIR=$(mktemp -d)
echo ""
echo "📥 Testing installation in: $TEMP_DIR"
cd "$TEMP_DIR"

# Initialize a test project
npm init -y > /dev/null 2>&1

# Install the package from tarball
echo "📦 Installing from tarball..."
npm install "$PACKAGE_PATH"

# Check installation
echo ""
echo "🔍 Checking installation..."

# Check if binary exists and is executable
if [ -f "node_modules/peekaboo/peekaboo" ]; then
    echo "✅ Binary found"
    
    # Check if executable
    if [ -x "node_modules/peekaboo/peekaboo" ]; then
        echo "✅ Binary is executable"
        
        # Test the binary
        echo ""
        echo "🧪 Testing Swift CLI..."
        if node_modules/peekaboo/peekaboo --version; then
            echo "✅ Swift CLI works!"
        else
            echo "❌ Swift CLI failed"
        fi
    else
        echo "❌ Binary is not executable"
    fi
else
    echo "❌ Binary not found!"
fi



# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"
rm -f "$PACKAGE_PATH"

echo ""
echo "✨ Package test complete!"
echo ""
echo "If all tests passed, the package is ready for publishing!"