#!/bin/bash
set -e

# Script to update the Homebrew tap with a new Peekaboo release

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.0.1"
    exit 1
fi

VERSION=$1
TAP_DIR="/Users/steipete/Projects/homebrew-tap"
FORMULA_PATH="$TAP_DIR/Formula/peekaboo.rb"

echo "📦 Updating Homebrew tap for Peekaboo v$VERSION..."

# Check if tap directory exists
if [ ! -d "$TAP_DIR" ]; then
    echo "❌ Error: Homebrew tap directory not found at $TAP_DIR"
    exit 1
fi

# Download the release tarball to calculate SHA256
echo "⬇️  Downloading release tarball..."
TARBALL_URL="https://github.com/steipete/peekaboo/releases/download/v$VERSION/peekaboo-macos-universal.tar.gz"
TEMP_FILE="/tmp/peekaboo-v$VERSION.tar.gz"

if ! curl -L -o "$TEMP_FILE" "$TARBALL_URL"; then
    echo "❌ Error: Failed to download tarball from $TARBALL_URL"
    echo "Make sure the release v$VERSION exists on GitHub with the tarball uploaded."
    exit 1
fi

# Calculate SHA256
echo "🔐 Calculating SHA256..."
SHA256=$(shasum -a 256 "$TEMP_FILE" | awk '{print $1}')
echo "SHA256: $SHA256"

# Update the formula
echo "📝 Updating formula..."
sed -i '' "s|url \".*\"|url \"$TARBALL_URL\"|" "$FORMULA_PATH"
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA_PATH"
sed -i '' "s|version \".*\"|version \"$VERSION\"|" "$FORMULA_PATH"

# Clean up
rm "$TEMP_FILE"

echo "✅ Formula updated!"
echo ""
echo "Next steps:"
echo "1. cd $TAP_DIR"
echo "2. git add Formula/peekaboo.rb"
echo "3. git commit -m \"Update Peekaboo to v$VERSION\""
echo "4. git push"
echo ""
echo "5. Test the formula:"
echo "   brew update"
echo "   brew upgrade peekaboo"