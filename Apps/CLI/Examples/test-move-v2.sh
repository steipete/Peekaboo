#!/bin/bash

# Test script for MoveCommandV2
# Demonstrates various mouse movement capabilities

echo "=== Testing MoveCommandV2 ==="
echo

# Build the CLI first
echo "Building CLI..."
cd "$(dirname "$0")/.." && swift build
PEEKABOO="$(pwd)/.build/debug/peekaboo"

echo
echo "1. Move to specific coordinates (instant)"
"$PEEKABOO" move-v2 500,300
sleep 1

echo
echo "2. Move to screen center"
"$PEEKABOO" move-v2 --center
sleep 1

echo
echo "3. Smooth movement to coordinates"
"$PEEKABOO" move-v2 800,400 --smooth
sleep 1

echo
echo "4. Move with custom duration and steps"
"$PEEKABOO" move-v2 200,200 --smooth --duration 2000 --steps 50
sleep 2

echo
echo "5. JSON output mode"
"$PEEKABOO" move-v2 600,300 --json-output | jq .

echo
echo "6. Move to element (requires active see session)"
echo "First, capture elements:"
SESSION=$("$PEEKABOO" see-v2 --json-output | jq -r .sessionId)
if [ ! -z "$SESSION" ]; then
    echo "Session: $SESSION"
    echo "Moving to first button found..."
    "$PEEKABOO" move-v2 --id B1 --session "$SESSION"
fi

echo
echo "✅ MoveCommandV2 test complete!"