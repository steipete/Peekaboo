#!/bin/bash
set -e

echo "Building Swift CLI..."

# Change to swift-cli directory
cd "$(dirname "$0")/../swift-cli"

# Build the Swift CLI in release mode
swift build --configuration release

# Copy the binary to the root directory
cp .build/release/peekaboo ../peekaboo

# Make it executable
chmod +x ../peekaboo

echo "Swift CLI built successfully and copied to ./peekaboo"