#!/bin/bash

# Wrapper script to run Poltergeist from the correct directory
# This works around the issue where Poltergeist doesn't handle
# being run from outside its directory properly

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project directory to ensure paths are resolved correctly
cd "$PROJECT_DIR"

POLTER_DIR="$(cd "$PROJECT_DIR/../poltergeist" && pwd)"
CLI_ENTRY="$POLTER_DIR/dist/cli.js"

if { [ "$1" = "panel" ] || { [ "$1" = "status" ] && [ "$2" = "panel" ]; }; }; then
  exec node --watch --watch-path "$POLTER_DIR/dist" --watch-preserve-output "$CLI_ENTRY" "$@"
else
  exec node "$CLI_ENTRY" "$@"
fi
