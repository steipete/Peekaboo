#!/bin/bash
# Build script for macOS Peekaboo app using xcodebuild
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Build configuration (overridable for other schemes)
WORKSPACE="${WORKSPACE:-$PROJECT_ROOT/Apps/Peekaboo.xcworkspace}"
SCHEME="${SCHEME:-Peekaboo}"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_NAME="${APP_NAME:-$SCHEME}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_ROOT/.build/DerivedData}"

# Check if workspace exists
if [ ! -d "$WORKSPACE" ]; then
    echo -e "${RED}Error: Workspace not found at $WORKSPACE${NC}" >&2
    exit 1
fi

echo -e "${CYAN}Building ${SCHEME} macOS app (${CONFIGURATION})...${NC}"

# Build the app
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "platform=macOS" \
    build \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | pipe_build_output

BUILD_EXIT_CODE=${PIPESTATUS[0]}

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful${NC}"
    
    # Find and report the app location
    APP_PATH=$(find "$DERIVED_DATA_PATH" -name "${APP_NAME}.app" -type d | grep -E "Build/Products/${CONFIGURATION}" | head -1)
    if [ -n "$APP_PATH" ]; then
        echo -e "${GREEN}📦 App built at: $APP_PATH${NC}"
    fi
else
    echo -e "${RED}❌ Build failed with exit code $BUILD_EXIT_CODE${NC}" >&2
    exit $BUILD_EXIT_CODE
fi
