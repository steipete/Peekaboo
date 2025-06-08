#!/bin/bash
set -e

# Peekaboo Installation Script
# Supports macOS and Linux

REPO="steipete/Peekaboo"
BINARY_NAME="peekaboo"
INSTALL_DIR="/usr/local/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect platform and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        darwin)
            PLATFORM="macos"
            ;;
        linux)
            PLATFORM="linux"
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    log_info "Detected platform: $PLATFORM-$ARCH"
}

# Get latest release version
get_latest_version() {
    log_info "Fetching latest release information..."
    
    if command -v curl >/dev/null 2>&1; then
        VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        VERSION=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        log_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    if [ -z "$VERSION" ]; then
        log_error "Failed to fetch latest version"
        exit 1
    fi
    
    log_info "Latest version: $VERSION"
}

# Download and extract binary
download_and_extract() {
    local filename="peekaboo-${VERSION}-${PLATFORM}-${ARCH}.tar.gz"
    local download_url="https://github.com/$REPO/releases/download/$VERSION/$filename"
    local temp_dir=$(mktemp -d)
    
    log_info "Downloading $filename..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$temp_dir/$filename" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_dir/$filename" "$download_url"
    fi
    
    if [ ! -f "$temp_dir/$filename" ]; then
        log_error "Failed to download $filename"
        exit 1
    fi
    
    log_info "Extracting binary..."
    tar -xzf "$temp_dir/$filename" -C "$temp_dir"
    
    if [ ! -f "$temp_dir/$BINARY_NAME" ]; then
        log_error "Binary not found in archive"
        exit 1
    fi
    
    BINARY_PATH="$temp_dir/$BINARY_NAME"
}

# Install binary
install_binary() {
    log_info "Installing $BINARY_NAME to $INSTALL_DIR..."
    
    # Check if we need sudo
    if [ ! -w "$INSTALL_DIR" ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo cp "$BINARY_PATH" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
        else
            log_error "No write permission to $INSTALL_DIR and sudo not available"
            log_info "Please run: cp $BINARY_PATH $INSTALL_DIR/ && chmod +x $INSTALL_DIR/$BINARY_NAME"
            exit 1
        fi
    else
        cp "$BINARY_PATH" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
    fi
    
    log_success "$BINARY_NAME installed successfully!"
}

# Verify installation
verify_installation() {
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local installed_version=$($BINARY_NAME --version 2>/dev/null || echo "unknown")
        log_success "Installation verified! Version: $installed_version"
        log_info "Run '$BINARY_NAME --help' to get started"
    else
        log_warning "Binary installed but not found in PATH"
        log_info "You may need to add $INSTALL_DIR to your PATH"
        log_info "Or run directly: $INSTALL_DIR/$BINARY_NAME --help"
    fi
}

# Check dependencies
check_dependencies() {
    case "$PLATFORM" in
        linux)
            log_info "Checking Linux dependencies..."
            
            # Check for X11 libraries
            if ! ldconfig -p | grep -q libX11; then
                log_warning "libX11 not found. Install with: sudo apt-get install libx11-6"
            fi
            
            if ! ldconfig -p | grep -q libXcomposite; then
                log_warning "libXcomposite not found. Install with: sudo apt-get install libxcomposite1"
            fi
            
            if ! ldconfig -p | grep -q libXrandr; then
                log_warning "libXrandr not found. Install with: sudo apt-get install libxrandr2"
            fi
            ;;
        macos)
            log_info "macOS dependencies should be available by default"
            ;;
    esac
}

# Main installation flow
main() {
    log_info "Peekaboo Installation Script"
    log_info "=============================="
    
    detect_platform
    check_dependencies
    get_latest_version
    download_and_extract
    install_binary
    verify_installation
    
    log_success "Installation complete!"
    echo
    log_info "Next steps:"
    echo "  1. Run 'peekaboo --help' to see available commands"
    echo "  2. Try 'peekaboo list-displays' to see available displays"
    echo "  3. Use 'peekaboo capture-screen' to take a screenshot"
    echo
    log_info "For more information, visit: https://github.com/$REPO"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Peekaboo Installation Script"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Install specific version"
        echo
        echo "Environment variables:"
        echo "  INSTALL_DIR    Installation directory (default: /usr/local/bin)"
        echo
        exit 0
        ;;
    --version|-v)
        if [ -z "${2:-}" ]; then
            log_error "Version not specified"
            exit 1
        fi
        VERSION="$2"
        ;;
esac

# Run main installation
main

