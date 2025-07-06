#!/bin/bash

# Comprehensive Click Feature Tests for TextEdit
# Tests various aspects of the click command functionality

set -e  # Exit on error

echo "=== Peekaboo Click Feature Comprehensive Test Suite ==="
echo "Testing with TextEdit application"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
PASSED=0
FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_result="$3"  # "pass" or "fail"
    
    echo -n "Testing: $test_name... "
    
    if [ "$expected_result" = "pass" ]; then
        if eval "$command" > /dev/null 2>&1; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
        else
            echo -e "${RED}FAILED${NC}"
            echo "  Command: $command"
            ((FAILED++))
        fi
    else
        if eval "$command" > /dev/null 2>&1; then
            echo -e "${RED}FAILED${NC} (expected to fail but passed)"
            ((FAILED++))
        else
            echo -e "${GREEN}PASSED${NC} (correctly failed)"
            ((PASSED++))
        fi
    fi
}

# Ensure TextEdit is running and create a new document
echo "Setting up TextEdit..."
osascript -e 'tell application "TextEdit" to activate' > /dev/null
sleep 1
osascript -e 'tell application "System Events" to keystroke "n" using command down' > /dev/null
sleep 1

# Create initial session
echo "Creating initial session..."
./peekaboo see --app TextEdit --annotate --json-output > /tmp/textedit-session.json
SESSION_ID=$(cat /tmp/textedit-session.json | jq -r '.data.session_id')
echo "Session ID: $SESSION_ID"
echo ""

# Test 1: Basic element clicking by ID
echo "=== Test Group 1: Basic Element Clicking ==="

# Get the window title to construct proper element IDs
WINDOW_TITLE=$(cat /tmp/textedit-session.json | jq -r '.data.window_title' | tr ' ' '_')

run_test "Click on text area by ID" \
    "./peekaboo click --on ${WINDOW_TITLE}_T1 --json-output" \
    "pass"

run_test "Click on bold checkbox" \
    "./peekaboo click --on ${WINDOW_TITLE}_C1 --json-output" \
    "pass"

run_test "Click on italic checkbox" \
    "./peekaboo click --on ${WINDOW_TITLE}_C2 --json-output" \
    "pass"

run_test "Click on underline checkbox" \
    "./peekaboo click --on ${WINDOW_TITLE}_C3 --json-output" \
    "pass"

echo ""

# Test 2: Text-based clicking
echo "=== Test Group 2: Text-Based Element Clicking ==="

# Type some text first
./peekaboo type "Testing text-based clicking" --json-output > /dev/null

run_test "Click element by partial text 'Bold'" \
    "./peekaboo click 'Bold' --json-output"

run_test "Click element by role text 'checkbox'" \
    "./peekaboo click 'checkbox' --json-output"

# Test clicking on font dropdown
run_test "Click on font dropdown" \
    "./peekaboo click 'Helvetica' --json-output"

# Press escape to close dropdown
./peekaboo hotkey --keys "escape" --json-output > /dev/null
sleep 0.5

echo ""

# Test 3: Coordinate-based clicking
echo "=== Test Group 3: Coordinate-Based Clicking ==="

# Get window bounds for relative coordinates
WINDOW_BOUNDS=$(cat /tmp/textedit-session.json | jq -r '.data.window_bounds')

run_test "Click at specific coordinates (300,400)" \
    "./peekaboo click --coords '300,400' --json-output"

run_test "Click at text area center using coordinates" \
    "./peekaboo click --coords '479,608' --json-output"

echo ""

# Test 4: Double-click functionality
echo "=== Test Group 4: Double-Click Tests ==="

# Type a word to double-click
./peekaboo type " DoubleClickMe" --json-output > /dev/null

run_test "Double-click on text area" \
    "./peekaboo click --on ${WINDOW_TITLE}_T1 --double --json-output" \
    "pass"

# The word should be selected after double-click
# Verify by typing to replace it
./peekaboo type "Selected" --json-output > /dev/null

echo ""

# Test 5: Right-click functionality
echo "=== Test Group 5: Right-Click Tests ==="

run_test "Right-click on text area" \
    "./peekaboo click --on ${WINDOW_TITLE}_T1 --right --json-output" \
    "pass"

# Press escape to close context menu
./peekaboo hotkey --keys "escape" --json-output > /dev/null

run_test "Right-click at coordinates" \
    "./peekaboo click --coords '400,500' --right --json-output"

