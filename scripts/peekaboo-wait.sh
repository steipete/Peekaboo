#!/bin/bash
# Smart CLI Wrapper for Peekaboo - Now Powered by pgrun
# This wrapper uses Poltergeist's pgrun for superior build management and diagnostics

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Path to pgrun
PGRUN_PATH="/Users/steipete/Projects/poltergeist/dist/pgrun.js"

# Check if pgrun is available
if [ ! -f "$PGRUN_PATH" ]; then
    echo "❌ pgrun not found at: $PGRUN_PATH" >&2
    echo "   This wrapper requires Poltergeist to be available." >&2
    echo "🔧 Please check that Poltergeist is installed and built." >&2
    exit 1
fi

# Map debug environment variable to pgrun verbose flag
PGRUN_ARGS=()
if [ "${PEEKABOO_WAIT_DEBUG:-false}" = "true" ]; then
    PGRUN_ARGS+=("--verbose")
fi

# Change to project directory to ensure correct context
cd "$PROJECT_ROOT"

# Create a symlink to the peekaboo binary for pgrun to find
# This works around the mismatch between target name (peekaboo-cli) and binary name (peekaboo)
if [ ! -e "$PROJECT_ROOT/peekaboo-cli" ] && [ -e "$PROJECT_ROOT/peekaboo" ]; then
    ln -sf peekaboo "$PROJECT_ROOT/peekaboo-cli"
fi

# Execute pgrun with peekaboo-cli target and all arguments
exec node "$PGRUN_PATH" peekaboo-cli "${PGRUN_ARGS[@]}" "$@"