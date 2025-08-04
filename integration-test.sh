#!/bin/bash

# Comprehensive Integration Testing Script for Peekaboo AI Providers
# Tests OpenAI, Anthropic, Grok, and Ollama integrations

set -e

echo "🧪 Starting Comprehensive Integration Testing"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
PASSED=0
FAILED=0
SKIPPED=0

# Function to print test status
print_test_result() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓ PASS${NC} - $test_name"
            ((PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗ FAIL${NC} - $test_name"
            if [[ -n "$details" ]]; then
                echo -e "  ${RED}Error: $details${NC}"
            fi
            ((FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}⊘ SKIP${NC} - $test_name - $details"
            ((SKIPPED++))
            ;;
    esac
}

# Function to test basic text generation
test_text_generation() {
    local provider="$1"
    local model="$2"
    local test_name="Text Generation: $provider/$model"
    
    echo -e "\n${BLUE}Testing:${NC} $test_name"
    
    # Simple test prompt
    local prompt="What is 2+2? Answer with just the number."
    
    if timeout 60 ./scripts/peekaboo-wait.sh agent --model "$model" "$prompt" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Text generation failed or timed out"
    fi
}

# Function to test tool calling
test_tool_calling() {
    local provider="$1"
    local model="$2"
    local test_name="Tool Calling: $provider/$model"
    
    echo -e "\n${BLUE}Testing:${NC} $test_name"
    
    # Tool calling test - ask for screenshot
    local prompt="Take a screenshot of the current desktop and tell me what you see"
    
    if timeout 120 ./scripts/peekaboo-wait.sh agent --model "$model" "$prompt" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Tool calling failed or timed out"
    fi
}

# Function to test streaming
test_streaming() {
    local provider="$1"
    local model="$2"
    local test_name="Streaming: $provider/$model"
    
    echo -e "\n${BLUE}Testing:${NC} $test_name"
    
    # Streaming test with verbose output to see streaming
    local prompt="Write a short poem about automation"
    
    if timeout 60 ./scripts/peekaboo-wait.sh agent --model "$model" --verbose "$prompt" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Streaming failed or timed out"
    fi
}

# Function to test a complete provider
test_provider() {
    local provider="$1"
    local model="$2"
    local api_key_var="$3"
    
    echo -e "\n${YELLOW}🔍 Testing Provider: $provider${NC}"
    echo "=================================================="
    
    # Check if API key is available
    if [[ -z "${!api_key_var}" ]]; then
        print_test_result "API Key Check: $provider" "SKIP" "API key not configured ($api_key_var)"
        return
    fi
    
    print_test_result "API Key Check: $provider" "PASS"
    
    # Run tests
    test_text_generation "$provider" "$model"
    test_tool_calling "$provider" "$model"
    test_streaming "$provider" "$model"
}

# Function to test Ollama (special case - no API key needed)
test_ollama() {
    echo -e "\n${YELLOW}🔍 Testing Provider: Ollama${NC}"
    echo "=================================================="
    
    # Check if Ollama is running
    if ! curl -s http://localhost:11434/api/version >/dev/null 2>&1; then
        print_test_result "Ollama Service Check" "SKIP" "Ollama service not running on localhost:11434"
        return
    fi
    
    print_test_result "Ollama Service Check" "PASS"
    
    # Test with llama3.3 (recommended model)
    local model="ollama/llama3.3"
    
    # For Ollama, we need to be more patient due to model loading
    echo -e "\n${BLUE}Testing:${NC} Text Generation: Ollama/llama3.3"
    local prompt="What is 2+2? Answer with just the number."
    
    if timeout 300 ./scripts/peekaboo-wait.sh agent --model "$model" "$prompt" >/dev/null 2>&1; then
        print_test_result "Text Generation: Ollama/llama3.3" "PASS"
    else
        print_test_result "Text Generation: Ollama/llama3.3" "FAIL" "Failed or timed out (model may need to be downloaded)"
    fi
    
    # Test tool calling with longer timeout
    echo -e "\n${BLUE}Testing:${NC} Tool Calling: Ollama/llama3.3"
    local tool_prompt="Take a screenshot and describe what you see"
    
    if timeout 300 ./scripts/peekaboo-wait.sh agent --model "$model" "$tool_prompt" >/dev/null 2>&1; then
        print_test_result "Tool Calling: Ollama/llama3.3" "PASS"
    else
        print_test_result "Tool Calling: Ollama/llama3.3" "FAIL" "Tool calling failed or timed out"
    fi
}

# Main testing sequence
echo -e "\n${BLUE}🏁 Starting Integration Tests${NC}"
echo "Testing Date: $(date)"
echo "Peekaboo Version: $(./scripts/peekaboo-wait.sh --version 2>/dev/null || echo 'Unknown')"

# Test OpenAI
test_provider "OpenAI" "openai/gpt-4o" "OPENAI_API_KEY"

# Test Anthropic  
test_provider "Anthropic" "anthropic/claude-opus-4" "ANTHROPIC_API_KEY"

# Test Grok (xAI)
test_provider "Grok" "grok/grok-4" "X_AI_API_KEY"

# Test Ollama (special case)
test_ollama

# Additional provider tests (if API keys available)
if [[ -n "$GROQ_API_KEY" ]]; then
    test_provider "Groq" "groq/llama-3.1-70b" "GROQ_API_KEY"
fi

if [[ -n "$TOGETHER_API_KEY" ]]; then
    test_provider "Together" "together/meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo" "TOGETHER_API_KEY"
fi

# Print final results
echo -e "\n${BLUE}📊 Test Results Summary${NC}"
echo "==========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"

TOTAL=$((PASSED + FAILED + SKIPPED))
echo "Total Tests: $TOTAL"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All tests passed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed. Check the output above for details.${NC}"
    exit 1
fi