# Press escape to close context menu
./peekaboo hotkey --keys "escape" --json-output > /dev/null

echo ""

# Test 6: Click with wait-for element
echo "=== Test Group 6: Click with Wait-For Element ==="

# Click on Format menu
./peekaboo hotkey --keys "ctrl,f2" --json-output > /dev/null
sleep 0.5
./peekaboo type "Format" --json-output > /dev/null
./peekaboo hotkey --keys "enter" --json-output > /dev/null
sleep 0.5

run_test "Click with wait-for menu item" \
    "./peekaboo click 'Font' --wait-for 'Show Fonts' --json-output"

# Close menu
./peekaboo hotkey --keys "escape" --json-output > /dev/null

echo ""

# Test 7: Clicking on different UI elements
echo "=== Test Group 7: Various UI Element Types ==="

# Refresh session to get latest element IDs
./peekaboo see --app TextEdit --json-output > /tmp/textedit-session2.json

# Click on different types of elements
run_test "Click on button (close button)" \
    "./peekaboo click --on ${WINDOW_TITLE}_B2 --json-output" \
    "pass"

# Cancel the close dialog if it appears
sleep 0.5
./peekaboo hotkey --keys "escape" --json-output > /dev/null

run_test "Click on popup button (font dropdown)" \
    "./peekaboo click --on ${WINDOW_TITLE}_G24 --json-output" \
    "pass"

# Close dropdown
./peekaboo hotkey --keys "escape" --json-output > /dev/null

run_test "Click on static text element" \
    "./peekaboo click --on ${WINDOW_TITLE}_G22 --json-output" \
    "pass"

echo ""

# Test 8: Error cases
echo "=== Test Group 8: Error Cases ==="

run_test "Click on non-existent element" \
    "./peekaboo click --on NONEXISTENT --json-output" \
    "fail"

run_test "Click with invalid coordinates" \
    "./peekaboo click --coords 'invalid,coords' --json-output" \
    "fail"

run_test "Click without target (no --on or --coords)" \
    "./peekaboo click --json-output" \
    "fail"

echo ""

# Test 9: Rapid clicking
echo "=== Test Group 9: Rapid Sequential Clicks ==="

run_test "Rapid clicks on checkboxes" \
    "for i in C1 C2 C3 C4; do ./peekaboo click --on ${WINDOW_TITLE}_\$i --json-output; done" \
    "pass"

echo ""

# Test 10: Click after UI state change
echo "=== Test Group 10: Click After UI State Changes ==="

# Change font size to modify UI
./peekaboo click --on ${WINDOW_TITLE}_G26 --json-output > /dev/null 2>&1 || true
./peekaboo type "18" --json-output > /dev/null
./peekaboo hotkey --keys "enter" --json-output > /dev/null

# Try clicking after UI change
run_test "Click on bold after font size change" \
    "./peekaboo click --on ${WINDOW_TITLE}_C1 --json-output" \
    "pass"

echo ""

# Test 11: Multi-window clicking
echo "=== Test Group 11: Multi-Window Click Tests ==="

# Open a second window
./peekaboo hotkey --keys "cmd,n" --json-output > /dev/null
sleep 1

# Create new session for second window
./peekaboo see --app TextEdit --json-output > /tmp/textedit-session3.json

# Should click on the frontmost (new) window
# Get new window title
NEW_SESSION=$(./peekaboo see --app TextEdit --json-output)
NEW_WINDOW_TITLE=$(echo $NEW_SESSION | jq -r '.data.window_title' | tr ' ' '_')
run_test "Click on element in new window" \
    "./peekaboo click --on ${NEW_WINDOW_TITLE}_T1 --json-output" \
    "pass"

./peekaboo type "Window 2" --json-output > /dev/null

echo ""

# Test 12: Click with session management
echo "=== Test Group 12: Session Management Tests ==="

# Get current session
CURRENT_SESSION=$(./peekaboo see --app TextEdit --json-output | jq -r '.data.session_id')

run_test "Click with explicit session ID" \
    "./peekaboo click --on ${WINDOW_TITLE}_T1 --session $CURRENT_SESSION --json-output" \
    "pass"

run_test "Click with old session ID" \
    "./peekaboo click --on ${WINDOW_TITLE}_T1 --session 99999 --json-output" \
    "fail"

echo ""

# Summary
echo "========================================"
echo "Test Summary:"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "========================================"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi