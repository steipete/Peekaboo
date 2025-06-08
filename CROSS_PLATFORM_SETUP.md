# Cross-Platform Setup Guide

Peekaboo now supports **macOS**, **Windows**, and **Linux**! This guide will help you set up and use Peekaboo on your platform.

## 🚀 Quick Start

### macOS
```bash
# Clone and build
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release

# Run
.build/release/peekaboo --help
```

### Linux
```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y swift-lang libx11-dev libxcomposite-dev libxrandr-dev libxfixes-dev imagemagick wmctrl

# Clone and build
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release

# Run
.build/release/peekaboo --help
```

### Windows
```powershell
# Install Swift for Windows (see Swift.org for latest installer)
# Clone and build
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release

# Run
.build/release/peekaboo.exe --help
```

## 📋 Platform Requirements

### macOS
- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** or Swift 6.0+
- **Permissions**: Screen Recording and Accessibility (granted through System Preferences)

### Linux
- **Swift 6.0+**
- **X11 or Wayland** display server
- **Dependencies**:
  - `libx11-dev`, `libxcomposite-dev`, `libxrandr-dev`, `libxfixes-dev` (for X11)
  - `imagemagick` or `scrot` (for screen capture)
  - `wmctrl` or `xwininfo` (for window management)
  - `grim` and `swaymsg` (for Wayland/Sway)

### Windows
- **Windows 10+** (version 1903 or later)
- **Swift 6.0 for Windows**
- **Visual Studio Build Tools** (for compilation)

## 🔧 Installation Instructions

### macOS Installation

1. **Install Xcode or Swift**:
   ```bash
   # Via Xcode (recommended)
   # Download from Mac App Store
   
   # Or via Swift toolchain
   # Download from swift.org
   ```

2. **Grant Permissions**:
   - Go to **System Preferences > Security & Privacy > Privacy**
   - Add Terminal (or your terminal app) to **Screen Recording** and **Accessibility**

3. **Build and Install**:
   ```bash
   git clone https://github.com/steipete/Peekaboo.git
   cd Peekaboo/peekaboo-cli
   swift build -c release
   
   # Optional: Install globally
   sudo cp .build/release/peekaboo /usr/local/bin/
   ```

### Linux Installation

#### Ubuntu/Debian
```bash
# Install Swift
wget https://download.swift.org/swift-6.0-release/ubuntu2204/swift-6.0-RELEASE/swift-6.0-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0-RELEASE-ubuntu22.04 /opt/swift
echo 'export PATH=/opt/swift/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Install dependencies
sudo apt-get update
sudo apt-get install -y \
  libx11-dev \
  libxcomposite-dev \
  libxrandr-dev \
  libxfixes-dev \
  imagemagick \
  wmctrl \
  grim \
  sway

# Build Peekaboo
git clone https://github.com/steipete/Peekaboo.git
cd Peekaboo/peekaboo-cli
swift build -c release

# Optional: Install globally
sudo cp .build/release/peekaboo /usr/local/bin/
```

#### Fedora/RHEL
```bash
# Install Swift (download from swift.org)
# Install dependencies
sudo dnf install -y \
  libX11-devel \
  libXcomposite-devel \
  libXrandr-devel \
  libXfixes-devel \
  ImageMagick \
  wmctrl

# Build as above
```

#### Arch Linux
```bash
# Install from AUR or build Swift from source
yay -S swift-bin

# Install dependencies
sudo pacman -S \
  libx11 \
  libxcomposite \
  libxrandr \
  libxfixes \
  imagemagick \
  wmctrl

# Build as above
```

### Windows Installation

1. **Install Swift for Windows**:
   - Download the latest Swift installer from [swift.org](https://swift.org/download/)
   - Follow the installation instructions
   - Ensure Visual Studio Build Tools are installed

2. **Install Git** (if not already installed):
   - Download from [git-scm.com](https://git-scm.com/)

3. **Build Peekaboo**:
   ```powershell
   git clone https://github.com/steipete/Peekaboo.git
   cd Peekaboo/peekaboo-cli
   swift build -c release
   
   # The binary will be at .build/release/peekaboo.exe
   ```

## 🎯 Usage Examples

### Basic Screen Capture
```bash
# Capture entire screen
peekaboo image --mode screen

# Capture specific screen (multi-monitor)
peekaboo image --mode screen --screen-index 1

# Capture with custom path
peekaboo image --mode screen --path ~/Screenshots/
```

### Window Capture
```bash
# List all applications
peekaboo list apps

# List windows for specific app
peekaboo list windows --app "Safari"

# Capture specific window
peekaboo image --mode window --app "Safari" --window-index 0
```

### Cross-Platform Compatibility
```bash
# These commands work identically on all platforms:
peekaboo image --mode screen --format png
peekaboo image --mode window --app "Firefox"
peekaboo list apps --format json
```

## 🐛 Troubleshooting

### macOS Issues

**Permission Denied**:
- Ensure Screen Recording permission is granted
- Restart terminal after granting permissions
- Check System Preferences > Security & Privacy > Privacy

**ScreenCaptureKit Not Available**:
- Update to macOS 12.3+ for best performance
- Fallback to CGImage will be used automatically

### Linux Issues

**Command Not Found**:
```bash
# Install missing tools
sudo apt-get install imagemagick wmctrl  # Ubuntu/Debian
sudo dnf install ImageMagick wmctrl      # Fedora
```

**X11 Display Issues**:
```bash
# Ensure DISPLAY is set
echo $DISPLAY
export DISPLAY=:0  # if not set
```

**Wayland Limitations**:
- Some features may be limited under Wayland
- Install `grim` and `swaymsg` for Sway
- GNOME Wayland may require additional setup

### Windows Issues

**Swift Not Found**:
- Ensure Swift is in your PATH
- Restart Command Prompt/PowerShell after installation

**Build Errors**:
- Ensure Visual Studio Build Tools are installed
- Try running from "Developer Command Prompt"

**Permission Issues**:
- Run as Administrator if capturing elevated applications
- Check Windows Defender settings

## 🔍 Platform-Specific Features

### macOS
- ✅ ScreenCaptureKit (hardware accelerated)
- ✅ CGImage fallback
- ✅ Retina display support
- ✅ Full window management
- ✅ Application enumeration

### Linux
- ✅ X11 support (XGetImage, wmctrl)
- ✅ Wayland support (grim, swaymsg)
- ✅ Multi-desktop environment support
- ⚠️ Limited Wayland window management

### Windows
- ✅ DXGI Desktop Duplication (planned)
- ✅ GDI+ screen capture
- ✅ Win32 window enumeration
- ✅ Process management
- ⚠️ UAC elevation may be required

## 🚧 Known Limitations

### General
- Window capture on Wayland is limited by compositor support
- Some desktop environments have additional security restrictions

### Platform-Specific
- **macOS**: Requires explicit permission grants
- **Linux**: Tool availability varies by distribution
- **Windows**: May require elevation for some applications

## 🤝 Contributing

Want to improve cross-platform support? Check out:
- `peekaboo-cli/Sources/peekaboo/Platforms/` - Platform implementations
- `peekaboo-cli/Sources/peekaboo/Protocols/` - Cross-platform interfaces
- `.github/workflows/` - CI/CD for all platforms

## 📚 Additional Resources

- [Swift.org Downloads](https://swift.org/download/) - Swift toolchains for all platforms
- [ImageMagick](https://imagemagick.org/) - Cross-platform image manipulation
- [Wayland Documentation](https://wayland.freedesktop.org/) - Linux Wayland support
- [Win32 API Reference](https://docs.microsoft.com/en-us/windows/win32/) - Windows development

---

**Happy screenshotting across all platforms! 🎉**

