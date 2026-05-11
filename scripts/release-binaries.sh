#!/bin/bash
set -e

# Release script for Peekaboo binaries
# Default: universal (arm64+x86_64). Use --arm64-only to skip Intel.

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="${RELEASE_DIR:-$BUILD_DIR/release}"

echo -e "${BLUE}🚀 Peekaboo Release Build Script${NC}"

# Parse command line arguments
SKIP_CHECKS=false
CREATE_GITHUB_RELEASE=false
PUBLISH_NPM=false
UNIVERSAL=true
INCLUDE_MAC_APP=true
MAC_APP_NOTARIZE=true
MAC_APP_APPCAST=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --create-github-release)
            CREATE_GITHUB_RELEASE=true
            shift
            ;;
        --publish-npm)
            PUBLISH_NPM=true
            shift
            ;;
        --arm64-only)
            UNIVERSAL=false
            shift
            ;;
        --universal)
            UNIVERSAL=true
            shift
            ;;
        --skip-mac-app)
            INCLUDE_MAC_APP=false
            shift
            ;;
        --no-notarize-mac-app)
            MAC_APP_NOTARIZE=false
            shift
            ;;
        --no-appcast)
            MAC_APP_APPCAST=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-checks          Skip pre-release checks"
            echo "  --create-github-release Create draft GitHub release"
            echo "  --publish-npm          Publish to npm after building"
            echo "  --arm64-only           Build arm64-only binary"
            echo "  --universal            Build universal (arm64+x86_64) binary (default)"
            echo "  --skip-mac-app         Skip Peekaboo.app zip, Sparkle appcast, and app checksum"
            echo "  --no-notarize-mac-app  Build/sign app zip without Apple notarization"
            echo "  --no-appcast           Do not update appcast.xml"
            echo "  --help                 Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Step 1: Run pre-release checks (unless skipped)
if [ "$SKIP_CHECKS" = false ]; then
    echo -e "\n${BLUE}Running pre-release checks...${NC}"
    # `prepare-release` is intentionally not runner-wrapped here: it can exceed runner timeouts.
    if [ "$UNIVERSAL" = true ]; then
        PREP_ENV="PEEKABOO_REQUIRE_UNIVERSAL=1"
    else
        PREP_ENV=""
    fi
    if ! env $PREP_ENV node scripts/prepare-release.js; then
        echo -e "${RED}❌ Pre-release checks failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ All checks passed${NC}"
fi

# Step 2: Clean previous build outputs. Do not clear release/ until after
# version metadata is embedded, because release/ contains tracked files.
echo -e "\n${BLUE}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 3: Read version from package.json
VERSION=$(node -p "require('$PROJECT_ROOT/package.json').version")
echo -e "${BLUE}Building version: ${VERSION}${NC}"

# Step 4: Build binary
if [ "$UNIVERSAL" = true ]; then
    echo -e "\n${BLUE}Building universal binary...${NC}"
    BUILD_SCRIPT="build:swift:all"
    CLI_ARTIFACT_DIR="peekaboo-macos-universal"
    CLI_TARBALL_NAME="peekaboo-macos-universal.tar.gz"
else
    echo -e "\n${BLUE}Building arm64 binary...${NC}"
    BUILD_SCRIPT="build:swift"
    CLI_ARTIFACT_DIR="peekaboo-macos-arm64"
    CLI_TARBALL_NAME="peekaboo-macos-arm64.tar.gz"
fi

if ! pnpm run "$BUILD_SCRIPT"; then
    echo -e "${RED}❌ Swift build failed!${NC}"
    exit 1
fi

# Step 5: Create release artifacts
echo -e "\n${BLUE}Creating release artifacts...${NC}"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Create CLI release directory
CLI_RELEASE_DIR="$BUILD_DIR/$CLI_ARTIFACT_DIR"
mkdir -p "$CLI_RELEASE_DIR"

# Copy files for CLI release
cp "$PROJECT_ROOT/peekaboo" "$CLI_RELEASE_DIR/"
cp "$PROJECT_ROOT/LICENSE" "$CLI_RELEASE_DIR/"
echo "$VERSION" > "$CLI_RELEASE_DIR/VERSION"

# Create minimal README for binary distribution
cat > "$CLI_RELEASE_DIR/README.md" << EOF
# Peekaboo CLI v${VERSION}

Lightning-fast macOS screenshots & AI vision analysis.

## Installation

