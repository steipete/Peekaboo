#!/bin/bash
set -e
set -o pipefail

if command -v xcbeautify >/dev/null 2>&1; then
    USE_XCBEAUTIFY=1
else
    USE_XCBEAUTIFY=0
fi

pipe_build_output() {
    if [[ "$USE_XCBEAUTIFY" -eq 1 ]]; then
        xcbeautify "$@"
    else
        cat
    fi
}

echo "Building Swift CLI..."

# Change to CLI directory
cd "$(dirname "$0")/../Apps/CLI"

# Build the Swift CLI in release mode
swift build --configuration release 2>&1 | pipe_build_output

# Copy the binary to the root directory
cp .build/release/peekaboo ../peekaboo

# Make it executable
chmod +x ../peekaboo

echo "Swift CLI built successfully and copied to ./peekaboo"
