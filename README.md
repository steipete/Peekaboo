# Peekaboo 👻

A **cross-platform** screenshot and screen capture tool that works seamlessly across **macOS**, **Windows**, and **Linux**. Built with Swift and designed for both command-line usage and MCP (Model Context Protocol) server integration.

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Windows](https://img.shields.io/badge/Windows-10%2B-blue.svg)](https://www.microsoft.com/windows/)
[![Linux](https://img.shields.io/badge/Linux-X11%2FWayland-blue.svg)](https://www.linux.org/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org/)

## ✨ Features

### 🖥️ Cross-Platform Screen Capture
- **macOS**: Native ScreenCaptureKit with CGImage fallback
- **Windows**: DXGI Desktop Duplication API
- **Linux**: X11 and Wayland support

### 📱 Comprehensive Capture Options
- Full screen capture (single or all displays)
- Window-specific capture
- Application-based capture
- Multi-display support with proper scaling

### 🎨 Multiple Image Formats
- PNG (default, lossless)
- JPEG (compressed)
- BMP (uncompressed)
- TIFF (high quality)

### 🔧 Advanced Features
- Application discovery and metadata
- Window enumeration and management
- Permission handling per platform
- MCP server for AI integration
- Command-line interface

## 🚀 Installation

### Quick Install (macOS/Linux)
```bash
curl -fsSL https://raw.githubusercontent.com/steipete/Peekaboo/main/scripts/install.sh | bash
```

### Quick Install (Windows)
```powershell
irm https://raw.githubusercontent.com/steipete/Peekaboo/main/scripts/install.ps1 | iex
```

### Manual Installation

#### Download Pre-built Binaries
1. Go to [Releases](https://github.com/steipete/Peekaboo/releases)
2. Download the appropriate binary for your platform:
   - **macOS (Apple Silicon)**: `peekaboo-*-macos-arm64.tar.gz`
   - **macOS (Intel)**: `peekaboo-*-macos-x86_64.tar.gz`
   - **Linux (x86_64)**: `peekaboo-*-linux-x86_64.tar.gz`
   - **Windows (x86_64)**: `peekaboo-*-windows-x86_64.zip`
3. Extract and run

#### Build from Source
```bash
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release
```

## 📋 Requirements

### macOS
- macOS 14.0 or later
- Screen Recording permission (granted automatically on first use)

### Windows  
- Windows 10 or later
- Administrator privileges may be required for some operations

### Linux
- X11 or Wayland display server
- Required libraries:
  ```bash
  # Ubuntu/Debian
  sudo apt-get install libx11-6 libxcomposite1 libxrandr2 libxdamage1 libxfixes3
  
  # Fedora/RHEL
  sudo dnf install libX11 libXcomposite libXrandr libXdamage libXfixes
  ```

## 🎯 Usage

### Command Line Interface

#### Basic Commands
```bash
# Show help
peekaboo --help

# List available displays
peekaboo list-displays

# List running applications
peekaboo list-apps

# List visible windows
peekaboo list-windows
```

#### Screen Capture
```bash
# Capture all screens
peekaboo capture-screen

# Capture specific display
peekaboo capture-screen --display-index 0

# Capture with custom format and output
peekaboo capture-screen --format jpeg --output screenshot.jpg
```

#### Window Capture
```bash
# Capture specific window by ID
peekaboo capture-window --window-id 12345

# Capture application windows
peekaboo capture-app --pid 67890

# Capture specific window of an app
peekaboo capture-app --pid 67890 --window-index 0
```

#### Advanced Options
```bash
# Save to specific directory
peekaboo capture-screen --output-dir ~/Screenshots

# Use different image format
peekaboo capture-screen --format png  # png, jpeg, bmp, tiff

# Capture with metadata
peekaboo capture-screen --include-metadata
```

### MCP Server Integration

Peekaboo includes an MCP server for AI integration:

```bash
# Start MCP server
peekaboo mcp-server

# Use with Claude Desktop or other MCP clients
# Add to your MCP configuration:
{
  "mcpServers": {
    "peekaboo": {
      "command": "peekaboo",
      "args": ["mcp-server"]
    }
  }
}
```

## 🏗️ Architecture

### Cross-Platform Design
```
┌─────────────────────────────────────────┐
│              CLI Interface              │
├─────────────────────────────────────────┤
│             MCP Server                  │
├─────────────────────────────────────────┤
│           Platform Factory              │
├─────────────┬─────────────┬─────────────┤
│    macOS    │   Windows   │    Linux    │
│             │             │             │
│ ScreenKit   │ DXGI API    │ X11/Wayland │
│ AppKit      │ Win32 API   │ XLib        │
│ Cocoa       │ WinRT       │ Wayland     │
└─────────────┴─────────────┴─────────────┘
```

### Key Components
- **PlatformFactory**: Creates platform-specific implementations
- **ScreenCaptureProtocol**: Unified interface for screen capture
- **ApplicationFinderProtocol**: Cross-platform app discovery
- **WindowManagerProtocol**: Window enumeration and management
- **PermissionCheckerProtocol**: Platform-specific permission handling

## 🧪 Development

### Building
```bash
cd peekaboo-cli
swift build
```

### Testing
```bash
# Run unit tests
swift test

# Run integration tests (requires display)
swift test --filter IntegrationTests

# Run performance tests
swift test --filter PerformanceTests
```

### Platform-Specific Development

#### macOS Development
- Requires Xcode 15.0 or later
- Uses ScreenCaptureKit for modern capture
- Falls back to CGImage for compatibility

#### Windows Development
- Requires Swift for Windows
- Uses DXGI Desktop Duplication API
- Win32 API for window management

#### Linux Development
- Requires Swift 5.10 or later
- X11 development libraries
- Optional Wayland support

## 📊 Performance

### Benchmarks
- **Screen Capture**: ~50ms average (varies by resolution)
- **Window Enumeration**: ~10ms average
- **Application Discovery**: ~20ms average

### Memory Usage
- Base memory: ~10MB
- Per capture: ~5-20MB (depends on resolution)
- Automatic cleanup after operations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass on all platforms
6. Submit a pull request

### Development Setup
```bash
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Swift team for cross-platform Swift support
- ScreenCaptureKit team at Apple
- X11 and Wayland communities
- MCP specification contributors

---

**Made with ❤️ by [Peter Steinberger](https://github.com/steipete)**

For more tools and projects, visit [steipete.com](https://steipete.com)

