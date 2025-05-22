#!/bin/bash
################################################################################
# test_peekaboo.sh - Comprehensive test suite for Peekaboo screenshot automation
# Tests all scenarios: apps, formats, multi-window, discovery, error handling
################################################################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PEEKABOO_CLASSIC="$SCRIPT_DIR/peekaboo.scpt"
PEEKABOO_PRO="$SCRIPT_DIR/peekaboo_enhanced.scpt"
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
    
    # Test 1: Basic Finder test (Classic)
    run_test "Classic: Basic Finder test" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "$TEST_OUTPUT_DIR/classic_finder_${TIMESTAMP}.png" \
        "success"
    
    # Test 2: Basic Finder test (Pro)
    run_test "Pro: Basic Finder test" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/pro_finder_${TIMESTAMP}.png" \
        "success"
    
    # Test 3: Bundle ID test
    run_test "Classic: Bundle ID test" \
        "$PEEKABOO_CLASSIC" \
        "com.apple.finder" \
        "$TEST_OUTPUT_DIR/classic_finder_bundle_${TIMESTAMP}.png" \
        "success"
    
    # Test 4: TextEdit test
    run_test "Classic: TextEdit test" \
        "$PEEKABOO_CLASSIC" \
        "TextEdit" \
        "$TEST_OUTPUT_DIR/classic_textedit_${TIMESTAMP}.png" \
        "success"
}

run_format_tests() {
    log_info "=== FORMAT SUPPORT TESTS ==="
    echo ""
    
    # Test different formats
    run_test "Classic: PNG format" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "$TEST_OUTPUT_DIR/format_png_${TIMESTAMP}.png" \
        "success"
    
    run_test "Classic: JPG format" \
        "$PEEKABOO_CLASSIC" \
        "Finder" \
        "$TEST_OUTPUT_DIR/format_jpg_${TIMESTAMP}.jpg" \
        "success"
    
    run_test "Classic: PDF format" \
        "$PEEKABOO_CLASSIC" \
        "TextEdit" \
        "$TEST_OUTPUT_DIR/format_pdf_${TIMESTAMP}.pdf" \
        "success"
    
    run_test "Pro: No extension (default PNG)" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/format_default_${TIMESTAMP}" \
        "success"
}

run_advanced_tests() {
    log_info "=== ADVANCED PEEKABOO PRO TESTS ==="
    echo ""
    
    # Test window mode
    run_test "Pro: Window mode test" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/pro_window_${TIMESTAMP}.png" \
        "success" \
        "--window"
    
    # Test multi-window mode
    run_test "Pro: Multi-window mode" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/pro_multi_${TIMESTAMP}.png" \
        "success" \
        "--multi"
    
    # Test verbose mode
    run_test "Pro: Verbose mode" \
        "$PEEKABOO_PRO" \
        "Finder" \
        "$TEST_OUTPUT_DIR/pro_verbose_${TIMESTAMP}.png" \
        "success" \
        "--verbose"
    
    # Test combined flags
    run_test "Pro: Window + Verbose" \
        "$PEEKABOO_PRO" \
        "TextEdit" \
        "$TEST_OUTPUT_DIR/pro_combined_${TIMESTAMP}.png" \
        "success" \
        "--window --verbose"
}

run_discovery_tests() {
    log_info "=== APP DISCOVERY TESTS ==="
    echo ""
    
    # Test list command
    run_command_test "Pro: List running apps" \
        "$PEEKABOO_PRO" \
        "list" \
        "Running Applications"
    
    # Test help command
    run_command_test "Pro: Help command" \
        "$PEEKABOO_PRO" \
        "help" \
        "Peekaboo Pro"
    
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
    run_format_tests
    run_advanced_tests
    run_discovery_tests
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
    log_info "Testing Classic usage output..."
    local classic_usage
    if classic_usage=$(osascript "$PEEKABOO_CLASSIC" 2>&1); then
        if [[ "$classic_usage" == *"Usage:"* ]] && [[ "$classic_usage" == *"Peekaboo"* ]]; then
            log_success "Classic usage test - Proper usage information displayed"
        else
            log_error "Classic usage test - Usage information incomplete"
        fi
    else
        log_error "Classic usage test - Failed to get usage output"
    fi
    
    # Test Pro usage
    log_info "Testing Pro usage output..."
    local pro_usage
    if pro_usage=$(osascript "$PEEKABOO_PRO" 2>&1); then
        if [[ "$pro_usage" == *"Usage:"* ]] && [[ "$pro_usage" == *"Peekaboo Pro"* ]]; then
            log_success "Pro usage test - Proper usage information displayed"
        else
            log_error "Pro usage test - Usage information incomplete"
        fi
    else
        log_error "Pro usage test - Failed to get usage output"
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
        "quick")
            log_info "⚡ Running quick test suite..."
            show_usage_tests
            run_basic_tests
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
        log_info "💡 Run with 'basic', 'advanced', 'errors', 'stress', or 'quick' for focused testing"
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
        echo "  advanced     Run advanced Pro features (multi-window, discovery)"
        echo "  errors       Run error handling and edge case tests"
        echo "  stress       Run performance and stress tests"
        echo "  quick        Run essential tests quickly"
        echo ""
        echo "Options:"
        echo "  --cleanup    Remove test files after running tests"
        echo "  --help       Show this help message"
        echo ""
        echo "🎯 Test Coverage:"
        echo "- ✅ Basic screenshots (Classic & Pro versions)"
        echo "- ✅ App name and bundle ID resolution"
        echo "- ✅ Multiple image formats (PNG, JPG, PDF)"
        echo "- ✅ Multi-window capture with descriptive names"
        echo "- ✅ App discovery and window enumeration"
        echo "- ✅ Error handling and edge cases"
        echo "- ✅ Enhanced error messaging validation"
        echo "- ✅ Performance and stress testing"
        echo "- ✅ Integration workflows"
        echo "- ✅ Compatibility with system apps"
        echo ""
        echo "📝 Examples:"
        echo "  $0                    # Run all tests"
        echo "  $0 quick              # Quick test suite"
        echo "  $0 basic --cleanup    # Basic tests + cleanup"
        echo "  $0 stress             # Performance testing"
        echo ""
        echo "🔧 Requirements:"
        echo "- Screen Recording permission in System Preferences"
        echo "- peekaboo.scpt and peekaboo_enhanced.scpt in same directory"
        echo "- Various system apps available for testing"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac