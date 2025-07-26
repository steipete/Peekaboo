#!/bin/bash
# Poltergeist Handler - The script that actually rebuilds Swift CLI
# Called by Watchman when Swift files change

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/.poltergeist.log"
BUILD_LOCK="/tmp/peekaboo-swift-build.lock"
CANCEL_FLAG="/tmp/peekaboo-build-cancel"

# Ensure log file exists
touch "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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

# Log the trigger
log "👻 Swift files changed, Poltergeist is rebuilding CLI..."

# Change to project root
cd "$PROJECT_ROOT"

# Capture start time
START_TIME=$(date +%s)

# Run the build with periodic cancel checks
(
    # Start the build in background
    npm run build:swift >> "$LOG_FILE" 2>&1 &
    BUILD_PID=$!
    
    # Monitor the build and check for cancellation
    while ps -p "$BUILD_PID" > /dev/null 2>&1; do
        if should_cancel; then
            log "🛑 Canceling current build due to newer changes..."
            kill_process_tree "$BUILD_PID"
            exit 1
        fi
        sleep 0.5
    done
    
    # Wait for build to complete and get exit code
    wait "$BUILD_PID"
)

BUILD_EXIT_CODE=$?

# Check if we were canceled
if should_cancel; then
    exit 0
fi

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    # Calculate build time
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    log "✅ Swift CLI build completed successfully (${BUILD_TIME}s)"
    
    # Copy to root for easy access
    if cp -f Apps/CLI/.build/debug/peekaboo ./peekaboo 2>>"$LOG_FILE"; then
        log "✅ Copied binary to project root"
    else
        log "❌ Failed to copy binary to project root"
    fi
else
    log "❌ Swift CLI build failed (exit code: $BUILD_EXIT_CODE)"
    log "💡 Run 'poltergeist logs' to see the full error"
fi