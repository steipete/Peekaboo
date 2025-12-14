#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SWIFT_PROJECT_PATH="$PROJECT_ROOT/Apps/CLI"
FINAL_BINARY_NAME="peekaboo"
FINAL_BINARY_PATH="$PROJECT_ROOT/$FINAL_BINARY_NAME"

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

# Swift compiler flags for size optimization
# -Osize: Optimize for binary size.
# -wmo: Whole Module Optimization, allows more aggressive optimizations.
# -Xlinker -dead_strip: Remove dead code at the linking stage.
SWIFT_OPTIMIZATION_FLAGS="-Xswiftc -Osize -Xswiftc -wmo -Xlinker -dead_strip"

echo "🧹 Cleaning previous build artifacts..."
(cd "$SWIFT_PROJECT_PATH" && swift package reset) || echo "'swift package reset' encountered an issue, attempting rm -rf..."
rm -rf "$SWIFT_PROJECT_PATH/.build"
rm -f "$FINAL_BINARY_PATH.tmp"

echo "📦 Reading version from version.json..."
VERSION=$(node -p "require('$PROJECT_ROOT/version.json').version")
echo "Version: $VERSION"

# Get git information
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_DATE=$(git show -s --format=%ci HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_DIRTY=$(git diff --quiet && git diff --cached --quiet || echo "-dirty")
BUILD_DATE=$(date -Iseconds)

echo "🧾 Embedding version metadata in Info.plist..."
generate_info_plist

echo "🏗️ Building for arm64 (Apple Silicon) only..."
(
    cd "$SWIFT_PROJECT_PATH"
    swift build --arch arm64 -c release $SWIFT_OPTIMIZATION_FLAGS 2>&1 | pipe_build_output
)
cp "$SWIFT_PROJECT_PATH/.build/arm64-apple-macosx/release/$FINAL_BINARY_NAME" "$FINAL_BINARY_PATH.tmp"
echo "✅ arm64 build complete"

echo "🤏 Stripping symbols for further size reduction..."
# -S: Remove debugging symbols
# -x: Remove non-global symbols
# -u: Save symbols of undefined references
# Note: LC_UUID is preserved by not using -no_uuid during linking
strip -Sxu "$FINAL_BINARY_PATH.tmp"

echo "🔏 Code signing the binary..."
ENTITLEMENTS_PATH="$SWIFT_PROJECT_PATH/Sources/Resources/peekaboo.entitlements"
if security find-identity -p codesigning -v | grep -q "Developer ID Application"; then
    # Sign with Developer ID if available
    SIGNING_IDENTITY=$(security find-identity -p codesigning -v | grep "Developer ID Application" | head -1 | awk '{print $2}')
    codesign --force --sign "$SIGNING_IDENTITY" \
        --options runtime \
        --identifier "boo.peekaboo.peekaboo" \
        --entitlements "$ENTITLEMENTS_PATH" \
        --timestamp \
        "$FINAL_BINARY_PATH.tmp"
    echo "✅ Signed with Developer ID: $SIGNING_IDENTITY"
else
    # Fall back to ad-hoc signing for local builds
    codesign --force --sign - \
        --identifier "boo.peekaboo.peekaboo" \
        --entitlements "$ENTITLEMENTS_PATH" \
        "$FINAL_BINARY_PATH.tmp"
    echo "⚠️  Ad-hoc signed (no Developer ID found)"
fi

# Verify the signature and embedded info
echo "🔍 Verifying code signature..."
codesign -dv "$FINAL_BINARY_PATH.tmp" 2>&1 | grep -E "Identifier=|Signature"

# Replace the old binary with the new one
mv "$FINAL_BINARY_PATH.tmp" "$FINAL_BINARY_PATH"

echo "🔍 Verifying final binary..."
lipo -info "$FINAL_BINARY_PATH"
ls -lh "$FINAL_BINARY_PATH"

echo "🎉 ARM64 binary '$FINAL_BINARY_PATH' created and optimized successfully!"
