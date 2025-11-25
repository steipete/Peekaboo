#!/bin/bash
set -e
set -o pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SWIFT_PROJECT_PATH="$PROJECT_ROOT/Apps/CLI"

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

set_plist_value() {
    local plist="$1"
    local key="$2"
    local value="$3"
    /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :$key string" "$plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Set :$key '$value'" "$plist"
}

generate_info_plist() {
    local template="$SWIFT_PROJECT_PATH/Sources/Resources/Info.plist"
    local output="$SWIFT_PROJECT_PATH/.generated/PeekabooCLI-Info.plist"
    mkdir -p "$SWIFT_PROJECT_PATH/.generated"
    cp "$template" "$output"

    local display="Peekaboo $VERSION"
    set_plist_value "$output" "CFBundleShortVersionString" "$VERSION"
    set_plist_value "$output" "CFBundleVersion" "$VERSION"
    set_plist_value "$output" "PeekabooVersionDisplayString" "$display"
    set_plist_value "$output" "PeekabooGitCommit" "$GIT_COMMIT$GIT_DIRTY"
    set_plist_value "$output" "PeekabooGitCommitDate" "$GIT_COMMIT_DATE"
    set_plist_value "$output" "PeekabooGitBranch" "$GIT_BRANCH"
    set_plist_value "$output" "PeekabooBuildDate" "$BUILD_DATE"

    export PEEKABOO_CLI_INFO_PLIST_PATH="$output"
}

# Parse arguments
CLEAN_BUILD=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_BUILD=true
fi

# Only clean if requested
if [[ "$CLEAN_BUILD" == "true" ]]; then
    echo "🧹 Cleaning previous build artifacts..."
    rm -rf "$SWIFT_PROJECT_PATH/.build"
    (cd "$SWIFT_PROJECT_PATH" && swift package reset 2>/dev/null || true)
fi

echo "📦 Reading version from version.json..."
VERSION=$(node -p "require('$PROJECT_ROOT/version.json').version" 2>/dev/null || echo "3.0.0-beta1-dev")

# Get git information
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_DATE=$(git show -s --format=%ci HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_DIRTY=$(git diff --quiet && git diff --cached --quiet || echo "-dirty")
BUILD_DATE=$(date -Iseconds)

echo "🧾 Embedding version metadata in Info.plist..."
generate_info_plist

if [[ "$CLEAN_BUILD" == "true" ]]; then
    echo "🏗️ Building for debug (clean build)..."
else
    echo "🏗️ Building for debug (incremental)..."
fi

(
    cd "$SWIFT_PROJECT_PATH"
    swift build 2>&1 | pipe_build_output
)

echo "🔏 Code signing the debug binary..."
PROJECT_NAME="peekaboo"
DEBUG_BINARY_PATH="$SWIFT_PROJECT_PATH/.build/debug/$PROJECT_NAME"
ENTITLEMENTS_PATH="$SWIFT_PROJECT_PATH/Sources/Resources/peekaboo.entitlements"

if [[ -f "$ENTITLEMENTS_PATH" ]]; then
    codesign --force --sign - \
        --identifier "boo.peekaboo" \
        --entitlements "$ENTITLEMENTS_PATH" \
        "$DEBUG_BINARY_PATH"
    echo "✅ Debug binary signed with entitlements"
else
    echo "⚠️  Entitlements file not found, signing without entitlements"
    codesign --force --sign - \
        --identifier "boo.peekaboo" \
        "$DEBUG_BINARY_PATH"
fi

echo "📦 Copying binary to project root..."
cp "$DEBUG_BINARY_PATH" "$PROJECT_ROOT/peekaboo"
echo "✅ Debug build complete"
