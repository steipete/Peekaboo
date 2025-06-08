# Cross-Platform Setup Guide

Peekaboo is now a cross-platform screen capture utility that works on macOS, Windows, and Linux.

## Platform Support

### macOS
- **Screen Capture**: ScreenCaptureKit (macOS 12.3+) with CGImage fallback
- **Window Management**: AppKit and Accessibility APIs
- **Permissions**: Screen Recording permission required
- **Dependencies**: None (built-in frameworks)

### Windows
- **Screen Capture**: DXGI Desktop Duplication API with GDI+ fallback
- **Window Management**: Win32 APIs (EnumWindows, GetWindowInfo)
- **Permissions**: UAC elevation may be required for some operations
- **Dependencies**: Windows 10+ recommended

### Linux
- **Screen Capture**: X11 (XGetImage) and Wayland (grim) support
- **Window Management**: wmctrl, xwininfo for X11; swaymsg for Wayland
- **Permissions**: X11 display access, Wayland portal permissions
- **Dependencies**: See installation section below

## Installation

### Prerequisites

#### Swift Installation

**macOS**: Swift comes with Xcode or Xcode Command Line Tools
```bash
xcode-select --install
```

**Windows**: Install Swift from [swift.org](https://swift.org/download/)
```powershell
# Download and install Swift for Windows
# Add Swift to PATH
```

**Linux**: Install Swift from [swift.org](https://swift.org/download/) or package manager
```bash
# Ubuntu/Debian
wget https://download.swift.org/swift-5.9-release/ubuntu2204/swift-5.9-RELEASE/swift-5.9-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-5.9-RELEASE-ubuntu22.04.tar.gz
export PATH=$PWD/swift-5.9-RELEASE-ubuntu22.04/usr/bin:$PATH

# Or use package manager (if available)
sudo apt-get install swift
```

#### Platform-Specific Dependencies

**Linux**:
```bash
# For X11 support
sudo apt-get install x11-utils wmctrl imagemagick

# For Wayland support (optional)
sudo apt-get install grim slurp

# Development libraries
sudo apt-get install libx11-dev libxext-dev
```

**Windows**:
```powershell
# No additional dependencies required
# Windows 10+ recommended for best compatibility
```

### Building

```bash
# Clone the repository
git clone <repository-url>
cd peekaboo

# Build the project
cd peekaboo-cli
swift build -c release

# Run tests
swift test
```

### Installation

```bash
# Install the binary
swift build -c release
cp .build/release/peekaboo /usr/local/bin/  # macOS/Linux
# or copy to appropriate location on Windows
```

## Usage

The CLI interface is consistent across all platforms:

```bash
# Capture screen
peekaboo image --mode screen

# Capture specific window
peekaboo image --mode window --app "Safari"

# List applications
peekaboo list apps

# List windows for an app
peekaboo list windows --app "Safari"
```

## Platform-Specific Notes

### macOS
- Requires Screen Recording permission (will prompt automatically)
- ScreenCaptureKit provides the best performance and quality
- Supports Retina displays natively

### Windows
- May require UAC elevation for some window operations
- DXGI provides hardware-accelerated capture
- Supports multiple monitors

### Linux
- X11 and Wayland support
- May require display server permissions
- Performance varies by desktop environment

## Troubleshooting

### Permission Issues

**macOS**: Grant Screen Recording permission in System Preferences > Security & Privacy
**Windows**: Run as Administrator if needed
**Linux**: Ensure X11 display access or Wayland portal permissions

### Build Issues

**Missing Swift**: Install Swift from swift.org
**Missing Dependencies**: Install platform-specific dependencies listed above
**Compilation Errors**: Ensure you're using Swift 5.9 or later

### Runtime Issues

**Screen Capture Fails**: Check permissions and display server compatibility
**Window Detection Fails**: Ensure target application is running and visible
**Cross-Platform Differences**: Some features may behave differently across platforms

## Development

### Architecture

The project uses a protocol-based architecture with platform-specific implementations:

- `ScreenCaptureProtocol`: Cross-platform screen capture interface
- `WindowManagerProtocol`: Window management and enumeration
- `ApplicationFinderProtocol`: Application discovery and management
- `PermissionsProtocol`: Platform-specific permission handling

### Adding Platform Support

1. Implement the required protocols for your platform
2. Add platform detection to `PlatformFactory`
3. Update build configuration in `Package.swift`
4. Add platform-specific tests

### Testing

```bash
# Run all tests
swift test

# Run platform-specific tests
swift test --filter PlatformFactoryTests

# Run with coverage
swift test --enable-code-coverage
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Ensure cross-platform compatibility
5. Submit a pull request

## License

[Add license information here]

