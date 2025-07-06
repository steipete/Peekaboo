#!/bin/bash
# Manual test script for Peekaboo v3 features

echo "=== Peekaboo v3 Manual Test Suite ==="
echo "This script tests key v3 features"
echo ""

# Build the CLI
echo "1. Building Peekaboo CLI..."
npm run build:swift

PEEKABOO="./peekaboo-cli/.build/debug/peekaboo"

# Test 1: Version check
echo ""
echo "2. Testing version (should show 3.0.0-beta.1)..."
$PEEKABOO --version

# Test 2: Session management with PID
echo ""
echo "3. Testing PID-based session management..."
echo "   Current PID: $$"
$PEEKABOO see --app "Finder" --json-output | jq -r '.sessionId'

# Test 3: Annotated screenshots
echo ""
echo "4. Testing annotated screenshot generation..."
SESSION_ID=$($PEEKABOO see --app "Finder" --annotate --json-output | jq -r '.sessionId')
echo "   Session ID: $SESSION_ID"
echo "   Checking for annotated.png..."
ls -la ~/.peekaboo/session/$SESSION_ID/annotated.png 2>/dev/null && echo "   ✅ Annotated screenshot created" || echo "   ❌ Annotated screenshot missing"

# Test 4: UI Element discovery
echo ""
echo "5. Testing UI element discovery..."
$PEEKABOO see --app "Finder" --json-output | jq '.elements | length' | xargs -I {} echo "   Found {} UI elements"

# Test 5: Clean command
echo ""
echo "6. Testing clean command..."
$PEEKABOO clean --all
echo "   Sessions cleaned"

# Test 6: Sleep command
echo ""
echo "7. Testing sleep command..."
time $PEEKABOO sleep 1000
echo "   Sleep completed"

# Test 7: Run command with script
echo ""
echo "8. Creating and testing run command..."
cat > /tmp/test-script.json << 'EOF'
{
  "description": "Test v3 automation script",
  "steps": [
    {
      "stepId": "capture",
      "command": "see",
      "params": {
        "app": "Finder"
      }
    },
    {
      "stepId": "wait",
      "command": "sleep",
      "params": {
        "duration": "500"
      }
    }
  ]
}
EOF

$PEEKABOO run /tmp/test-script.json --json-output | jq -r '.success'

echo ""
echo "=== Manual Test Complete ==="
echo ""
echo "Additional manual tests to perform:"
echo "1. Test click command: $PEEKABOO click 'Close' --wait-for 3000"
echo "2. Test type command: $PEEKABOO type 'Hello World' --return"
echo "3. Test scroll command: $PEEKABOO scroll --direction down --amount 100"
echo "4. Test swipe command: $PEEKABOO swipe --from-coords 100,100 --to-coords 300,300"
echo "5. Test hotkey command: $PEEKABOO hotkey cmd,space"