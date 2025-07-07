#!/bin/bash

echo "=== AXorcist Test Runner ==="
echo "Killing any existing SwiftPM processes..."

# Kill any existing swift processes
pkill -f "swift" || true
pkill -f "SourceKitService" || true

echo "Starting swift test (without git clean to preserve dependencies)..."
swift test