#!/bin/bash
# Poltergeist Handler - The script that actually rebuilds Swift CLI
# Called by Watchman when Swift files change

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/.poltergeist.log"
BUILD_LOCK="/tmp/peekaboo-swift-build.lock"

# Ensure log file exists
touch "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if a build is already running
if [ -f "$BUILD_LOCK" ]; then
    PID=$(cat "$BUILD_LOCK")
    if ps -p "$PID" > /dev/null 2>&1; then
        log "👻 Build already in progress (PID: $PID), skipping..."
        exit 0
    else
        # Stale lock file
        rm -f "$BUILD_LOCK"
    fi
fi

# Create lock file
echo $$ > "$BUILD_LOCK"

# Log the trigger
log "👻 Swift files changed, Poltergeist is rebuilding CLI..."

# Change to project root
cd "$PROJECT_ROOT"

# Capture start time
START_TIME=$(date +%s)

# Run the build
if npm run build:swift >> "$LOG_FILE" 2>&1; then
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
    log "❌ Swift CLI build failed (exit code: $?)"
    log "💡 Run 'poltergeist logs' to see the full error"
fi

# Remove lock file
rm -f "$BUILD_LOCK"