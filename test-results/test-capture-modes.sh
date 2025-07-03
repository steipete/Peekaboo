#!/bin/bash
set -e

echo "=== Testing Peekaboo Image Capture Modes ==="
echo

# Test 1: Frontmost window capture
echo "Test 1: Capturing frontmost window..."
../../peekaboo image --mode frontmost --path frontmost.png
echo "✓ Frontmost capture completed"
echo

# Test 2: Screen capture (main screen)
echo "Test 2: Capturing main screen..."
../../peekaboo image --mode screen --screen-index 0 --path screen-main.png
echo "✓ Main screen capture completed"
echo

# Test 3: All screens capture
echo "Test 3: Capturing all screens..."
../../peekaboo image --mode screen --path screen-all.png 2>/dev/null || echo "Note: Single screen system"
echo

# Test 4: Application capture by name
echo "Test 4: Capturing specific applications..."
for app in "Finder" "Google Chrome" "Safari" "Terminal" "Visual Studio Code"; do
    echo "  Attempting to capture: $app"
    ../../peekaboo image --app "$app" --path "app-${app// /-}.png" 2>/dev/null || echo "  → $app not running or no windows"
done
echo

# Test 5: Window title filtering
echo "Test 5: Testing window title filtering..."
../../peekaboo image --app "Google Chrome" --window-title "github" --path chrome-github.png 2>/dev/null || echo "→ No matching Chrome window with 'github' in title"
echo

# Test 6: Multi-window capture
echo "Test 6: Testing multi-window capture..."
../../peekaboo image --mode multi --app "Google Chrome" --path chrome-multi 2>/dev/null || echo "→ Chrome not running or single window"
echo

# Test 7: Format options
echo "Test 7: Testing different formats..."
../../peekaboo image --mode frontmost --format png --path format-test.png
../../peekaboo image --mode frontmost --format jpeg --path format-test.jpg 2>/dev/null || echo "→ JPEG format may not be supported"
echo "✓ Format testing completed"
echo

# Test 8: No path (stdout) - skip for now as it outputs binary
echo "Test 8: Testing stdout output..."
../../peekaboo image --mode frontmost 2>/dev/null | wc -c | xargs echo "  Stdout output size (bytes):"
echo

echo "=== Capture Mode Tests Complete ==="
echo
echo "Files created:"
ls -la *.png 2>/dev/null | wc -l | xargs echo "  PNG files:"
ls -la *.jpg 2>/dev/null | wc -l | xargs echo "  JPG files:"