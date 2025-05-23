#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

PROJECT_ROOT_REL=".." # Relative path to project root from swift-cli
PROJECT_ROOT=$(cd "$(dirname "$0")/$PROJECT_ROOT_REL" && pwd)
SWIFT_PROJECT_PATH="$PROJECT_ROOT/swift-cli"
FINAL_BINARY_NAME="peekaboo"
FINAL_BINARY_PATH="$PROJECT_ROOT/$FINAL_BINARY_NAME"

ARM64_BINARY_TEMP="$PROJECT_ROOT/${FINAL_BINARY_NAME}-arm64"
X86_64_BINARY_TEMP="$PROJECT_ROOT/${FINAL_BINARY_NAME}-x86_64"

# Swift compiler flags for size optimization
# -Osize: Optimize for binary size.
# -wmo: Whole Module Optimization, allows more aggressive optimizations.
# -Xlinker -dead_strip: Remove dead code at the linking stage.
SWIFT_OPTIMIZATION_FLAGS="-Xswiftc -Osize -Xswiftc -wmo -Xlinker -dead_strip -Xlinker -no_uuid"

echo "🧹 Cleaning previous build artifacts..."
(cd "$SWIFT_PROJECT_PATH" && swift package reset) || echo "'swift package reset' encountered an issue, attempting rm -rf..."
rm -rf "$SWIFT_PROJECT_PATH/.build"
rm -f "$ARM64_BINARY_TEMP" "$X86_64_BINARY_TEMP" "$FINAL_BINARY_PATH.tmp"

echo "🏗️ Building for arm64 (Apple Silicon)..."
(cd "$SWIFT_PROJECT_PATH" && swift build --arch arm64 -c release $SWIFT_OPTIMIZATION_FLAGS)
cp "$SWIFT_PROJECT_PATH/.build/arm64-apple-macosx/release/$FINAL_BINARY_NAME" "$ARM64_BINARY_TEMP"
echo "✅ arm64 build complete: $ARM64_BINARY_TEMP"

echo "🏗️ Building for x86_64 (Intel)..."
(cd "$SWIFT_PROJECT_PATH" && swift build --arch x86_64 -c release $SWIFT_OPTIMIZATION_FLAGS)
cp "$SWIFT_PROJECT_PATH/.build/x86_64-apple-macosx/release/$FINAL_BINARY_NAME" "$X86_64_BINARY_TEMP"
echo "✅ x86_64 build complete: $X86_64_BINARY_TEMP"

echo "🔗 Creating universal binary..."
lipo -create -output "$FINAL_BINARY_PATH.tmp" "$ARM64_BINARY_TEMP" "$X86_64_BINARY_TEMP"

echo "🤏 Stripping symbols for further size reduction..."
# -S: Remove debugging symbols
# -x: Remove non-global symbols
strip -Sx "$FINAL_BINARY_PATH.tmp"

# Replace the old binary with the new one
mv "$FINAL_BINARY_PATH.tmp" "$FINAL_BINARY_PATH"

echo "🗑️ Cleaning up temporary architecture-specific binaries..."
rm -f "$ARM64_BINARY_TEMP" "$X86_64_BINARY_TEMP"

echo "🔍 Verifying final universal binary..."
lipo -info "$FINAL_BINARY_PATH"
ls -lh "$FINAL_BINARY_PATH"

echo "🎉 Universal binary '$FINAL_BINARY_PATH' created and optimized successfully!" 