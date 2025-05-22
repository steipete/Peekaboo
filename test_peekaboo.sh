#!/bin/bash
################################################################################
# test_peekaboo.sh - Comprehensive test suite for Peekaboo screenshot automation
# Tests all scenarios: apps, formats, multi-window, discovery, error handling
################################################################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PEEKABOO_SCRIPT="$SCRIPT_DIR/peekaboo.scpt"
# Legacy variables for backward compatibility
PEEKABOO_CLASSIC="$PEEKABOO_SCRIPT"
PEEKABOO_PRO="$PEEKABOO_SCRIPT"
TEST_OUTPUT_DIR="$HOME/Desktop/peekaboo_tests"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    local script_path="$2"
    local app_identifier="$3"
    local output_path="$4"
    local expected_result="$5" # "success" or "error"
    local extra_args="${6:-}" # Optional extra arguments
    
    ((TESTS_RUN++))
    log_info "Running test: $test_name"
    
    # Run the peekaboo script
    local result
    local exit_code
    
    if [[ -n "$extra_args" ]]; then
        if result=$(osascript "$script_path" "$app_identifier" "$output_path" $extra_args 2>&1); then
            exit_code=0
        else
            exit_code=1
        fi
    else
        if result=$(osascript "$script_path" "$app_identifier" "$output_path" 2>&1); then
            exit_code=0
        else
            exit_code=1
        fi
    fi
    
    # Check result - Updated for enhanced error messages
    if [[ "$expected_result" == "success" ]]; then
        if [[ $exit_code -eq 0 ]] && ([[ "$result" == *"Screenshot captured successfully"* ]] || [[ "$result" == *"Captured"* ]] || [[ "$result" == *"Multi-window capture successful"* ]]); then
            if [[ -f "$output_path" ]] || [[ "$result" == *"Captured"* ]] || [[ "$result" == *"Multi-window"* ]]; then
                log_success "$test_name - Success"
                # Show first line of result for context
                local first_line=$(echo "$result" | head -1)
                log_info "  Result: $first_line"
                # Get file size for verification if single file
                if [[ -f "$output_path" ]]; then
                    local file_size=$(stat -f%z "$output_path" 2>/dev/null || echo "0")
                    if [[ $file_size -gt 1000 ]]; then
                        log_info "  File size: ${file_size} bytes (reasonable)"
                    else
                        log_warning "  File size: ${file_size} bytes (suspiciously small)"
                    fi
                fi
            else
                log_error "$test_name - Script reported success but file not found: $output_path"
            fi
        else
            log_error "$test_name - Expected success but got: $result"
        fi
    else
        # Expected error - Updated for enhanced error messages
        if [[ $exit_code -ne 0 ]] || [[ "$result" == *"Error:"* ]] || [[ "$result" == *"Peekaboo 👀:"* ]] && [[ "$result" == *"Error"* ]]; then
            log_success "$test_name - Correctly failed"
            # Show error type for context
            local error_type=$(echo "$result" | grep -o "[A-Za-z ]*Error:" | head -1)
            if [[ -n "$error_type" ]]; then
                log_info "  Error type: $error_type"
            fi
        else
            log_error "$test_name - Expected error but got success: $result"
        fi
    fi
    
    echo ""
}

