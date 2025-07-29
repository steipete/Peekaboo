#!/bin/bash
# Poltergeist Handler - The script that actually rebuilds Swift CLI
# Called by Watchman when Swift files change

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/.poltergeist.log"
BUILD_LOCK="/tmp/peekaboo-swift-build.lock"
BUILD_STATUS="/tmp/peekaboo-build-status.json"
CANCEL_FLAG="/tmp/peekaboo-build-cancel"
RECOVERY_SIGNAL="/tmp/peekaboo-build-recovery"
MIN_BUILD_TIME=5  # Minimum seconds before allowing cancellation
SPM_ERROR_RETRY_COUNT=0
MAX_SPM_RETRIES=2
BACKOFF_FILE="/tmp/peekaboo-build-backoff"

# Ensure log file exists
touch "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to write build status
write_build_status() {
    local status="$1"
    local error_summary="$2"
    local git_hash=$(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    cat > "$BUILD_STATUS" <<EOF
{
    "status": "$status",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "git_hash": "$git_hash",
    "error_summary": "$error_summary",
    "builder": "poltergeist"
}
EOF
}

# Function to check for recovery signal
check_recovery_signal() {
    if [ -f "$RECOVERY_SIGNAL" ]; then
        local signal_time=$(stat -f "%m" "$RECOVERY_SIGNAL" 2>/dev/null || stat -c "%Y" "$RECOVERY_SIGNAL" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local age=$((current_time - signal_time))
        
        # If recovery signal is less than 5 minutes old, honor it
        if [ $age -lt 300 ]; then
            log "🔄 Recovery signal detected, resetting backoff"
            rm -f "$BACKOFF_FILE"
            rm -f "$RECOVERY_SIGNAL"
            return 0
        fi
    fi
    return 1
}

# Function to get backoff time
get_backoff_time() {
    if [ ! -f "$BACKOFF_FILE" ]; then
        echo "0"
        return
    fi
    
    local last_failure=$(cat "$BACKOFF_FILE" 2>/dev/null | grep "last_failure" | cut -d: -f2 || echo "0")
    local failure_count=$(cat "$BACKOFF_FILE" 2>/dev/null | grep "count" | cut -d: -f2 || echo "0")
    local current_time=$(date +%s)
    local time_since_failure=$((current_time - last_failure))
    
    # Backoff times: 60s, 120s, 300s (1min, 2min, 5min)
    case $failure_count in
        1) echo "60" ;;
        2) echo "120" ;;
        *) echo "300" ;;
    esac
}

# Function to update backoff
update_backoff() {
    local current_count=$(cat "$BACKOFF_FILE" 2>/dev/null | grep "count" | cut -d: -f2 || echo "0")
    local new_count=$((current_count + 1))
    
    cat > "$BACKOFF_FILE" <<EOF
count:$new_count
last_failure:$(date +%s)
EOF
}

# Function to kill a process tree
kill_process_tree() {
    local pid=$1
    local child_pids=$(pgrep -P "$pid" 2>/dev/null)
    
    # Kill children first
    if [ -n "$child_pids" ]; then
        for child in $child_pids; do
            kill_process_tree "$child"
        done
    fi
    
    # Then kill the parent
    if ps -p "$pid" > /dev/null 2>&1; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 0.1
        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    fi
}

# Check if a build is already running
if [ -f "$BUILD_LOCK" ]; then
    PID=$(cat "$BUILD_LOCK")
    if ps -p "$PID" > /dev/null 2>&1; then
        log "🛑 Canceling outdated build (PID: $PID) to start fresh build..."
        
        # Set cancel flag so the old build knows it was canceled
        touch "$CANCEL_FLAG"
        
        # Kill the old build process tree
        kill_process_tree "$PID"
        
        # Give it a moment to clean up
        sleep 0.5
        
        # Clean up lock file
        rm -f "$BUILD_LOCK"
        
        log "✅ Old build canceled, starting new build..."
    else
        # Stale lock file
        rm -f "$BUILD_LOCK"
    fi
fi

# Also check if SwiftPM is running to avoid conflicts
SWIFT_PIDS=$(pgrep -f "swift build|swift-build|swift-frontend" 2>/dev/null || true)
if [ -n "$SWIFT_PIDS" ]; then
    log "🛑 Canceling ${#SWIFT_PIDS[@]} Swift build process(es)..."
    for pid in $SWIFT_PIDS; do
        kill_process_tree "$pid"
    done
    sleep 0.5
    log "✅ Swift processes canceled"
fi

# Clear any cancel flag from previous runs
rm -f "$CANCEL_FLAG"

# Create lock file with our PID
echo $$ > "$BUILD_LOCK"

