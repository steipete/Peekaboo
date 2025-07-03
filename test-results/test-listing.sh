#!/bin/bash
set -e

echo "=== Testing Peekaboo List Features ==="
echo

# Test 1: List all applications
echo "Test 1: Listing all applications..."
echo "  Regular output:"
../peekaboo list apps | head -10
echo
echo "  JSON output (first 3 apps):"
../peekaboo list apps --json-output | jq '.data.applications[:3]'
echo

# Test 2: List windows for specific app
echo "Test 2: Listing windows for specific applications..."
for app in "Google Chrome" "Finder" "Safari"; do
    echo "  Windows for $app:"
    ../peekaboo list windows --app "$app" 2>/dev/null || echo "    → $app not running"
    echo
done

# Test 3: JSON output for windows
echo "Test 3: Testing JSON output for windows..."
../peekaboo list windows --app "Google Chrome" --json-output 2>/dev/null | jq '.data.windows[:2]' || echo "→ Chrome not running"
echo

# Test 4: Server status
echo "Test 4: Checking server status..."
echo "  Regular output:"
../peekaboo list server_status
echo
echo "  JSON output:"
../peekaboo list server_status --json-output | jq '.'
echo

# Test 5: Search for non-existent app
echo "Test 5: Testing non-existent app..."
../peekaboo list windows --app "NonExistentApp123" 2>&1 || echo "✓ Properly handled non-existent app"
echo

# Test 6: Case sensitivity and fuzzy matching
echo "Test 6: Testing app name matching..."
echo "  Testing 'chrome' (lowercase):"
../peekaboo list windows --app "chrome" 2>/dev/null | head -3 || echo "→ No match"
echo "  Testing 'CHROME' (uppercase):"
../peekaboo list windows --app "CHROME" 2>/dev/null | head -3 || echo "→ No match"
echo "  Testing partial match 'Chro':"
../peekaboo list windows --app "Chro" 2>/dev/null | head -3 || echo "→ No match"
echo

echo "=== List Feature Tests Complete ==="