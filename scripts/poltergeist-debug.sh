#!/bin/bash

# Debug wrapper for Poltergeist

set -x  # Enable debug output

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Script dir: $SCRIPT_DIR"
echo "Project dir: $PROJECT_DIR"
echo "Current dir: $(pwd)"

cd "$PROJECT_DIR"

echo "Changed to: $(pwd)"
echo "Config file exists: $(test -f poltergeist.config.json && echo YES || echo NO)"
echo "Running: node ../poltergeist/dist/cli.js $@"

exec node ../poltergeist/dist/cli.js "$@"