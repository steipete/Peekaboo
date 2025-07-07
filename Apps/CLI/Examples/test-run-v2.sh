#!/bin/bash
# Test script for RunCommandV2

echo "Testing RunCommandV2..."

# Test basic script execution
echo "1. Basic script execution:"
peekaboo run-v2 Examples/test-script.peekaboo.json --verbose

# Test with JSON output
echo -e "\n2. JSON output:"
peekaboo run-v2 Examples/test-script.peekaboo.json --json-output --output results.json

# Test with no-fail-fast mode
echo -e "\n3. No fail-fast mode:"
peekaboo run-v2 Examples/test-script.peekaboo.json --no-fail-fast

# Show results
if [ -f results.json ]; then
    echo -e "\n4. Script results:"
    cat results.json
fi

echo -e "\nAll tests completed!"