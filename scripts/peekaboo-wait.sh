#!/bin/bash
# Smart CLI Wrapper for Peekaboo
# Automatically waits for Poltergeist rebuilds to complete before running

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINARY_PATH="$PROJECT_ROOT/peekaboo"
BUILD_LOCK="/tmp/peekaboo-swift-build.lock"
POLTERGEIST_LOG="$PROJECT_ROOT/.poltergeist.log"
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

# Function to check if Poltergeist is active
is_poltergeist_active() {
    # Check if there's recent activity in the log (within last 5 seconds)
    if [ -f "$POLTERGEIST_LOG" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            LOG_TIME=$(stat -f "%m" "$POLTERGEIST_LOG" 2>/dev/null)
            CURRENT_TIME=$(date +%s)
        else
            LOG_TIME=$(stat -c "%Y" "$POLTERGEIST_LOG" 2>/dev/null)
            CURRENT_TIME=$(date +%s)
        fi
        
        TIME_DIFF=$((CURRENT_TIME - LOG_TIME))
        if [ "$TIME_DIFF" -le 5 ]; then
            debug_log "Poltergeist is actively working (log updated ${TIME_DIFF}s ago)"
            return 0
        fi
    fi
    return 1
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

# Binary is stale, wait for any ongoing build
debug_log "Binary is stale, checking for ongoing builds"

# Always check build lock, even if no lock exists
if ! is_build_running; then
    # No build running, but binary is stale - Poltergeist should pick it up
    echo "⏳ Binary is stale. Waiting for Poltergeist to detect changes and rebuild..." >&2
    echo "   If this takes too long, check: npm run poltergeist:status" >&2
    
    # Give Poltergeist a moment to detect the stale binary
    sleep 2
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
        
        # Check if build has failed already
        if [ -f "$POLTERGEIST_LOG" ]; then
            recent_error=$(tail -5 "$POLTERGEIST_LOG" 2>/dev/null | grep -E "❌" | tail -1)
            if [ -n "$recent_error" ]; then
                echo "   ⚠️  Build appears to have failed. Waiting for completion..." >&2
            fi
        fi
    fi
done

if [ $wait_count -ge $MAX_WAIT ]; then
    echo "⚠️  Build timeout reached (${MAX_WAIT}s). Running with potentially stale binary..." >&2
    echo "   Consider checking 'npm run poltergeist:logs' for build issues." >&2
fi

# If Poltergeist is actively working, give it a moment more
if is_poltergeist_active; then
    debug_log "Poltergeist is active, waiting 2 more seconds"
    sleep 2
fi

# Check if Poltergeist reported a build failure
check_build_status() {
    if [ -f "$POLTERGEIST_LOG" ]; then
        # Check last few lines for build status
        local last_status=$(tail -20 "$POLTERGEIST_LOG" 2>/dev/null | grep -E "✅|❌" | tail -1)
        
        if echo "$last_status" | grep -q "❌"; then
            # Build failed!
            local error_details=$(echo "$last_status" | sed 's/.*❌ //')
            echo "❌ POLTERGEIST BUILD FAILED: $error_details" >&2
            echo "" >&2
            echo "📋 Recent build log:" >&2
            tail -30 "$POLTERGEIST_LOG" | grep -v "^\[" | head -20 >&2
            echo "" >&2
            echo "🤖 Claude should investigate and fix this build error." >&2
            echo "   Run: npm run poltergeist:logs" >&2
            echo "" >&2
            return 1
        fi
    fi
    return 0
}

# Final freshness check
if is_binary_fresh; then
    debug_log "Binary is now fresh after waiting"
    # But still check if the build failed
    if ! check_build_status; then
        echo "⚠️  Binary exists but last build failed. Claude needs to fix the build error." >&2
        exit 1
    fi
else
    debug_log "Binary might still be stale, but proceeding"
    # Check if build failed
    if ! check_build_status; then
        echo "⚠️  Build failed and binary is stale. Claude needs to fix the build error." >&2
        exit 1
    fi
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