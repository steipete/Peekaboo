#!/bin/bash
# Smart CLI Wrapper for Peekaboo
# Automatically waits for Poltergeist rebuilds to complete before running

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINARY_PATH="$PROJECT_ROOT/peekaboo"
BUILD_LOCK="/tmp/peekaboo-cli-build.lock"
BUILD_STATUS="/tmp/peekaboo-cli-build-status.json"
RECOVERY_SIGNAL="/tmp/peekaboo-cli-build-recovery"
MAX_WAIT=180  # Maximum seconds to wait for build (3 minutes)
DEBUG="${PEEKABOO_WAIT_DEBUG:-false}"

# Debug logging
debug_log() {
    if [ "$DEBUG" = "true" ]; then
        echo "[peekaboo-wait] $1" >&2
    fi
}

# Function to check if binary is newer than all Swift sources
is_binary_fresh() {
    if [ ! -f "$BINARY_PATH" ]; then
        debug_log "Binary not found at $BINARY_PATH"
        return 1
    fi
    
    # Get binary modification time
    if [[ "$OSTYPE" == "darwin"* ]]; then
        BINARY_TIME=$(stat -f "%m" "$BINARY_PATH" 2>/dev/null)
    else
        BINARY_TIME=$(stat -c "%Y" "$BINARY_PATH" 2>/dev/null)
    fi
    
    debug_log "Binary modification time: $BINARY_TIME"
    
    # Find newest Swift file modification time
    NEWEST_SWIFT=0
    while IFS= read -r -d '' file; do
        if [[ "$OSTYPE" == "darwin"* ]]; then
            FILE_TIME=$(stat -f "%m" "$file" 2>/dev/null)
        else
            FILE_TIME=$(stat -c "%Y" "$file" 2>/dev/null)
        fi
        if [ "$FILE_TIME" -gt "$NEWEST_SWIFT" ]; then
            NEWEST_SWIFT=$FILE_TIME
            NEWEST_FILE="$file"
        fi
    done < <(find "$PROJECT_ROOT/Core/PeekabooCore/Sources" "$PROJECT_ROOT/Core/AXorcist/Sources" "$PROJECT_ROOT/Apps/CLI/Sources" -name "*.swift" -type f -print0 2>/dev/null)
    
    debug_log "Newest Swift file: $NEWEST_FILE (time: $NEWEST_SWIFT)"
    
    # Binary is fresh if it's newer than all Swift files
    if [ "$BINARY_TIME" -ge "$NEWEST_SWIFT" ]; then
        debug_log "Binary is fresh"
        return 0
    else
        debug_log "Binary is stale (older than Swift sources)"
        return 1
    fi
}

# Function to check if a build is running
is_build_running() {
    if [ -f "$BUILD_LOCK" ]; then
        PID=$(cat "$BUILD_LOCK" 2>/dev/null)
        if [ -n "$PID" ] && ps -p "$PID" > /dev/null 2>&1; then
            return 0
        else
            # Stale lock file
            debug_log "Removing stale build lock (PID $PID not running)"
            rm -f "$BUILD_LOCK"
        fi
    fi
    return 1
}


