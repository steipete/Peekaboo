#!/bin/bash
# Smart CLI Wrapper for Peekaboo
# Automatically waits for Poltergeist rebuilds to complete before running

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINARY_PATH="$PROJECT_ROOT/peekaboo"
BUILD_LOCK="/tmp/peekaboo-swift-build.lock"
POLTERGEIST_LOG="$PROJECT_ROOT/.poltergeist.log"
MAX_WAIT=30  # Maximum seconds to wait for build
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
wait_count=0
while is_build_running && [ $wait_count -lt $MAX_WAIT ]; do
    if [ $wait_count -eq 0 ]; then
        echo "⏳ Waiting for Poltergeist to finish rebuilding..." >&2
    fi
    sleep 1
    ((wait_count++))
    
    # Show progress every 5 seconds
    if [ $((wait_count % 5)) -eq 0 ]; then
        echo "   Still waiting... (${wait_count}s)" >&2
    fi
done

if [ $wait_count -ge $MAX_WAIT ]; then
    echo "⚠️  Build is taking too long (>${MAX_WAIT}s). Running anyway..." >&2
fi

# If Poltergeist is actively working, give it a moment more
if is_poltergeist_active; then
    debug_log "Poltergeist is active, waiting 2 more seconds"
    sleep 2
fi

# Final freshness check
if is_binary_fresh; then
    debug_log "Binary is now fresh after waiting"
else
    debug_log "Binary might still be stale, but proceeding"
    # If the binary exists but is stale, Poltergeist should pick it up
    # We'll run it anyway to avoid blocking
fi

# Execute the binary
debug_log "Executing: $BINARY_PATH $*"
exec "$BINARY_PATH" "$@"