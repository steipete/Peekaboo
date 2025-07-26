#!/bin/bash

echo "Testing VibeTunnel integration with Peekaboo Agent"
echo "Watch your terminal title bar during execution!"
echo ""

# Test 1: Simple task
echo "Test 1: Simple screenshot task"
./scripts/peekaboo-wait.sh agent "take a screenshot of the current window" --quiet

echo ""
echo "Test 2: Multi-step task with different tools"
./scripts/peekaboo-wait.sh agent "list running applications and then tell me which app is frontmost" --quiet

echo ""
echo "Test completed! The terminal title should have updated during execution."