\`\`\`bash
# Make binary executable
chmod +x peekaboo

# Move to your PATH
sudo mv peekaboo /usr/local/bin/

# Verify installation
peekaboo --version
\`\`\`

## Quick Start

\`\`\`bash
# Capture screenshot
peekaboo image --app Safari --path screenshot.png

# List applications
peekaboo list apps

# Analyze image with AI
peekaboo analyze image.png "What is shown?"
\`\`\`

## Documentation

Full documentation: https://github.com/steipete/peekaboo

## License

MIT License - see LICENSE file
EOF

# Create tarball
echo -e "${BLUE}Creating tarball...${NC}"
cd "$BUILD_DIR"
tar -czf "$RELEASE_DIR/$CLI_TARBALL_NAME" "$CLI_ARTIFACT_DIR"

# Create npm package tarball
echo -e "${BLUE}Creating npm package...${NC}"
cd "$PROJECT_ROOT"
NPM_PACK_OUTPUT=$(pnpm pack --pack-destination "$RELEASE_DIR" 2>&1)
NPM_PACKAGE=$(echo "$NPM_PACK_OUTPUT" | grep -o '[^ ]*\.tgz' | tail -1)
NPM_PACKAGE_PATH="$RELEASE_DIR/$(basename "$NPM_PACKAGE")"

if [ -z "$NPM_PACKAGE" ]; then
    echo -e "${RED}❌ Failed to create npm package${NC}"
    exit 1
fi

# Step 6: Generate checksums
echo -e "\n${BLUE}Generating checksums...${NC}"
cd "$RELEASE_DIR"

# Generate SHA256 checksums
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$CLI_TARBALL_NAME" > checksums.txt
    shasum -a 256 "$(basename "$NPM_PACKAGE")" >> checksums.txt
else
    echo -e "${YELLOW}⚠️  shasum not found, skipping checksum generation${NC}"
fi

# Step 7: Build/sign/notarize macOS app zip and append checksum
MAC_APP_ZIP_PATH=""
if [ "$INCLUDE_MAC_APP" = true ]; then
    echo -e "\n${BLUE}Building Peekaboo.app release zip...${NC}"
    MAC_APP_ARGS=()
    if [ "$MAC_APP_NOTARIZE" = false ]; then
        MAC_APP_ARGS+=(--no-notarize)
    fi
    if [ "$MAC_APP_APPCAST" = false ]; then
        MAC_APP_ARGS+=(--no-appcast)
    fi
    if ! RELEASE_DIR="$RELEASE_DIR" "$PROJECT_ROOT/scripts/release-macos-app.sh" "${MAC_APP_ARGS[@]}"; then
        echo -e "${RED}❌ macOS app release failed!${NC}"
        exit 1
    fi
    MAC_APP_ZIP_PATH="$RELEASE_DIR/Peekaboo-${VERSION}.app.zip"
    if [ ! -f "$MAC_APP_ZIP_PATH" ]; then
        echo -e "${RED}❌ Expected macOS app artifact missing: $MAC_APP_ZIP_PATH${NC}"
        exit 1
    fi
fi

# Step 8: Create release notes
echo -e "\n${BLUE}Generating release notes...${NC}"
if ! awk -v version="$VERSION" '
    $0 ~ "^## \\[?" version "\\]?" {
        in_section = 1
        found = 1
        print
        next
    }
    in_section && /^## / {
        exit
    }
    in_section {
        print
    }
    END {
        if (!found) {
            exit 1
        }
    }
' "$PROJECT_ROOT/CHANGELOG.md" > "$RELEASE_DIR/release-notes.md"; then
    echo -e "${RED}❌ Could not extract v${VERSION} notes from CHANGELOG.md${NC}"
    exit 1
fi
perl -0pi -e 's/\n+\z/\n/' "$RELEASE_DIR/release-notes.md"

# Step 9: Display results
echo -e "\n${GREEN}✅ Release artifacts created successfully!${NC}"
echo -e "${BLUE}Release directory: ${RELEASE_DIR}${NC}"
echo -e "${BLUE}Artifacts:${NC}"
ls -la "$RELEASE_DIR"

# Step 10: Create GitHub release (if requested)
if [ "$CREATE_GITHUB_RELEASE" = true ]; then
    echo -e "\n${BLUE}Creating GitHub release draft...${NC}"
    
    if ! command -v gh >/dev/null 2>&1; then
        echo -e "${RED}❌ GitHub CLI (gh) not found. Install with: brew install gh${NC}"
        exit 1
    fi

    RELEASE_ASSETS=(
        "$RELEASE_DIR/$CLI_TARBALL_NAME"
        "$NPM_PACKAGE_PATH"
    )
    if [ -n "$MAC_APP_ZIP_PATH" ]; then
        RELEASE_ASSETS+=("$MAC_APP_ZIP_PATH")
    fi
    RELEASE_ASSETS+=("$RELEASE_DIR/checksums.txt")

    # Create release
    gh release create "v${VERSION}" \
        --draft \
        --title "v${VERSION}" \
        --notes-file "$RELEASE_DIR/release-notes.md" \
        "${RELEASE_ASSETS[@]}"
    
    echo -e "${GREEN}✅ GitHub release draft created!${NC}"
    echo -e "${BLUE}Edit the release at: https://github.com/openclaw/Peekaboo/releases${NC}"
fi

# Step 11: Publish to npm (if requested)
if [ "$PUBLISH_NPM" = true ]; then
    echo -e "\n${BLUE}Publishing to npm...${NC}"
    NPM_TAG=""
    if [[ "$VERSION" == *"-"* ]]; then
        NPM_TAG="beta"
    fi
    
    # Confirm before publishing
    if [ -n "$NPM_TAG" ]; then
        echo -e "${YELLOW}About to publish @steipete/peekaboo@${VERSION} to npm (tag: ${NPM_TAG})${NC}"
    else
        echo -e "${YELLOW}About to publish @steipete/peekaboo@${VERSION} to npm${NC}"
    fi
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -n "$NPM_TAG" ]; then
            pnpm publish "$NPM_PACKAGE_PATH" --tag "$NPM_TAG"
        else
            pnpm publish "$NPM_PACKAGE_PATH"
        fi
        echo -e "${GREEN}✅ Published to npm!${NC}"
    else
        echo -e "${YELLOW}Skipped npm publish${NC}"
    fi
fi

echo -e "\n${GREEN}🎉 Release build complete!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review artifacts in: $RELEASE_DIR"
echo "2. Test the binary: tar -xzf $RELEASE_DIR/$CLI_TARBALL_NAME && ./$CLI_ARTIFACT_DIR/peekaboo --version"
if [ "$CREATE_GITHUB_RELEASE" = false ]; then
    echo "3. Create GitHub release: $0 --create-github-release"
fi
if [ "$PUBLISH_NPM" = false ]; then
    echo "4. Publish to npm: $0 --publish-npm"
fi
echo "5. Update Homebrew formula with new version and SHA256"