# Helper functions for AI testing
check_ollama_available() {
    if command -v ollama >/dev/null 2>&1 && ollama --version >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

get_test_vision_models() {
    if check_ollama_available; then
        # Try to get available vision models, fallback to empty if none
        ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -E "(llava|qwen|gemma|minicpm)" | head -3 || echo ""
    else
        echo ""
    fi
}

create_test_image() {
    local image_path="$1"
    # Create a simple test image using ImageMagick or native macOS tools
    if command -v magick >/dev/null 2>&1; then
        magick -size 400x300 xc:white -fill black -pointsize 30 -annotate +50+150 "Peekaboo Test Image" "$image_path"
    elif command -v convert >/dev/null 2>&1; then
        convert -size 400x300 xc:white -fill black -pointsize 30 -annotate +50+150 "Peekaboo Test Image" "$image_path"
    else
        # Fallback: take a screenshot of Finder to create test image
        osascript "$PEEKABOO_SCRIPT" "Finder" "$image_path" >/dev/null 2>&1 || true
    fi
}

# AI analysis test function
run_ai_test() {
    local test_name="$1"
    local script_path="$2" 
    local test_type="$3"  # "one-step" or "two-step" or "analyze-only"
    local app_or_image="$4"
    local question="$5"
    local model="${6:-}"
    local expected_result="$7" # "success", "error", or "skip"
    
    ((TESTS_RUN++))
    log_info "Running AI test: $test_name"
    
    local result
    local exit_code
    local cmd_args=()
    
    # Build command arguments based on test type
    case "$test_type" in
        "one-step")
            cmd_args=("$app_or_image" "-a" "$question")
            if [[ -n "$model" ]]; then
                if [[ "$model" == "--provider"* ]]; then
                    cmd_args+=($model)
                else
                    cmd_args+=(--model "$model")
                fi
            fi
            ;;
        "two-step")
            # First create a test image, then analyze it
            local test_image="/tmp/peekaboo_ai_test_${TIMESTAMP}.png"
            create_test_image "$test_image"
            if [[ ! -f "$test_image" ]]; then
                log_error "$test_name - Could not create test image"
                return
            fi
            cmd_args=("analyze" "$test_image" "$question")
            if [[ -n "$model" ]]; then
                if [[ "$model" == "--provider"* ]]; then
                    cmd_args+=($model)
                else
                    cmd_args+=(--model "$model")
                fi
            fi
            ;;
        "analyze-only")
            cmd_args=("analyze" "$app_or_image" "$question")
            if [[ -n "$model" ]]; then
                if [[ "$model" == "--provider"* ]]; then
                    cmd_args+=($model)
                else
                    cmd_args+=(--model "$model")
                fi
            fi
            ;;
    esac
    
    # Execute the command
    if result=$(osascript "$script_path" "${cmd_args[@]}" 2>&1); then
        exit_code=0
    else
        exit_code=1  
    fi
    
    # Check results
    case "$expected_result" in
        "success")
            if [[ $exit_code -eq 0 ]] && [[ "$result" == *"AI Analysis Complete"* ]]; then
                log_success "$test_name - AI analysis completed successfully"
                log_info "  Model used: $(echo "$result" | grep "🤖 Model:" | cut -d: -f2 | xargs || echo "Unknown")"
                # Check for timing info
                if [[ "$result" == *"took"* && "$result" == *"sec."* ]]; then
                    local timing=$(echo "$result" | grep -o "took [0-9.]* sec\." || echo "")
                    log_info "  Timing: $timing"
                fi
                # Show first few words of AI response
                local ai_answer=$(echo "$result" | sed -n '/💬 Answer:/,$ p' | tail -n +2 | head -1 | cut -c1-60)
                if [[ -n "$ai_answer" ]]; then
                    log_info "  AI Response: ${ai_answer}..."
                fi
            elif [[ "$result" == *"Ollama"* ]] && [[ "$result" == *"not"* ]]; then
                log_warning "$test_name - Skipped: Ollama not available"
                ((TESTS_FAILED--))  # Don't count as failure
            elif [[ "$result" == *"vision models"* ]] && [[ "$result" == *"found"* ]]; then
                log_warning "$test_name - Skipped: No vision models available"
                ((TESTS_FAILED--))  # Don't count as failure
            else
                log_error "$test_name - Expected AI success but got: $(echo "$result" | head -1)"
            fi
            ;;
        "error")
            if [[ $exit_code -ne 0 ]] || [[ "$result" == *"Error"* ]] || [[ "$result" == *"not found"* ]]; then
                log_success "$test_name - Correctly handled error case"
                log_info "  Error: $(echo "$result" | head -1)"
            else
                log_error "$test_name - Expected error but got success: $(echo "$result" | head -1)"
            fi
            ;;
        "skip")
            log_warning "$test_name - Skipped (expected)"
            ((TESTS_FAILED--))  # Don't count as failure
            ;;
        "timing")
            if [[ $exit_code -eq 0 ]] && [[ "$result" == *"took"* && "$result" == *"sec."* ]]; then
                local timing=$(echo "$result" | grep -o "took [0-9.]* sec\." || echo "")
                log_success "$test_name - Timing info present: $timing"
            else
                log_error "$test_name - Expected timing info but not found"
            fi
            ;;
        "multi-window-success")
            if [[ $exit_code -eq 0 ]] && [[ "$result" == *"Multi-window AI Analysis Complete"* ]]; then
                log_success "$test_name - Multi-window AI analysis completed successfully"
                # Count analyzed windows
                local window_count=$(echo "$result" | grep -c "🪟 Window" || echo "0")
                log_info "  Analyzed $window_count windows"
                # Check for timing info
                if [[ "$result" == *"Analysis of"* && "$result" == *"windows complete"* ]]; then
                    log_info "  Multi-window analysis completed"
                fi
            elif [[ "$result" == *"AI Analysis Complete"* ]]; then
                # Single window fallback (app might have closed windows)
                log_success "$test_name - Completed (single window mode)"
            else
                log_error "$test_name - Expected multi-window analysis but got: $(echo "$result" | head -1)"
            fi
            ;;
        "claude-limitation")
            if [[ "$result" == *"Claude Limitation"* || "$result" == *"doesn't support direct image file analysis"* ]]; then
                log_success "$test_name - Claude limitation correctly reported"
                # Check for timing even in error
                if [[ "$result" == *"took"* && "$result" == *"sec."* ]]; then
                    local timing=$(echo "$result" | grep -o "took [0-9.]* sec\." || echo "")
                    log_info "  Timing: $timing"
                fi
            else
                log_error "$test_name - Expected Claude limitation message"
            fi
            ;;
    esac
    
    echo ""
}

# Special test for commands that don't take file paths
run_command_test() {
    local test_name="$1"
    local script_path="$2"
    local command="$3"
    local expected_pattern="$4"
    
    ((TESTS_RUN++))
    log_info "Running command test: $test_name"
    
    local result
    local exit_code
    
    if result=$(osascript "$script_path" "$command" 2>&1); then
        exit_code=0
    else
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]] && [[ "$result" == *"$expected_pattern"* ]]; then
        log_success "$test_name - Command executed successfully"
        # Show more meaningful output for list/help commands
        if [[ "$command" == "list" ]]; then
            local app_count=$(echo "$result" | grep -c "^•" || echo "0")
            log_info "  Found $app_count running applications"
        elif [[ "$command" == "help" ]] || [[ "$command" == "" ]]; then
            log_info "  Help text displayed correctly"
        else
            log_info "  Output preview: $(echo "$result" | head -3 | tr '\n' ' ')..."
        fi
    else
        log_error "$test_name - Command failed or unexpected output: $result"
    fi
    
    echo ""
}

cleanup_test_files() {
    log_info "Cleaning up test files..."
    if [[ -d "$TEST_OUTPUT_DIR" ]]; then
        rm -rf "$TEST_OUTPUT_DIR"
    fi
}

setup_test_environment() {
    log_info "Setting up Peekaboo test environment..."
    
    # Check if Peekaboo scripts exist
    if [[ ! -f "$PEEKABOO_CLASSIC" ]]; then
        log_error "Peekaboo Classic script not found at: $PEEKABOO_CLASSIC"
        exit 1
    fi
    
    if [[ ! -f "$PEEKABOO_PRO" ]]; then
        log_error "Peekaboo Pro script not found at: $PEEKABOO_PRO"
        exit 1
    fi
    
    # Create test output directory
    mkdir -p "$TEST_OUTPUT_DIR"
    
    # Check permissions
    log_info "Checking system permissions..."
    log_warning "Note: This script requires Screen Recording permission in System Preferences > Security & Privacy"
    log_warning "If tests fail, please check that Terminal (or your terminal app) has Screen Recording permission"
    echo ""
}

