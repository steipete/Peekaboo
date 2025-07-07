#!/bin/bash

echo "=== Testing Peekaboo Agent with Calculator Tasks ==="
echo

# Test 1: Simple addition
echo "Test 1: Simple addition (7 + 3)"
echo "================================"
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 60 ./peekaboo agent "Clear the calculator and calculate 7 + 3" --model gpt-4o
echo
echo "Press Enter to continue..."
read

# Test 2: Using keyboard shortcuts
echo "Test 2: Using keyboard shortcuts"
echo "================================"
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 60 ./peekaboo agent "Use keyboard shortcuts to type 15 * 4 and press enter to calculate" --model gpt-4o
echo
echo "Press Enter to continue..."
read

# Test 3: Complex calculation
echo "Test 3: Complex calculation"
echo "==========================="
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 60 ./peekaboo agent "Calculate (100 - 25) / 5. First calculate 100 - 25, then divide the result by 5" --model gpt-4o
echo
echo "Press Enter to continue..."
read

# Test 4: Using memory functions
echo "Test 4: Clear and percentage"
echo "============================"
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 60 ./peekaboo agent "Clear the calculator, then calculate 20% of 150" --model gpt-4o
echo
echo "Press Enter to continue..."
read

# Test 5: Error handling
echo "Test 5: Division by zero"
echo "========================"
OPENAI_API_KEY="${OPENAI_API_KEY}" timeout 60 ./peekaboo agent "Try to divide 10 by 0 and tell me what happens" --model gpt-4o
echo

echo "=== All tests completed ==="