# Function to check if we should cancel this build
should_cancel() {
    [ -f "$CANCEL_FLAG" ]
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    
    # Remove lock file
    rm -f "$BUILD_LOCK"
    
    # Check if we were canceled
    if [ -f "$CANCEL_FLAG" ]; then
        log "🚫 Build was canceled by newer change"
        rm -f "$CANCEL_FLAG"
        exit 0
    elif [ $exit_code -eq 0 ]; then
        log "✅ Build handler completed successfully"
    else
        log "❌ Build handler failed (exit code: $exit_code)"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Check for recovery signal first
check_recovery_signal

# Check backoff
if [ -f "$BACKOFF_FILE" ]; then
    backoff_time=$(get_backoff_time)
    last_failure=$(cat "$BACKOFF_FILE" 2>/dev/null | grep "last_failure" | cut -d: -f2 || echo "0")
    current_time=$(date +%s)
    time_since_failure=$((current_time - last_failure))
    
    if [ $time_since_failure -lt $backoff_time ]; then
        remaining=$((backoff_time - time_since_failure))
        log "⏳ In backoff period, waiting ${remaining}s before next build attempt"
        exit 0
    fi
fi

# Log the trigger
log "👻 Swift files changed, Poltergeist is rebuilding CLI..."

# Write initial build status
write_build_status "building" ""

# Change to project root
cd "$PROJECT_ROOT"

# Capture start time
START_TIME=$(date +%s)
BUILD_START=$START_TIME


# Function to run build with retry logic
run_build() {
    local build_output_file="/tmp/peekaboo-build-output.$$"
    
    # Use incremental build for Poltergeist (no --clean flag)
    ./scripts/build-swift-debug.sh > "$build_output_file" 2>&1 &
    local BUILD_PID=$!
    
    # Monitor the build and check for cancellation
    while ps -p "$BUILD_PID" > /dev/null 2>&1; do
        local ELAPSED=$(($(date +%s) - BUILD_START))
        
        # Only allow cancellation after minimum build time
        if should_cancel && [ $ELAPSED -ge $MIN_BUILD_TIME ]; then
            log "🛑 Canceling current build due to newer changes (after ${ELAPSED}s)..."
            kill_process_tree "$BUILD_PID"
            rm -f "$build_output_file"
            # Don't exit here - let the function return with a special code
            return 3  # Special code for cancellation
        fi
        sleep 0.5
    done
    
    # Wait for build to complete and get exit code
    wait "$BUILD_PID"
    local exit_code=$?
    
    # Append output to log
    cat "$build_output_file" >> "$LOG_FILE"
    
    # Check for SPM errors
    if [ $exit_code -ne 0 ] && grep -q "Failed to parse target info" "$build_output_file"; then
        rm -f "$build_output_file"
        return 2  # Special code for SPM error
    fi
    
    # Always clean up build output file
    rm -f "$build_output_file"
    return $exit_code
}

# Run the build with retry logic for SPM errors
while true; do
    run_build
    BUILD_EXIT_CODE=$?
    
    # Check for cancellation
    if [ $BUILD_EXIT_CODE -eq 3 ]; then
        log "🚫 Build was canceled by newer change"
        rm -f "$CANCEL_FLAG"
        # Exit silently without notification
        exit 0
    fi
    
    if [ $BUILD_EXIT_CODE -eq 2 ] && [ $SPM_ERROR_RETRY_COUNT -lt $MAX_SPM_RETRIES ]; then
        SPM_ERROR_RETRY_COUNT=$((SPM_ERROR_RETRY_COUNT + 1))
        log "⚠️ SPM initialization error detected (attempt $SPM_ERROR_RETRY_COUNT/$MAX_SPM_RETRIES), retrying in 3s..."
        sleep 3
        BUILD_START=$(date +%s)  # Reset build start time
        continue
    fi
    
    break
done


if [ $BUILD_EXIT_CODE -eq 0 ]; then
    # Calculate build time
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    # Get current Git hash
    GIT_HASH=$(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    if [ $SPM_ERROR_RETRY_COUNT -gt 0 ]; then
        log "✅ Swift CLI build completed successfully after $SPM_ERROR_RETRY_COUNT retries (${BUILD_TIME}s) - git: $GIT_HASH"
    else
        log "✅ Swift CLI build completed successfully (${BUILD_TIME}s) - git: $GIT_HASH"
    fi
    
    # Write success status
    write_build_status "success" ""
    
    # Clear backoff on success
    rm -f "$BACKOFF_FILE"
    
    # Copy to root for easy access
    if cp -f Apps/CLI/.build/debug/peekaboo ./peekaboo 2>>"$LOG_FILE"; then
        log "✅ Copied binary to project root"
    else
        log "❌ Failed to copy binary to project root"
    fi
    
else
    # Get current Git hash for failure notifications too
    GIT_HASH=$(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    # Extract first few lines of error from log
    error_summary=$(tail -100 "$LOG_FILE" 2>/dev/null | grep -E "error:|Error:|fatal:" | head -3 | tr '\n' ' ' || echo "Build failed")
    
    if [ $BUILD_EXIT_CODE -eq 2 ]; then
        log "❌ Swift CLI build failed due to persistent SPM errors after $MAX_SPM_RETRIES retries - git: $GIT_HASH"
        write_build_status "failed" "SPM initialization error after $MAX_SPM_RETRIES retries"
    else
        log "❌ Swift CLI build failed (exit code: $BUILD_EXIT_CODE) - git: $GIT_HASH"
        write_build_status "failed" "$error_summary"
    fi
    log "💡 Run 'poltergeist logs' to see the full error"
    
    # Update backoff
    update_backoff
    
fi