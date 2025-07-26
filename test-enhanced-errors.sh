#!/bin/bash

# Test script to demonstrate enhanced error messages in Peekaboo agent

echo "=== Enhanced Error Message Testing ==="
echo ""

# Test 1: Shell command errors (already working)
echo "Test 1: Shell command with detailed error output"
./scripts/peekaboo-wait.sh agent "Run shell command 'ls /nonexistent/directory'"
echo ""
echo "---"
echo ""

# Test 2: App not found with fuzzy matching
echo "Test 2: Launch app with typo (fuzzy matching)"
./scripts/peekaboo-wait.sh agent "Launch app 'Safary'"
echo ""
echo "---"
echo ""

# Test 3: Click element not found with suggestions
echo "Test 3: Click non-existent button with suggestions"
./scripts/peekaboo-wait.sh agent "Take a screenshot, then click on 'Submit'"
echo ""
echo "---"
echo ""

# Test 4: Window operations with detailed state
echo "Test 4: Focus window for non-existent app"
./scripts/peekaboo-wait.sh agent "Focus window for 'NotARealApp'"
echo ""
echo "---"
echo ""

# Test 5: Type without focused field
echo "Test 5: Type text without focused field"
./scripts/peekaboo-wait.sh agent "Type 'Hello World'"
echo ""
echo "---"
echo ""

# Test 6: Invalid hotkey format
echo "Test 6: Invalid hotkey format"
./scripts/peekaboo-wait.sh agent "Press hotkey 'cmd+shift+a'"
echo ""
echo "---"
echo ""

# Test 7: Menu item not found
echo "Test 7: Menu item not found"
./scripts/peekaboo-wait.sh agent "Click menu item 'File > NonExistent'"
echo ""
echo "---"
echo ""

# Test 8: Permission denied (if not granted)
echo "Test 8: Permission diagnostics"
./scripts/peekaboo-wait.sh agent "Take a screenshot of the screen"
echo ""

echo "=== Testing Complete ==="
echo "The enhanced error messages provide:"
echo "- Available alternatives when items aren't found"
echo "- Current vs required state information"
echo "- Specific fix instructions"
echo "- Examples of correct usage"
echo "- Context-aware suggestions"