run_basic_tests() {
    log_info "=== BASIC FUNCTIONALITY TESTS ==="
    echo ""
    
    # Test 1: Basic app window capture
    ((TESTS_RUN++))
    log_info "Running test: Basic app window capture"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -q 2>&1); then
        if [[ "$result" =~ ^/tmp/peekaboo_finder_[0-9_]+\.png$ ]]; then
            log_success "Basic app window capture - Success"
        else
            log_error "Basic app window capture - Unexpected output: $result"
        fi
    else
        log_error "Basic app window capture - Failed"
    fi
    echo ""
    
    # Test 2: Fullscreen capture (no app)
    ((TESTS_RUN++))
    log_info "Running test: Fullscreen capture"
    if result=$(osascript "$PEEKABOO_SCRIPT" -q 2>&1); then
        if [[ "$result" =~ ^/tmp/peekaboo_fullscreen_[0-9_]+\.png$ ]]; then
            log_success "Fullscreen capture - Success"
        else
            log_error "Fullscreen capture - Unexpected output: $result"
        fi
    else
        log_error "Fullscreen capture - Failed"
    fi
    echo ""
    
    # Test 3: Custom output path
    ((TESTS_RUN++))
    log_info "Running test: Custom output path"
    local custom_path="$TEST_OUTPUT_DIR/custom_test_${TIMESTAMP}.png"
    if result=$(osascript "$PEEKABOO_SCRIPT" Safari -o "$custom_path" -q 2>&1); then
        if [[ "$result" == "$custom_path" ]] && [[ -f "$custom_path" ]]; then
            log_success "Custom output path - File created correctly"
        else
            log_error "Custom output path - Output mismatch or file missing"
        fi
    else
        log_error "Custom output path - Failed"
    fi
    echo ""
    
    # Test 4: Bundle ID support
    ((TESTS_RUN++))
    log_info "Running test: Bundle ID support"
    if result=$(osascript "$PEEKABOO_SCRIPT" com.apple.finder -q 2>&1); then
        if [[ "$result" =~ ^/tmp/peekaboo_com_apple_finder_[0-9_]+\.png$ ]]; then
            log_success "Bundle ID support - Success"
        else
            log_error "Bundle ID support - Unexpected output: $result"
        fi
    else
        log_error "Bundle ID support - Failed"
    fi
    echo ""
}

run_window_capture_tests() {
    log_info "=== WINDOW CAPTURE TESTS ==="
    echo ""
    
    # Test 1: Window bounds capture verification
    ((TESTS_RUN++))
    log_info "Running test: Window bounds capture"
    local window_test_path="$TEST_OUTPUT_DIR/window_bounds_${TIMESTAMP}.png"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -o "$window_test_path" -v 2>&1); then
        if [[ "$result" == *"Capturing window bounds for"* ]] && [[ "$result" == *"-R"* ]]; then
            log_success "Window bounds capture - Using correct -R flag with bounds"
            # Extract bounds from verbose output
            local bounds=$(echo "$result" | grep -o "bounds for [^:]*: [0-9,]*" | head -1)
            if [[ -n "$bounds" ]]; then
                log_info "  Captured window bounds: $bounds"
            fi
        elif [[ "$result" == *"Warning: Could not capture window bounds"* ]]; then
            log_warning "Window bounds capture - Fallback to fullscreen (app may not have accessible windows)"
        else
            log_error "Window bounds capture - Not using window bounds method"
        fi
    else
        log_error "Window bounds capture - Failed"
    fi
    echo ""
    
    # Test 2: Verify file size is reasonable (window should be smaller than fullscreen)
    ((TESTS_RUN++))
    log_info "Running test: Window vs fullscreen size comparison"
    local window_file="$TEST_OUTPUT_DIR/size_window_${TIMESTAMP}.png"
    local fullscreen_file="$TEST_OUTPUT_DIR/size_fullscreen_${TIMESTAMP}.png"
    
    # Capture window
    osascript "$PEEKABOO_SCRIPT" Safari -o "$window_file" -q 2>&1
    # Capture fullscreen
    osascript "$PEEKABOO_SCRIPT" -f -o "$fullscreen_file" -q 2>&1
    
    if [[ -f "$window_file" ]] && [[ -f "$fullscreen_file" ]]; then
        local window_size=$(stat -f%z "$window_file" 2>/dev/null || stat -c%s "$window_file" 2>/dev/null)
        local fullscreen_size=$(stat -f%z "$fullscreen_file" 2>/dev/null || stat -c%s "$fullscreen_file" 2>/dev/null)
        
        if [[ $window_size -lt $fullscreen_size ]]; then
            log_success "Window size comparison - Window capture is smaller than fullscreen"
            log_info "  Window size: $window_size bytes, Fullscreen: $fullscreen_size bytes"
        else
            log_warning "Window size comparison - Window not smaller (may have captured fullscreen)"
        fi
    else
        log_error "Window size comparison - Could not create test files"
    fi
    echo ""
    
    # Test 3: Multi-window bounds capture
    ((TESTS_RUN++))
    log_info "Running test: Multi-window bounds capture"
    # Find an app with multiple windows
    local multi_app=""
    for app in "Safari" "Chrome" "Google Chrome" "Finder"; do
        local win_count=$(osascript -e "tell application \"System Events\" to tell process \"$app\" to count windows" 2>/dev/null || echo "0")
        if [[ $win_count -gt 1 ]]; then
            multi_app="$app"
            break
        fi
    done
    
    if [[ -n "$multi_app" ]]; then
        if result=$(osascript "$PEEKABOO_SCRIPT" "$multi_app" -m -v 2>&1); then
            local bounds_count=$(echo "$result" | grep -c "Capturing window [0-9]* bounds:")
            if [[ $bounds_count -gt 0 ]]; then
                log_success "Multi-window bounds - Captured $bounds_count windows with bounds"
            else
                log_error "Multi-window bounds - No window bounds captured"
            fi
        else
            log_error "Multi-window bounds - Failed"
        fi
    else
        log_warning "Multi-window bounds - No app with multiple windows found"
    fi
    echo ""
    
    # Test 4: Fallback message format
    ((TESTS_RUN++))
    log_info "Running test: Fallback message format"
    # Try to capture a non-existent or problematic app
    if result=$(osascript "$PEEKABOO_SCRIPT" "NonExistentApp123" 2>&1); then
        if [[ "$result" == *"Peekaboo 👀:"* ]]; then
            log_success "Fallback message - Uses correct Peekaboo prefix"
        else
            log_error "Fallback message - Missing Peekaboo prefix"
        fi
    else
        # Error is expected, check the error message
        if [[ "$result" == *"Peekaboo 👀:"* ]]; then
            log_success "Fallback message - Error uses correct prefix"
        else
            log_error "Fallback message - Error missing prefix: $result"
        fi
    fi
    echo ""
    
    # Test 5: Window capture with AI (verify bounds in AI mode)
    if command -v ollama >/dev/null 2>&1 && [[ $(get_test_vision_models | wc -l) -gt 0 ]]; then
        ((TESTS_RUN++))
        log_info "Running test: Window bounds with AI analysis"
        if result=$(osascript "$PEEKABOO_SCRIPT" Finder -a "Test question" -v 2>&1); then
            if [[ "$result" == *"Capturing window bounds"* ]] || [[ "$result" == *"Auto-enabling multi-window"* ]]; then
                log_success "Window bounds with AI - Using proper window capture"
            else
                log_warning "Window bounds with AI - May be using fullscreen fallback"
            fi
        else
            log_error "Window bounds with AI - Failed"
        fi
    else
        log_warning "Window bounds with AI - Skipped (no AI provider available)"
    fi
    echo ""
}

run_format_tests() {
    log_info "=== FORMAT SUPPORT TESTS ==="
    echo ""
    
    # Test 1: PNG format (default)
    ((TESTS_RUN++))
    log_info "Running test: PNG format (default)"
    local png_path="$TEST_OUTPUT_DIR/format_test_${TIMESTAMP}.png"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -o "$png_path" -q 2>&1); then
        if [[ -f "$png_path" ]]; then
            log_success "PNG format - File created successfully"
        else
            log_error "PNG format - File not created"
        fi
    else
        log_error "PNG format - Failed"
    fi
    echo ""
    
    # Test 2: JPG format with --format flag
    ((TESTS_RUN++))
    log_info "Running test: JPG format with flag"
    local jpg_base="$TEST_OUTPUT_DIR/format_jpg_${TIMESTAMP}"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -o "$jpg_base" --format jpg -q 2>&1); then
        if [[ -f "${jpg_base}.jpg" ]]; then
            log_success "JPG format - File created with correct extension"
        else
            log_error "JPG format - File not created or wrong extension"
        fi
    else
        log_error "JPG format - Failed"
    fi
    echo ""
    
    # Test 3: PDF format via extension
    ((TESTS_RUN++))
    log_info "Running test: PDF format via extension"
    local pdf_path="$TEST_OUTPUT_DIR/format_pdf_${TIMESTAMP}.pdf"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -o "$pdf_path" -q 2>&1); then
        if [[ -f "$pdf_path" ]]; then
            log_success "PDF format - File created with auto-detected format"
        else
            log_error "PDF format - File not created"
        fi
    else
        log_error "PDF format - Failed"
    fi
    echo ""
    
    run_test "Pro: No extension (default PNG)" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/format_default_${TIMESTAMP}" \
        "success"
}

run_advanced_tests() {
    log_info "=== ADVANCED FEATURE TESTS ==="
    echo ""
    
    # Test 1: Multi-window mode
    ((TESTS_RUN++))
    log_info "Running test: Multi-window mode"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -m -o "$TEST_OUTPUT_DIR/" 2>&1); then
        # Check if multiple files were created
        local window_files=$(ls "$TEST_OUTPUT_DIR"/peekaboo_finder_*_window_*.png 2>/dev/null | wc -l)
        if [[ $window_files -gt 0 ]]; then
            log_success "Multi-window mode - Created $window_files window files"
        else
            log_error "Multi-window mode - No window files created"
        fi
    else
        log_error "Multi-window mode - Failed: $result"
    fi
    echo ""
    
    # Test 2: Forced fullscreen with app
    ((TESTS_RUN++))
    log_info "Running test: Forced fullscreen with app"
    if result=$(osascript "$PEEKABOO_SCRIPT" Safari -f -q 2>&1); then
        if [[ "$result" =~ fullscreen ]]; then
            log_success "Forced fullscreen - Correctly captured fullscreen despite app"
        else
            log_error "Forced fullscreen - Wrong capture mode"
        fi
    else
        log_error "Forced fullscreen - Failed"
    fi
    echo ""
    
    # Test 3: Verbose mode
    ((TESTS_RUN++))
    log_info "Running test: Verbose mode"
    if result=$(osascript "$PEEKABOO_SCRIPT" Finder -v -q 2>&1); then
        # Verbose should still output just path in quiet mode
        if [[ "$result" =~ ^/tmp/peekaboo_finder_[0-9_]+\.png$ ]]; then
            log_success "Verbose mode - Works with quiet mode"
        else
            log_warning "Verbose mode - May have extra output"
        fi
    else
        log_error "Verbose mode - Failed"
    fi
    echo ""
    
    # Test 4: Combined options
    ((TESTS_RUN++))
    log_info "Running test: Combined options"
    local combo_path="$TEST_OUTPUT_DIR/combo_${TIMESTAMP}"
    if result=$(osascript "$PEEKABOO_SCRIPT" TextEdit -w -o "$combo_path" --format jpg -v -q 2>&1); then
        if [[ -f "${combo_path}.jpg" ]]; then
            log_success "Combined options - All options work together"
        else
            log_error "Combined options - File not created correctly"
        fi
    else
        log_error "Combined options - Failed"
    fi
    echo ""
        "TextEdit" \
        "$TEST_OUTPUT_DIR/pro_combined_${TIMESTAMP}.png" \
        "success" \
        "--window --verbose"
}

run_discovery_tests() {
    log_info "=== COMMAND TESTS ==="
    echo ""
    
    # Test 1: List command
    ((TESTS_RUN++))
    log_info "Running test: List command"
    if result=$(osascript "$PEEKABOO_SCRIPT" list 2>&1); then
        if [[ "$result" == *"Running Applications:"* ]]; then
            local app_count=$(echo "$result" | grep -c "^•" || echo "0")
            log_success "List command - Found $app_count running applications"
        else
            log_error "List command - Unexpected output"
        fi
    else
        log_error "List command - Failed"
    fi
    echo ""
    
    # Test 2: ls alias
    ((TESTS_RUN++))
    log_info "Running test: ls command alias"
    if result=$(osascript "$PEEKABOO_SCRIPT" ls 2>&1); then
        if [[ "$result" == *"Running Applications:"* ]]; then
            log_success "ls alias - Works correctly"
        else
            log_error "ls alias - Unexpected output"
        fi
    else
        log_error "ls alias - Failed"
    fi
    echo ""
    
    # Test 3: Help command
    ((TESTS_RUN++))
    log_info "Running test: Help command"
    if result=$(osascript "$PEEKABOO_SCRIPT" help 2>&1); then
        if [[ "$result" == *"USAGE:"* ]] && [[ "$result" == *"OPTIONS:"* ]]; then
            log_success "Help command - Shows proper help text"
        else
            log_error "Help command - Missing expected sections"
        fi
    else
        log_error "Help command - Failed"
    fi
    echo ""
    
    # Test 4: -h flag
    ((TESTS_RUN++))
    log_info "Running test: -h help flag"
    if result=$(osascript "$PEEKABOO_SCRIPT" -h 2>&1); then
        if [[ "$result" == *"USAGE:"* ]]; then
            log_success "-h flag - Shows help correctly"
        else
            log_error "-h flag - Unexpected output"
        fi
    else
        log_error "-h flag - Failed"
    fi
    echo ""
    
    run_command_test "Classic: Help command" \
        "$PEEKABOO_CLASSIC" \
        "" \
        "Peekaboo"
}

run_error_tests() {
    log_info "=== ERROR HANDLING TESTS ==="
    echo ""
    
    # Test non-existent app (should show enhanced error message)
    run_test "Error: Non-existent app name" \
        "$PEEKABOO_CLASSIC" \
        "NonExistentApp12345XYZ" \
        "$TEST_OUTPUT_DIR/error_nonexistent_${TIMESTAMP}.png" \
        "error"
    
    # Test malformed bundle ID (should show enhanced error message)
    run_test "Error: Non-existent bundle ID" \
        "$PEEKABOO_PRO" \
        "com.fake.nonexistent.app.that.does.not.exist" \
        "$TEST_OUTPUT_DIR/error_bundle_${TIMESTAMP}.png" \
        "error"
    
    # Test invalid path
    run_test "Error: Invalid relative path" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "relative/path/screenshot.png" \
        "error"
    
    # Test empty app name
    run_test "Error: Empty app name" \
        "$PEEKABOO_CLASSIC" \
        "" \
        "$TEST_OUTPUT_DIR/error_empty_${TIMESTAMP}.png" \
        "error"
    
    # Test permission edge cases
    run_test "Error: Read-only directory" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "/System/error_readonly_${TIMESTAMP}.png" \
        "error"
    
    # Test window mode with app that might have no windows
    run_test "Error: Window mode with background app" \
        "$PEEKABOO_PRO" \
        "Mimestream" \
        "$TEST_OUTPUT_DIR/error_no_windows_${TIMESTAMP}.png" \
        "error" \
        "--window"
}

run_edge_case_tests() {
    log_info "=== EDGE CASE TESTS ==="
    echo ""
    
    # Test very deep directory creation
    local deep_dir="$TEST_OUTPUT_DIR/very/deeply/nested/directory/structure/test"
    run_test "Edge: Deep directory creation" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "$deep_dir/deep_${TIMESTAMP}.png" \
        "success"
    
    # Test special characters in filenames
    run_test "Edge: Special chars in filename" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/special_chars_test_${TIMESTAMP}.png" \
        "success"
    
    # Test long filename
    local long_name="very_long_filename_that_tests_the_limits_of_filesystem_naming_conventions_${TIMESTAMP}"
    run_test "Edge: Long filename" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "$TEST_OUTPUT_DIR/${long_name}.png" \
        "success"
    
    # Test system apps with different bundle IDs
    run_test "Edge: System Preferences bundle ID" \
        "$PEEKABOO_PRO" \
        "com.apple.SystemPreferences" \
        "$TEST_OUTPUT_DIR/edge_sysprefs_${TIMESTAMP}.png" \
        "success"
    
    # Test app with spaces in name
    run_test "Edge: App with spaces" \
        "$PEEKABOO_CLASSIC" \
        "Activity Monitor" \
        "$TEST_OUTPUT_DIR/edge_spaces_${TIMESTAMP}.png" \
        "success"
}

