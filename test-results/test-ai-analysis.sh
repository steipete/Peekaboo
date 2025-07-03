#!/bin/bash

echo "=== Testing Peekaboo AI Analysis ==="
echo

# Capture a test screenshot first
echo "Capturing test screenshot..."
../peekaboo image --mode frontmost --path ai-test.png
echo

# Test 1: Ollama analysis
echo "Test 1: Testing Ollama analysis..."
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "  Ollama is running, testing with llava..."
    PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ../peekaboo analyze ai-test.png "What application is shown in this screenshot?"
    echo
    
    # Test JSON output
    echo "  Testing JSON output:"
    PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ../peekaboo analyze ai-test.png "Describe this image" --json-output | jq -r '.data.analysis' | head -3
else
    echo "  Ollama not running, skipping..."
fi
echo

# Test 2: OpenAI analysis (if API key is set)
echo "Test 2: Testing OpenAI analysis..."
if [ -n "$OPENAI_API_KEY" ]; then
    echo "  OpenAI API key found, testing..."
    PEEKABOO_AI_PROVIDERS="openai/gpt-4o" ../peekaboo analyze ai-test.png "What is visible in this screenshot?" | head -5
else
    echo "  OpenAI API key not set, skipping..."
fi
echo

# Test 3: Provider fallback
echo "Test 3: Testing provider fallback..."
echo "  Setting invalid provider first, should fall back to Ollama..."
PEEKABOO_AI_PROVIDERS="invalid/provider,ollama/llava:latest" ../peekaboo analyze ai-test.png "What do you see?" 2>&1 | grep -E "(Analyzed|Error)" | head -3
echo

# Test 4: Multiple prompts
echo "Test 4: Testing detailed analysis..."
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ../peekaboo analyze ai-test.png "Please describe: 1) The application shown, 2) The window title if visible, 3) The overall UI layout"
echo

# Test 5: Performance timing
echo "Test 5: Testing analysis performance..."
echo -n "  Analysis time: "
time_output=$(PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ../peekaboo analyze ai-test.png "Quick description" 2>&1)
echo "$time_output" | grep -E "Analyzed.*in [0-9.]+s"
echo

# Test 6: Invalid image file
echo "Test 6: Testing invalid image analysis..."
echo "test content" > invalid.txt
../peekaboo analyze invalid.txt "What is this?" 2>&1 | grep -E "(Error|Invalid|format)"
rm invalid.txt
echo

# Test 7: Large prompt
echo "Test 7: Testing large prompt..."
LARGE_PROMPT="Please analyze this screenshot in detail. Look for the following elements: application name, window title, UI components, color scheme, layout structure, visible text, buttons, menus, toolbars, status bars, and any other relevant interface elements. Also describe the overall purpose of the application based on what you can see."
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ../peekaboo analyze ai-test.png "$LARGE_PROMPT" 2>&1 | head -10
echo

# Cleanup
rm -f ai-test.png

echo "=== AI Analysis Tests Complete ==="