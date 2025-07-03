#!/bin/bash

echo "=== Testing Peekaboo Performance & Output Formats ==="
echo

# Test 1: Measure capture performance
echo "Test 1: Screenshot capture performance..."
echo "  Single window capture times (5 runs):"
for i in {1..5}; do
    start=$(date +%s.%N)
    ../peekaboo image --mode frontmost --path perf-test-$i.png >/dev/null 2>&1
    end=$(date +%s.%N)
    runtime=$(echo "$end - $start" | bc)
    echo "    Run $i: ${runtime}s"
    rm -f perf-test-$i.png
done
echo

# Test 2: Multi-window capture performance
echo "Test 2: Multi-window capture performance..."
start=$(date +%s.%N)
../peekaboo image --mode multi --app "Google Chrome" --path perf-multi >/dev/null 2>&1
end=$(date +%s.%N)
runtime=$(echo "$end - $start" | bc)
echo "  Multi-window capture time: ${runtime}s"
rm -rf perf-multi
echo

# Test 3: Large screen capture
echo "Test 3: Full screen capture performance..."
start=$(date +%s.%N)
../peekaboo image --mode screen --path screen-perf.png >/dev/null 2>&1
end=$(date +%s.%N)
runtime=$(echo "$end - $start" | bc)
file_size=$(ls -lh screen-perf.png 2>/dev/null | awk '{print $5}')
echo "  Screen capture time: ${runtime}s"
echo "  File size: ${file_size}"
rm -f screen-perf.png
echo

# Test 4: JSON output performance
echo "Test 4: JSON output performance for listings..."
echo "  Apps list:"
start=$(date +%s.%N)
../peekaboo list apps --json-output >/dev/null 2>&1
end=$(date +%s.%N)
runtime=$(echo "$end - $start" | bc)
echo "    Time: ${runtime}s"

echo "  Windows list:"
start=$(date +%s.%N)
../peekaboo list windows --app "Finder" --json-output >/dev/null 2>&1
end=$(date +%s.%N)
runtime=$(echo "$end - $start" | bc)
echo "    Time: ${runtime}s"
echo

# Test 5: Different output formats
echo "Test 5: Testing output formats..."
echo "  Regular output (apps):"
../peekaboo list apps 2>&1 | head -3
echo
echo "  JSON output (apps):"
../peekaboo list apps --json-output 2>&1 | jq -r '.success'
echo
echo "  Regular output (windows):"
../peekaboo list windows --app "Finder" 2>&1 | head -3
echo
echo "  JSON output (windows):"
../peekaboo list windows --app "Finder" --json-output 2>&1 | jq -r '.data.windows | length' | xargs echo "    Window count:"
echo

# Test 6: Concurrent operations
echo "Test 6: Testing concurrent operations..."
echo "  Launching 3 concurrent captures..."
(
    ../peekaboo image --mode frontmost --path concurrent-1.png &
    ../peekaboo image --mode frontmost --path concurrent-2.png &
    ../peekaboo image --mode frontmost --path concurrent-3.png &
    wait
) 2>/dev/null
ls -la concurrent-*.png 2>/dev/null | wc -l | xargs echo "  Successfully captured:"
rm -f concurrent-*.png
echo

# Test 7: Memory usage (rough estimate)
echo "Test 7: Resource usage check..."
echo "  Binary size: $(ls -lh ../peekaboo | awk '{print $5}')"
echo "  Architecture: $(file ../peekaboo | cut -d: -f2)"
echo

echo "=== Performance Tests Complete ==="