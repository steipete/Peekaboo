#!/bin/bash

# Script to run local-only tests with the test host app

echo "🧪 Running Peekaboo Local Tests"
echo "================================"
echo ""
echo "These tests require:"
echo "  - Screen Recording permission"
echo "  - Accessibility permission (optional)"
echo "  - User interaction may be required"
echo ""

# Set environment variable to enable local tests
export RUN_LOCAL_TESTS=true

# Build the test host first
echo "📦 Building test host app..."
cd TestHost
swift build -c debug
if [ $? -ne 0 ]; then
    echo "❌ Failed to build test host"
    exit 1
fi
cd ..

echo "✅ Test host built successfully"
echo ""

# Run tests with local-only tag
echo "🏃 Running local-only tests..."
swift test --filter "localOnly"

# Also run screenshot tests
echo ""
echo "📸 Running screenshot tests..."
swift test --filter "screenshot"

# Run permission tests
echo ""
echo "🔐 Running permission tests..."
swift test --filter "permissions"

echo ""
echo "✨ Local tests completed!"
echo ""
echo "Note: If any tests failed due to permissions, please grant the required permissions and run again."