# Function to check build status from status file
check_build_status_file() {
    if [ ! -f "$BUILD_STATUS" ]; then
        debug_log "No build status file found"
        return 2  # Unknown status
    fi
    
    # Read status file
    local status=$(grep '"status"' "$BUILD_STATUS" 2>/dev/null | cut -d'"' -f4)
    local timestamp=$(grep '"timestamp"' "$BUILD_STATUS" 2>/dev/null | cut -d'"' -f4)
    local error_summary=$(grep '"error_summary"' "$BUILD_STATUS" 2>/dev/null | cut -d'"' -f4)
    
    # Check age of status
    if [ -n "$timestamp" ]; then
        # Convert ISO timestamp to epoch
        local status_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%s" 2>/dev/null || date -u -d "$timestamp" "+%s" 2>/dev/null || echo "0")
        local current_epoch=$(date +%s)
        local age=$((current_epoch - status_epoch))
        
        # If status is older than 5 minutes, consider it stale
        if [ $age -gt 300 ]; then
            debug_log "Build status is stale (${age}s old)"
            return 2  # Unknown/stale status
        fi
    fi
    
    case "$status" in
        "building")
            debug_log "Build status: currently building"
            return 3  # Building
            ;;
        "success")
            debug_log "Build status: success"
            return 0  # Success
            ;;
        "failed")
            debug_log "Build status: failed - $error_summary"
            echo "❌ POLTERGEIST BUILD FAILED" >&2
            echo "" >&2
            if [ -n "$error_summary" ]; then
                echo "Error: $error_summary" >&2
            else
                echo "Build failed. Check 'npm run poltergeist:logs' for details." >&2
            fi
            echo "" >&2
            echo "🔧 TO FIX: Run 'npm run build:swift' to see and fix the compilation errors." >&2
            echo "   After fixing, the wrapper will automatically use the new binary." >&2
            echo "" >&2
            return 1  # Failed
            ;;
        *)
            debug_log "Build status: unknown ($status)"
            return 2  # Unknown
            ;;
    esac
}

# Main logic
debug_log "Starting peekaboo-wait wrapper"
debug_log "Binary path: $BINARY_PATH"
debug_log "Build lock: $BUILD_LOCK"

# First, check if binary is already fresh
if is_binary_fresh; then
    debug_log "Binary is fresh, executing immediately"
    exec "$BINARY_PATH" "$@"
fi

# Binary is stale, check build status first
debug_log "Binary is stale, checking build status"

# Check if there's a recent build failure
check_build_status_file
status_result=$?

if [ $status_result -eq 1 ]; then
    # Build failed - exit with special code to trigger manual rebuild
    exit 42  # Special exit code for build failure
fi

# Check for ongoing build
if ! is_build_running; then
    # No build running, but binary is stale
    if [ $status_result -eq 0 ]; then
        # Status says success but binary is stale - might be a race condition
        debug_log "Status shows success but binary is stale, proceeding anyway"
    else
        # Unknown status or stale - Poltergeist should pick it up
        echo "⏳ Binary is stale. Waiting for Poltergeist to detect changes and rebuild..." >&2
        echo "   If this takes too long, check: npm run poltergeist:status" >&2
        
        # Give Poltergeist a moment to detect the stale binary
        sleep 2
    fi
fi

wait_count=0
while is_build_running && [ $wait_count -lt $MAX_WAIT ]; do
    if [ $wait_count -eq 0 ]; then
        echo "🔨 Poltergeist is rebuilding the Swift CLI..." >&2
    fi
    sleep 1
    ((wait_count++))
    
    # Show progress with more helpful messages
    if [ $((wait_count % 10)) -eq 0 ] && [ $wait_count -gt 0 ]; then
        remaining=$((MAX_WAIT - wait_count))
        echo "   Still building... (${wait_count}s elapsed, max ${remaining}s remaining)" >&2
        
    fi
done

if [ $wait_count -ge $MAX_WAIT ]; then
    echo "⚠️  Build timeout reached (${MAX_WAIT}s)." >&2
    echo "   Check build status with: npm run poltergeist:status" >&2
fi



# Final checks after waiting
debug_log "Performing final checks after wait"

# Check build status file again
check_build_status_file
final_status=$?

if [ $final_status -eq 1 ]; then
    # Build failed - exit with special code
    exit 42  # Special exit code for build failure
fi

# Final freshness check
if is_binary_fresh; then
    debug_log "Binary is now fresh after waiting"
else
    debug_log "Binary might still be stale, but proceeding"
    # If the binary exists but is stale, Poltergeist should pick it up
    # We'll run it anyway to avoid blocking
fi

# Execute the binary if it exists
if [ -f "$BINARY_PATH" ]; then
    debug_log "Executing: $BINARY_PATH $*"
    exec "$BINARY_PATH" "$@"
else
    echo "❌ Binary not found at: $BINARY_PATH" >&2
    echo "   This usually means the build failed." >&2
    echo "   Check: npm run poltergeist:logs" >&2
    exit 1
fi