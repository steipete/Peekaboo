#!/bin/bash
################################################################################
# test_screenshotter.sh - Test suite for screenshotter.scpt
# Tests various scenarios including app names, bundle IDs, formats, and error cases
################################################################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCREENSHOTTER_SCRIPT="$SCRIPT_DIR/screenshotter.scpt"
TEST_OUTPUT_DIR="$HOME/Desktop/screenshotter_tests"
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
    local app_identifier="$2"
    local output_path="$3"
    local expected_result="$4" # "success" or "error"
    
    ((TESTS_RUN++))
    log_info "Running test: $test_name"
    
    # Run the screenshotter script
    local result
    local exit_code
    
    if result=$(osascript "$SCREENSHOTTER_SCRIPT" "$app_identifier" "$output_path" 2>&1); then
        exit_code=0
    else
        exit_code=1
    fi
    
    # Check result
    if [[ "$expected_result" == "success" ]]; then
        if [[ $exit_code -eq 0 ]] && [[ "$result" == *"Screenshot captured successfully"* ]]; then
            if [[ -f "$output_path" ]]; then
                log_success "$test_name - Screenshot created at $output_path"
                # Get file size for verification
                local file_size=$(stat -f%z "$output_path" 2>/dev/null || echo "0")
                if [[ $file_size -gt 1000 ]]; then
                    log_info "  File size: ${file_size} bytes (reasonable)"
                else
                    log_warning "  File size: ${file_size} bytes (suspiciously small)"
                fi
            else
                log_error "$test_name - Script reported success but file not found: $output_path"
            fi
        else
            log_error "$test_name - Expected success but got: $result"
        fi
    else
        # Expected error
        if [[ $exit_code -ne 0 ]] || [[ "$result" == *"Error"* ]]; then
            log_success "$test_name - Correctly failed with: $result"
        else
            log_error "$test_name - Expected error but got success: $result"
        fi
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
    log_info "Setting up test environment..."
    
    # Check if screenshotter script exists
    if [[ ! -f "$SCREENSHOTTER_SCRIPT" ]]; then
        log_error "Screenshotter script not found at: $SCREENSHOTTER_SCRIPT"
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

run_all_tests() {
    log_info "Starting screenshotter.scpt test suite"
    echo "Timestamp: $TIMESTAMP"
    echo "Test output directory: $TEST_OUTPUT_DIR"
    echo ""
    
    # Test 1: Basic app name test with system app
    run_test "Basic Finder test" \
        "Finder" \
        "$TEST_OUTPUT_DIR/finder_${TIMESTAMP}.png" \
        "success"
    
    # Test 2: Bundle ID test
    run_test "Bundle ID test (Finder)" \
        "com.apple.finder" \
        "$TEST_OUTPUT_DIR/finder_bundle_${TIMESTAMP}.png" \
        "success"
    
    # Test 3: Different format test
    run_test "JPG format test" \
        "Finder" \
        "$TEST_OUTPUT_DIR/finder_${TIMESTAMP}.jpg" \
        "success"
    
    # Test 4: TextEdit test (another common app)
    run_test "TextEdit test" \
        "TextEdit" \
        "$TEST_OUTPUT_DIR/textedit_${TIMESTAMP}.png" \
        "success"
    
    # Test 5: PDF format test
    run_test "PDF format test" \
        "TextEdit" \
        "$TEST_OUTPUT_DIR/textedit_${TIMESTAMP}.pdf" \
        "success"
    
    # Test 6: Non-existent app (should fail)
    run_test "Non-existent app test" \
        "NonExistentApp12345" \
        "$TEST_OUTPUT_DIR/nonexistent_${TIMESTAMP}.png" \
        "error"
    
    # Test 7: Invalid path (should fail)
    run_test "Invalid path test" \
        "Finder" \
        "relative/path/screenshot.png" \
        "error"
    
    # Test 8: Empty app name (should fail)
    run_test "Empty app name test" \
        "" \
        "$TEST_OUTPUT_DIR/empty_${TIMESTAMP}.png" \
        "error"
    
    # Test 9: Directory creation test
    local deep_dir="$TEST_OUTPUT_DIR/deep/nested/directory"
    run_test "Directory creation test" \
        "Finder" \
        "$deep_dir/finder_deep_${TIMESTAMP}.png" \
        "success"
    
    # Test 10: Bundle ID for third-party app (if Safari is available)
    run_test "Safari bundle ID test" \
        "com.apple.Safari" \
        "$TEST_OUTPUT_DIR/safari_bundle_${TIMESTAMP}.png" \
        "success"
}

show_usage_test() {
    log_info "Testing usage output..."
    local usage_output
    if usage_output=$(osascript "$SCREENSHOTTER_SCRIPT" 2>&1); then
        if [[ "$usage_output" == *"Usage:"* ]] && [[ "$usage_output" == *"Examples:"* ]]; then
            log_success "Usage output test - Proper usage information displayed"
        else
            log_error "Usage output test - Usage information incomplete"
        fi
    else
        log_error "Usage output test - Failed to get usage output"
    fi
    echo ""
}

show_summary() {
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
    else
        log_error "$TESTS_FAILED test(s) failed"
    fi
    
    echo ""
    log_info "Test files location: $TEST_OUTPUT_DIR"
    if [[ -d "$TEST_OUTPUT_DIR" ]]; then
        local file_count=$(find "$TEST_OUTPUT_DIR" -type f | wc -l)
        log_info "Generated $file_count screenshot file(s)"
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
    setup_test_environment
    show_usage_test
    run_all_tests
    show_summary
    show_file_listing
    
    if [[ "${1:-}" == "--cleanup" ]]; then
        cleanup_test_files
        log_info "Test files cleaned up"
    else
        log_info "Run with --cleanup to remove test files"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--cleanup] [--help]"
        echo ""
        echo "Options:"
        echo "  --cleanup    Remove test files after running tests"
        echo "  --help       Show this help message"
        echo ""
        echo "This script tests the screenshotter.scpt AppleScript by:"
        echo "- Testing various app names and bundle IDs"
        echo "- Testing different output formats (PNG, JPG, PDF)"
        echo "- Testing error conditions"
        echo "- Verifying file creation and sizes"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac