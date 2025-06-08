# 🌍 Peekaboo - Cross-Platform Screen Capture Utility

> Now you see it, now it's saved. A cross-platform screen capture utility that works seamlessly on **macOS**, **Windows**, and **Linux**.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows%20%7C%20Linux-blue.svg)](https://github.com/steipete/Peekaboo)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Features

### 🎯 **Universal Screen Capture**
- **Screen Capture**: Capture entire screens or specific displays
- **Window Capture**: Capture specific application windows
- **Multi-Window Capture**: Capture all windows from an application
- **Frontmost Window**: Capture the currently active window

### 🌍 **Cross-Platform Support**
- **macOS**: ScreenCaptureKit with CGImage fallback, full feature support
- **Windows**: DXGI Desktop Duplication API with GDI+ fallback
- **Linux**: X11 and Wayland support via external tools

### 🔧 **Smart Platform Detection**
- Automatic OS and architecture detection
- Capability-based feature detection
- Graceful fallbacks for unsupported features
- Platform-specific optimizations

### 📋 **Application & Window Management**
- List running applications across all platforms
- Enumerate windows for specific applications
- Cross-platform window information and bounds
- Platform-specific permission handling

## 🚀 Quick Start

### Installation

#### macOS
```bash
# Using Homebrew (coming soon)
brew install steipete/tap/peekaboo

# Or build from source
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release
```

#### Windows
```bash
# Prerequisites: Swift 6.0, Visual Studio Build Tools
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release
```

#### Linux
```bash
# Prerequisites: Swift 6.0, X11/Wayland development libraries
sudo apt-get install libx11-dev libxcomposite-dev libxrandr-dev libxfixes-dev
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release
```

### Basic Usage

```bash
# Capture primary screen
peekaboo image

# Capture specific application window
peekaboo image --app "Safari" --mode window

# Capture all windows from an application
peekaboo image --app "Safari" --mode multi

# List running applications
peekaboo list apps

# List windows for a specific app
peekaboo list windows --app "Safari"

# Check platform capabilities
peekaboo list server-status
```

## 📖 Detailed Usage

### Screen Capture

```bash
# Capture primary screen
peekaboo image --mode screen

# Capture specific screen by index
peekaboo image --mode screen --screen-index 1

# Capture to specific path
peekaboo image --mode screen --path ~/Screenshots/

# Capture in JPEG format
peekaboo image --mode screen --format jpg
```

### Window Capture

```bash
# Capture frontmost window of an app
peekaboo image --app "Safari" --mode window

# Capture specific window by title
peekaboo image --app "Safari" --window-title "GitHub"

# Capture specific window by index
peekaboo image --app "Safari" --window-index 0

# Capture all windows from an app
peekaboo image --app "Safari" --mode multi
```

### Application & Window Listing

```bash
# List all running applications
peekaboo list apps

# List with JSON output
peekaboo list apps --json-output

# List windows for specific app
peekaboo list windows --app "Safari"

# Include window bounds and details
peekaboo list windows --app "Safari" --details bounds --details ids
```

### Platform Status

```bash
# Check platform capabilities and permissions
peekaboo list server-status

# JSON output for scripting
peekaboo list server-status --json-output
```

## 🏗️ Architecture

### Protocol-Based Design

Peekaboo uses a protocol-based architecture for maximum flexibility and testability:

```swift
// Core protocols
protocol ScreenCaptureProtocol: Sendable { ... }
protocol WindowManagerProtocol: Sendable { ... }
protocol ApplicationFinderProtocol: Sendable { ... }
protocol PermissionsProtocol: Sendable { ... }

// Platform factory
let screenCapture = PlatformFactory.createScreenCapture()
let windowManager = PlatformFactory.createWindowManager()
```

### Platform-Specific Implementations

#### macOS
- **Screen Capture**: ScreenCaptureKit with CGImage fallback
- **Window Management**: AppKit and Core Graphics APIs
- **Application Finding**: NSWorkspace integration
- **Permissions**: System-level permission dialogs

#### Windows
- **Screen Capture**: DXGI Desktop Duplication API with GDI+ fallback
- **Window Management**: Win32 API window enumeration
- **Application Finding**: Process and module management
- **Permissions**: UAC-aware permission handling

#### Linux
- **Screen Capture**: X11 (XGetImage) and Wayland (grim) support
- **Window Management**: wmctrl and swaymsg integration
- **Application Finding**: /proc filesystem based process management
- **Permissions**: Display server specific permission handling

## 🔐 Permissions

### macOS
- **Screen Recording**: Required for screen and window capture
- **Accessibility**: Required for window enumeration and focus control

Grant permissions in **System Settings > Privacy & Security**

### Windows
- **UAC**: May require administrator privileges for some operations
- **Windows Security**: Screen capture permissions handled automatically

### Linux
- **X11**: Requires access to X11 display server
- **Wayland**: May require additional portal permissions
- **File System**: Read access to /proc for process information

## 🛠️ Development

### Building from Source

```bash
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build
```

### Running Tests

```bash
swift test
```

### Platform-Specific Development

#### macOS Development
```bash
# Requires Xcode 15.0+ or Swift 6.0+
swift build -c release
```

#### Windows Development
```bash
# Requires Swift 6.0 and Visual Studio Build Tools
swift build -c release
```

#### Linux Development
```bash
# Install dependencies
sudo apt-get install libx11-dev libxcomposite-dev libxrandr-dev libxfixes-dev

# Build
swift build -c release
```

### Adding New Platforms

1. Create platform-specific implementations in `Sources/peekaboo/Platforms/YourPlatform/`
2. Implement the required protocols
3. Update `PlatformFactory.swift` to include your platform
4. Add platform-specific CI workflows
5. Update documentation

## 🧪 Testing

### Automated Testing

The project includes comprehensive CI workflows for all supported platforms:

- **macOS**: Latest macOS with Xcode
- **Windows**: Windows Server with Swift toolchain
- **Linux**: Ubuntu with Swift and required libraries

### Manual Testing

```bash
# Test platform detection
peekaboo list server-status

# Test screen capture
peekaboo image --mode screen

# Test application listing
peekaboo list apps

# Test window capture
peekaboo image --app "YourApp" --mode window
```

## 📚 API Reference

### Command Line Interface

#### Global Options
- `--json-output`: Output results in JSON format

#### Image Command
- `--app <identifier>`: Target application identifier
- `--mode <mode>`: Capture mode (screen, window, multi, frontmost)
- `--path <path>`: Output directory path
- `--format <format>`: Image format (png, jpg)
- `--window-title <title>`: Specific window title to capture
- `--window-index <index>`: Window index to capture
- `--screen-index <index>`: Screen index to capture

#### List Command
- `apps`: List running applications
- `windows --app <identifier>`: List windows for an application
- `server-status`: Show platform capabilities and status

### Platform Capabilities

| Feature | macOS | Windows | Linux |
|---------|-------|---------|-------|
| Screen Capture | ✅ | ✅ | ✅ |
| Window Capture | ✅ | ✅ | ✅ |
| Application Listing | ✅ | ✅ | ✅ |
| Window Management | ✅ | ✅ | ✅ |
| Permission Handling | ✅ | ✅ | ✅ |
| Focus Control | ✅ | ⚠️ | ⚠️ |

✅ Full Support | ⚠️ Limited Support | ❌ Not Supported

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass on all platforms
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **ScreenCaptureKit**: Apple's modern screen capture framework
- **Swift Argument Parser**: Command-line argument parsing
- **Cross-Platform Swift**: The Swift community's cross-platform efforts

## 🔗 Links

- [GitHub Repository](https://github.com/steipete/Peekaboo)
- [Issue Tracker](https://github.com/steipete/Peekaboo/issues)
- [Releases](https://github.com/steipete/Peekaboo/releases)
- [Swift.org](https://swift.org)

---

**Made with ❤️ by [Peter Steinberger](https://github.com/steipete) and the open source community.**