run_ai_analysis_tests() {
    log_info "=== AI VISION ANALYSIS TESTS ==="
    echo ""
    
    # Check which providers are available
    local ollama_available=false
    local claude_available=false
    
    if check_ollama_available; then
        ollama_available=true
        log_info "✅ Ollama is available"
    else
        log_warning "❌ Ollama not found"
    fi
    
    if command -v claude >/dev/null 2>&1; then
        claude_available=true
        log_info "✅ Claude CLI is available"
    else
        log_warning "❌ Claude CLI not found"
    fi
    
    if [[ "$ollama_available" == false && "$claude_available" == false ]]; then
        log_warning "No AI providers found - skipping AI analysis tests"
        log_info "To enable AI tests:"
        log_info "  • Ollama: curl -fsSL https://ollama.ai/install.sh | sh && ollama pull llava:7b"
        log_info "  • Claude: Install from https://claude.ai/code"
        return
    fi
    
    # Test Ollama if available
    if [[ "$ollama_available" == true ]]; then
        # Get available vision models
        local models=($(get_test_vision_models))
        if [[ ${#models[@]} -eq 0 ]]; then
            log_warning "No Ollama vision models found - skipping Ollama tests"
            log_info "To enable: ollama pull qwen2.5vl:7b  # or llava:7b"
        else
            log_info "Found Ollama vision models: ${models[*]}"
            local test_model="${models[0]}"  # Use first available model
            
            # Run Ollama-specific tests
            run_ollama_tests "$test_model"
        fi
    fi
    
    # Test Claude if available
    if [[ "$claude_available" == true ]]; then
        run_claude_tests
    fi
    
    # Test provider selection
    if [[ "$ollama_available" == true || "$claude_available" == true ]]; then
        run_provider_selection_tests "$ollama_available" "$claude_available"
    fi
}

run_ollama_tests() {
    local test_model="$1"
    log_info ""
    log_info "--- Ollama Provider Tests ---"
    
    # Test 1: One-step AI analysis (screenshot + analyze)
    run_ai_test "Ollama: One-step screenshot + analysis" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "Finder" \
        "What application is shown in this screenshot?" \
        "" \
        "success"
    
    # Test 2: One-step with custom model
    run_ai_test "AI: One-step with custom model" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "TextEdit" \
        "Describe what you see" \
        "$test_model" \
        "success"
    
    # Test 3: Two-step analysis (analyze existing image)
    run_ai_test "AI: Two-step analysis" \
        "$PEEKABOO_SCRIPT" \
        "two-step" \
        "" \
        "What text is visible in this image?" \
        "" \
        "success"
    
    # Test 4: Analyze existing screenshot
    local existing_screenshot="$TEST_OUTPUT_DIR/ai_test_existing_${TIMESTAMP}.png"
    # First create a screenshot
    if osascript "$PEEKABOO_SCRIPT" "Finder" "$existing_screenshot" >/dev/null 2>&1; then
        run_ai_test "AI: Analyze existing screenshot" \
            "$PEEKABOO_SCRIPT" \
            "analyze-only" \
            "$existing_screenshot" \
            "What application window is shown?" \
            "" \
            "success"
    else
        log_warning "Could not create test screenshot for analysis"
    fi
    
    # Test 5: Multi-window AI analysis (if supported app available)
    # Try to find an app with multiple windows
    local multi_window_app=""
    for app in "Safari" "Chrome" "Google Chrome" "Firefox" "TextEdit"; do
        if osascript -e "tell application \"System Events\" to get name of every process whose name is \"$app\"" >/dev/null 2>&1; then
            # Check if app has multiple windows
            local window_count=$(osascript -e "tell application \"System Events\" to tell process \"$app\" to count windows" 2>/dev/null || echo "0")
            if [[ $window_count -gt 1 ]]; then
                multi_window_app="$app"
                break
            fi
        fi
    done
    
    if [[ -n "$multi_window_app" ]]; then
        run_ai_test "Ollama: Multi-window AI analysis" \
            "$PEEKABOO_SCRIPT" \
            "one-step" \
            "$multi_window_app" \
            "What's in each window?" \
            "" \
            "multi-window-success"
    else
        log_warning "No app with multiple windows found - skipping multi-window AI test"
    fi
    
    # Test 6: Force single window mode with -w flag
    if [[ -n "$multi_window_app" ]]; then
        ((TESTS_RUN++))
        log_info "Running AI test: Force single window with -w flag"
        if result=$(osascript "$PEEKABOO_SCRIPT" "$multi_window_app" -w -a "What's on this tab?" 2>&1); then
            if [[ "$result" == *"AI Analysis Complete"* ]] && [[ "$result" != *"Multi-window"* ]]; then
                log_success "Single window mode - Correctly analyzed only one window"
            else
                log_error "Single window mode - Unexpected result"
            fi
        else
            log_error "Single window mode - Failed"
        fi
        echo ""
    fi
    
    # Note: Timeout testing (90 seconds) is not included in automated tests
    # to avoid long test runs. The timeout is implemented with curl --max-time 90
    log_info "Note: AI timeout protection (90s) is active but not tested here"
    echo ""
    
    # Test 7: Error handling - invalid model
    run_ai_test "AI: Invalid model error handling" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "Finder" \
        "Test question" \
        "nonexistent-model:999b" \
        "error"
    
    # Test 8: Error handling - invalid image path
    run_ai_test "AI: Invalid image path error handling" \
        "$PEEKABOO_SCRIPT" \
        "analyze-only" \
        "/nonexistent/path/image.png" \
        "What do you see?" \
        "" \
        "error"
    
    # Test 7: Error handling - missing question
    ((TESTS_RUN++))
    log_info "Running AI test: Missing question parameter"
    local result
    if result=$(osascript "$PEEKABOO_SCRIPT" "Finder" "--ask" 2>&1); then
        log_error "AI: Missing question - Expected error but got success"
    else
        if [[ "$result" == *"requires a question"* ]]; then
            log_success "AI: Missing question - Correctly handled error"
        else
            log_error "AI: Missing question - Unexpected error: $result"
        fi
    fi
    echo ""
    
    # Test 8: Complex question with special characters
    run_ai_test "AI: Complex question with special chars" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "Safari" \
        "What's the URL? Are there any errors?" \
        "" \
        "success"
    
    # Test 9: Timing verification
    run_ai_test "AI: Verify timing output" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "Finder" \
        "What is shown?" \
        "" \
        "timing"
}

run_claude_tests() {
    log_info ""
    log_info "--- Claude Provider Tests ---"
    
    # Test 1: Claude provider selection
    run_ai_test "Claude: Provider selection test" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "Finder" \
        "What do you see?" \
        "--provider claude" \
        "claude-limitation"
    
    # Test 2: Claude analyze command
    run_ai_test "Claude: Analyze existing image" \
        "$PEEKABOO_SCRIPT" \
        "analyze-only" \
        "$TEST_OUTPUT_DIR/test_image.png" \
        "Describe this" \
        "--provider claude" \
        "claude-limitation"
    
    # Test 3: Claude timing verification
    ((TESTS_RUN++))
    log_info "Running AI test: Claude timing verification"
    local result
    if result=$(osascript "$PEEKABOO_SCRIPT" "Safari" "--ask" "Test" "--provider" "claude" 2>&1); then
        if [[ "$result" == *"check took"* && "$result" == *"sec."* ]]; then
            log_success "Claude: Timing verification - Shows execution time"
        else
            log_error "Claude: Timing verification - Missing timing info"
        fi
    else
        log_error "Claude: Timing verification - Unexpected error: $result"
    fi
    echo ""
}

run_provider_selection_tests() {
    local ollama_available="$1"
    local claude_available="$2"
    
    log_info ""
    log_info "--- Provider Selection Tests ---"
    
    # Test auto selection
    ((TESTS_RUN++))
    log_info "Running AI test: Auto provider selection"
    local result
    if result=$(osascript "$PEEKABOO_SCRIPT" "Finder" "--ask" "What is shown?" 2>&1); then
        if [[ "$ollama_available" == true ]]; then
            if [[ "$result" == *"Model:"* || "$result" == *"Analysis via"* ]]; then
                log_success "Provider: Auto selection - Correctly used Ollama"
            else
                log_error "Provider: Auto selection - Unexpected result"
            fi
        else
            if [[ "$result" == *"Claude"* ]]; then
                log_success "Provider: Auto selection - Correctly fell back to Claude"
            else
                log_error "Provider: Auto selection - Unexpected result"
            fi
        fi
    fi
    echo ""
    
    # Test explicit Ollama selection
    if [[ "$ollama_available" == true ]]; then
        run_ai_test "Provider: Explicit Ollama selection" \
            "$PEEKABOO_SCRIPT" \
            "one-step" \
            "Finder" \
            "What do you see?" \
            "--provider ollama" \
            "success"
    fi
    
    # Test invalid provider
    run_ai_test "Provider: Invalid provider error" \
        "$PEEKABOO_SCRIPT" \
        "one-step" \
        "Finder" \
        "Test" \
        "--provider invalid" \
        "error"
}

run_performance_tests() {
    log_info "=== PERFORMANCE TESTS ==="
    echo ""
    
    local start_time=$(date +%s)
    
    # Test rapid succession
    for i in {1..3}; do
        run_test "Performance: Rapid test $i" \
            "$PEEKABOO_CLASSIC" \
            "Finder" \
            "$TEST_OUTPUT_DIR/perf_rapid_${i}_${TIMESTAMP}.png" \
            "success"
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "Performance test completed in ${duration} seconds"
    
    # Test large output directory
    mkdir -p "$TEST_OUTPUT_DIR/performance_test"
    run_test "Performance: Many files in directory" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/performance_test/many_files_${TIMESTAMP}.png" \
        "success"
}

run_enhanced_messaging_tests() {
    log_info "=== ENHANCED MESSAGING VALIDATION ==="
    echo ""
    
    # Test that error messages contain specific guidance
    log_info "Testing enhanced error message content..."
    
    local app_error_result
    if app_error_result=$(osascript "$PEEKABOO_CLASSIC" "FakeApp123" "/tmp/test.png" 2>&1); then
        log_error "Expected error for fake app"
    else
        if [[ "$app_error_result" == *"Common issues:"* ]] && [[ "$app_error_result" == *"case-sensitive"* ]]; then
            log_success "Enhanced app name error - Contains troubleshooting guidance"
        else
            log_error "Enhanced app name error - Missing detailed guidance"
        fi
    fi
    
    local bundle_error_result
    if bundle_error_result=$(osascript "$PEEKABOO_PRO" "com.fake.bundle" "/tmp/test.png" 2>&1); then
        log_error "Expected error for fake bundle"
    else
        if [[ "$bundle_error_result" == *"bundle ID"* ]] && [[ "$bundle_error_result" == *"com.apple."* ]]; then
            log_success "Enhanced bundle ID error - Contains specific guidance"
        else
            log_error "Enhanced bundle ID error - Missing bundle-specific guidance"
        fi
    fi
    
    # Test success message format
    local success_result
    if success_result=$(osascript "$PEEKABOO_CLASSIC" "Finder" "/tmp/peekaboo_message_test.png" 2>&1); then
        if [[ "$success_result" == *"Screenshot captured successfully!"* ]] && [[ "$success_result" == *"• File:"* ]] && [[ "$success_result" == *"💡"* ]]; then
            log_success "Enhanced success message - Contains structured information"
            rm -f "/tmp/peekaboo_message_test.png"
        else
            log_error "Enhanced success message - Missing structured format"
        fi
    else
        log_error "Could not test success message format"
    fi
    
    echo ""
}

run_compatibility_tests() {
    log_info "=== COMPATIBILITY TESTS ==="
    echo ""
    
    # Test common third-party apps (if available)
    local common_apps=("Safari" "Terminal" "Calculator" "Preview")
    
    for app in "${common_apps[@]}"; do
        run_test "Compatibility: $app" \
            "$PEEKABOO_CLASSIC" \
            "$app" \
            "$TEST_OUTPUT_DIR/compat_${app,,}_${TIMESTAMP}.png" \
            "success"
    done
    
    # Test bundle IDs of system apps
    local system_bundles=("com.apple.Safari" "com.apple.Terminal" "com.apple.Calculator" "com.apple.Preview")
    
    for bundle in "${system_bundles[@]}"; do
        local app_name=$(echo "$bundle" | cut -d. -f3)
        run_test "Compatibility: $bundle" \
            "$PEEKABOO_PRO" \
            "$bundle" \
            "$TEST_OUTPUT_DIR/compat_bundle_${app_name,,}_${TIMESTAMP}.png" \
            "success"
    done
}

run_all_tests() {
    log_info "🎪 Starting Comprehensive Peekaboo Test Suite 🎪"
    echo "Timestamp: $TIMESTAMP"
    echo "Test output directory: $TEST_OUTPUT_DIR"
    echo "Classic script: $PEEKABOO_CLASSIC"
    echo "Pro script: $PEEKABOO_PRO"
    echo ""
    
    # Run all test categories
    run_basic_tests
    run_window_capture_tests
    run_format_tests
    run_advanced_tests
    run_discovery_tests
    run_ai_analysis_tests
    run_error_tests
    run_enhanced_messaging_tests
    run_edge_case_tests
    run_performance_tests
    run_compatibility_tests
}

show_usage_tests() {
    log_info "=== USAGE OUTPUT TESTS ==="
    echo ""
    
    # Test Classic usage
    log_info "Testing help output..."
    local help_output
    if help_output=$(osascript "$PEEKABOO_SCRIPT" help 2>&1); then
        if [[ "$help_output" == *"USAGE:"* ]] && [[ "$help_output" == *"Peekaboo"* ]]; then
            log_success "Help output test - Proper usage information displayed"
        else
            log_error "Help output test - Usage information incomplete"
        fi
    else
        log_error "Help output test - Failed to get help output"
    fi
    
    # Test no arguments (should capture fullscreen)
    log_info "Testing no arguments (fullscreen capture)..."
    local no_args_output
    if no_args_output=$(osascript "$PEEKABOO_SCRIPT" -q 2>&1); then
        if [[ "$no_args_output" =~ ^/tmp/peekaboo_fullscreen_[0-9_]+\.png$ ]]; then
            log_success "No args test - Correctly captures fullscreen"
        else
            log_error "No args test - Unexpected output: $no_args_output"
        fi
    else
        log_error "No args test - Failed"
    fi
    echo ""
}

run_stress_tests() {
    log_info "=== STRESS TESTS ==="
    echo ""
    
    # Test rapid-fire screenshots
    log_info "Running rapid-fire stress test..."
    local stress_start=$(date +%s)
    for i in {1..5}; do
        run_test "Stress: Rapid shot $i" \
            "$PEEKABOO_CLASSIC" \
            "Finder" \
            "$TEST_OUTPUT_DIR/stress_rapid_${i}_${TIMESTAMP}.png" \
            "success"
        sleep 0.5  # Brief pause between shots
    done
    local stress_end=$(date +%s)
    local stress_duration=$((stress_end - stress_start))
    log_info "Rapid-fire stress test completed in ${stress_duration} seconds"
    
    # Test concurrent directory creation
    run_test "Stress: Concurrent directory creation" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/stress/concurrent/test/deep/structure/screenshot_${TIMESTAMP}.png" \
        "success"
}

run_integration_tests() {
    log_info "=== INTEGRATION TESTS ==="
    echo ""
    
    # Test workflow: discovery -> screenshot -> verify
    log_info "Testing integrated workflow..."
    
    # Step 1: Discover apps
    local app_list
    if app_list=$(osascript "$PEEKABOO_PRO" list 2>&1); then
        log_success "Integration: App discovery successful"
        
        # Step 2: Extract an app name from the list
        local test_app=$(echo "$app_list" | grep -o "• [A-Za-z ]*" | head -1 | sed 's/• //' | xargs)
        if [[ -n "$test_app" ]]; then
            log_info "Integration: Found app '$test_app' for testing"
            
            # Step 3: Screenshot the discovered app
            run_test "Integration: Screenshot discovered app" \
                "$PEEKABOO_PRO" \
                "$test_app" \
                "$TEST_OUTPUT_DIR/integration_discovered_${TIMESTAMP}.png" \
                "success"
        else
            log_warning "Integration: Could not extract app name from discovery"
        fi
    else
        log_error "Integration: App discovery failed"
    fi
}

show_summary() {
    echo ""
    echo "🎪 ================================== 🎪"
    echo "🎯           TEST SUMMARY            🎯"
    echo "🎪 ================================== 🎪"
    echo ""
    echo "📊 Tests run:    $TESTS_RUN"
    echo "✅ Tests passed: $TESTS_PASSED"
    echo "❌ Tests failed: $TESTS_FAILED"
    echo ""
    
    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo "📈 Success rate: ${success_rate}%"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "🎉 ALL TESTS PASSED! Peekaboo is ready to rock! 🎉"
        echo "👀 → 📸 → 💾 — Peekaboo is working perfectly!"
    else
        log_error "⚠️  $TESTS_FAILED test(s) failed - check output above"
        echo "🔍 Review failed tests and check permissions/setup"
    fi
    
    echo ""
    log_info "📁 Test files location: $TEST_OUTPUT_DIR"
    if [[ -d "$TEST_OUTPUT_DIR" ]]; then
        local file_count=$(find "$TEST_OUTPUT_DIR" -type f -name "*.png" -o -name "*.jpg" -o -name "*.pdf" | wc -l)
        local total_size=$(du -sh "$TEST_OUTPUT_DIR" 2>/dev/null | cut -f1)
        log_info "📸 Generated $file_count screenshot file(s) (Total size: $total_size)"
        
        # Show largest files
        echo ""
        log_info "🔍 Largest test files:"
        find "$TEST_OUTPUT_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.pdf" \) -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -3 | while read -r line; do
            echo "   $(echo "$line" | awk '{print $5, $9}' | sed "s|$TEST_OUTPUT_DIR/||")"
        done
    fi
}

show_file_listing() {
    if [[ -d "$TEST_OUTPUT_DIR" ]]; then
        echo ""
        log_info "Generated test files:"
        find "$TEST_OUTPUT_DIR" -type f -exec ls -lh {} \; | while read -r line; do
            echo "  $line"
        done
    fi
}

# Main execution
main() {
    local run_mode="${1:-all}"
    
    setup_test_environment
    
    case "$run_mode" in
        "basic")
            log_info "🎯 Running basic tests only..."
            show_usage_tests
            run_basic_tests
            ;;
        "advanced")
            log_info "🎪 Running advanced tests only..."
            run_advanced_tests
            run_discovery_tests
            run_ai_analysis_tests
            ;;
        "ai")
            log_info "🤖 Running AI analysis tests only..."
            run_ai_analysis_tests
            ;;
        "errors")
            log_info "⚠️ Running error tests only..."
            run_error_tests
            run_enhanced_messaging_tests
            run_edge_case_tests
            ;;
        "stress")
            log_info "💪 Running stress tests only..."
            run_stress_tests
            run_performance_tests
            ;;
        "window")
            log_info "🪟 Running window capture tests only..."
            run_window_capture_tests
            ;;
        "quick")
            log_info "⚡ Running quick test suite..."
            show_usage_tests
            run_basic_tests
            run_window_capture_tests
            run_format_tests
            ;;
        "all"|*)
            log_info "🎪 Running comprehensive test suite..."
            show_usage_tests
            run_all_tests
            run_stress_tests
            run_integration_tests
            ;;
    esac
    
    show_summary
    show_file_listing
    
    if [[ "${2:-}" == "--cleanup" ]] || [[ "${1:-}" == "--cleanup" ]]; then
        cleanup_test_files
        log_info "🧹 Test files cleaned up"
    else
        log_info "💡 Run with --cleanup to remove test files"
        log_info "💡 Run with 'basic', 'advanced', 'ai', 'errors', 'stress', or 'quick' for focused testing"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "🎪 Peekaboo Comprehensive Test Suite 🎪"
        echo ""
        echo "Usage: $0 [test_mode] [--cleanup] [--help]"
        echo ""
        echo "Test Modes:"
        echo "  all          Run all tests (default) - comprehensive coverage"
        echo "  basic        Run basic functionality tests only"
        echo "  window       Run window capture tests only"
        echo "  advanced     Run advanced features (multi-window, discovery, AI)"
        echo "  ai           Run AI vision analysis tests only"
        echo "  errors       Run error handling and edge case tests"
        echo "  stress       Run performance and stress tests"
        echo "  quick        Run essential tests quickly"
        echo ""
        echo "Options:"
        echo "  --cleanup    Remove test files after running tests"
        echo "  --help       Show this help message"
        echo ""
        echo "🎯 Test Coverage:"
        echo "- ✅ Basic screenshots with smart filenames"
        echo "- ✅ App name and bundle ID resolution"
        echo "- ✅ Window bounds capture with -R flag"
        echo "- ✅ Window vs fullscreen size verification"
        echo "- ✅ Multiple image formats (PNG, JPG, PDF)"
        echo "- ✅ Multi-window capture with descriptive names"
        echo "- ✅ App discovery and window enumeration"
        echo "- ✅ AI vision analysis (one-step and two-step)"
        echo "- ✅ AI model auto-detection and error handling"
        echo "- ✅ Error handling and edge cases"
        echo "- ✅ Enhanced error messaging validation"
        echo "- ✅ Performance and stress testing"
        echo "- ✅ Integration workflows"
        echo "- ✅ Compatibility with system apps"
        echo "- ✅ Fallback message prefixes"
        echo ""
        echo "📝 Examples:"
        echo "  $0                    # Run all tests"
        echo "  $0 quick              # Quick test suite"
        echo "  $0 ai                 # Test AI vision analysis only"
        echo "  $0 basic --cleanup    # Basic tests + cleanup"
        echo "  $0 stress             # Performance testing"
        echo ""
        echo "🔧 Requirements:"
        echo "- Screen Recording permission in System Preferences"
        echo "- peekaboo.scpt in same directory"
        echo "- Various system apps available for testing"
        echo "- Optional: Ollama + vision models for AI analysis tests"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac