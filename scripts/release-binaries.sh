#!/bin/bash
set -e

# Release script for Peekaboo binaries
# This script builds universal binaries and prepares GitHub release artifacts

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
RELEASE_DIR="$PROJECT_ROOT/release"

echo -e "${BLUE}🚀 Peekaboo Release Build Script${NC}"

# Parse command line arguments
SKIP_CHECKS=false
CREATE_GITHUB_RELEASE=false
PUBLISH_NPM=false

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
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-checks          Skip pre-release checks"
            echo "  --create-github-release Create draft GitHub release"
            echo "  --publish-npm          Publish to npm after building"
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
    if ! npm run prepare-release; then
        echo -e "${RED}❌ Pre-release checks failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ All checks passed${NC}"
fi

# Step 2: Clean previous builds
echo -e "\n${BLUE}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

# Step 3: Read version from package.json
VERSION=$(node -p "require('$PROJECT_ROOT/package.json').version")
echo -e "${BLUE}Building version: ${VERSION}${NC}"

# Step 4: Build universal binary
echo -e "\n${BLUE}Building universal binary...${NC}"
if ! npm run build:swift:all; then
    echo -e "${RED}❌ Swift build failed!${NC}"
    exit 1
fi

# Step 5: Create release artifacts
echo -e "\n${BLUE}Creating release artifacts...${NC}"

# Create CLI release directory
CLI_RELEASE_DIR="$BUILD_DIR/peekaboo-macos-universal"
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
tar -czf "$RELEASE_DIR/peekaboo-macos-universal.tar.gz" "peekaboo-macos-universal"

# Create npm package tarball
echo -e "${BLUE}Creating npm package...${NC}"
cd "$PROJECT_ROOT"
NPM_PACK_OUTPUT=$(npm pack --pack-destination "$RELEASE_DIR" 2>&1)
NPM_PACKAGE=$(echo "$NPM_PACK_OUTPUT" | grep -o '[^ ]*\.tgz' | tail -1)

if [ -z "$NPM_PACKAGE" ]; then
    echo -e "${RED}❌ Failed to create npm package${NC}"
    exit 1
fi

# Step 6: Generate checksums
echo -e "\n${BLUE}Generating checksums...${NC}"
cd "$RELEASE_DIR"

# Generate SHA256 checksums
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 peekaboo-macos-universal.tar.gz > checksums.txt
    shasum -a 256 "$(basename "$NPM_PACKAGE")" >> checksums.txt
else
    echo -e "${YELLOW}⚠️  shasum not found, skipping checksum generation${NC}"
fi

# Step 7: Create release notes
echo -e "\n${BLUE}Generating release notes...${NC}"
cat > "$RELEASE_DIR/release-notes.md" << EOF
# Peekaboo v${VERSION}

## Installation

### Homebrew (Recommended)
\`\`\`bash
brew tap steipete/peekaboo
brew install peekaboo
\`\`\`

### Direct Download
\`\`\`bash
curl -L https://github.com/steipete/peekaboo/releases/download/v${VERSION}/peekaboo-macos-universal.tar.gz | tar xz
sudo mv peekaboo-macos-universal/peekaboo /usr/local/bin/
\`\`\`

### npm (includes MCP server)
\`\`\`bash
npm install -g @steipete/peekaboo-mcp
\`\`\`

## What's New

[Add changelog entries here]

## Checksums

\`\`\`
$(cat checksums.txt 2>/dev/null || echo "See checksums.txt")
\`\`\`
EOF

# Step 8: Display results
echo -e "\n${GREEN}✅ Release artifacts created successfully!${NC}"
echo -e "${BLUE}Release directory: ${RELEASE_DIR}${NC}"
echo -e "${BLUE}Artifacts:${NC}"
ls -la "$RELEASE_DIR"

# Step 9: Create GitHub release (if requested)
if [ "$CREATE_GITHUB_RELEASE" = true ]; then
    echo -e "\n${BLUE}Creating GitHub release draft...${NC}"
    
    if ! command -v gh >/dev/null 2>&1; then
        echo -e "${RED}❌ GitHub CLI (gh) not found. Install with: brew install gh${NC}"
        exit 1
    fi
    
    # Create release
    gh release create "v${VERSION}" \
        --draft \
        --title "v${VERSION}" \
        --notes-file "$RELEASE_DIR/release-notes.md" \
        "$RELEASE_DIR/peekaboo-macos-universal.tar.gz" \
        "$RELEASE_DIR/$(basename "$NPM_PACKAGE")" \
        "$RELEASE_DIR/checksums.txt"
    
    echo -e "${GREEN}✅ GitHub release draft created!${NC}"
    echo -e "${BLUE}Edit the release at: https://github.com/steipete/peekaboo/releases${NC}"
fi

# Step 10: Publish to npm (if requested)
if [ "$PUBLISH_NPM" = true ]; then
    echo -e "\n${BLUE}Publishing to npm...${NC}"
    
    # Confirm before publishing
    echo -e "${YELLOW}About to publish @steipete/peekaboo-mcp@${VERSION} to npm${NC}"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm publish
        echo -e "${GREEN}✅ Published to npm!${NC}"
    else
        echo -e "${YELLOW}Skipped npm publish${NC}"
    fi
fi

echo -e "\n${GREEN}🎉 Release build complete!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review artifacts in: $RELEASE_DIR"
echo "2. Test the binary: tar -xzf $RELEASE_DIR/peekaboo-macos-universal.tar.gz && ./peekaboo-macos-universal/peekaboo --version"
if [ "$CREATE_GITHUB_RELEASE" = false ]; then
    echo "3. Create GitHub release: $0 --create-github-release"
fi
if [ "$PUBLISH_NPM" = false ]; then
    echo "4. Publish to npm: $0 --publish-npm"
fi
echo "5. Update Homebrew formula with new version and SHA256"
