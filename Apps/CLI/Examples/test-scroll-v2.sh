#!/bin/bash
# Test script for ScrollCommandV2

echo "Testing ScrollCommandV2..."

# Test basic scroll down
echo "1. Basic scroll down:"
peekaboo scroll-v2 --direction down --amount 5

# Test scroll with element target
echo -e "\n2. Scroll on specific element:"
peekaboo scroll-v2 --direction up --amount 3 --on element_42

# Test smooth scrolling
echo -e "\n3. Smooth scrolling:"
peekaboo scroll-v2 --direction right --amount 2 --smooth

# Test with custom delay
echo -e "\n4. Custom delay between ticks:"
peekaboo scroll-v2 --direction left --amount 4 --delay 50

# Test JSON output
echo -e "\n5. JSON output:"
peekaboo scroll-v2 --direction down --amount 1 --json-output

echo -e "\nAll tests completed!"