#!/bin/bash

echo "Testing o3 model API fix..."
echo ""

# Test a simple command with o3
./scripts/peekaboo-wait.sh agent "What is 2 + 2?" --model o3

echo ""
echo "If you see a response instead of an API error, the fix worked!"