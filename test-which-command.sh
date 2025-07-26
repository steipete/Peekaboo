#!/bin/bash

# Test script to verify 'which' command error output

echo "=== Testing 'which' command error output ==="
echo ""

# Test 1: Command that exists
echo "Test 1: which ls (should succeed)"
./scripts/peekaboo-wait.sh agent "Run shell command 'which ls'"
echo ""
echo "---"
echo ""

# Test 2: Command that doesn't exist
echo "Test 2: which pandoc (should show 'pandoc not found')"
./scripts/peekaboo-wait.sh agent "Run shell command 'which pandoc'"
echo ""
echo "---"
echo ""

# Test 3: Another non-existent command
echo "Test 3: which nonexistentcommand"
./scripts/peekaboo-wait.sh agent "Run shell command 'which nonexistentcommand'"
echo ""
echo "---"
echo ""

# Test 4: type command (bash builtin alternative to which)
echo "Test 4: type pandoc (alternative to which)"
./scripts/peekaboo-wait.sh agent "Run shell command 'type pandoc'"
echo ""

echo "=== Test Complete ==="
echo ""
echo "The error output should now show:"
echo "- 'pandoc not found' for which pandoc"
echo "- 'bash: type: pandoc: not found' for type pandoc"
echo "- Exit code information"