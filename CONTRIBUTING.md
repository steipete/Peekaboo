# Contributing to Peekaboo

Thank you for your interest in contributing to Peekaboo! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

#### All Platforms
- Git
- Swift 5.10 or later

#### macOS
- Xcode 15.0 or later
- macOS 14.0 or later

#### Windows
- Swift for Windows toolchain
- Windows 10 or later
- Visual Studio Build Tools (recommended)

#### Linux
- Swift 5.10 or later
- X11 development libraries:
  ```bash
  # Ubuntu/Debian
  sudo apt-get install libx11-dev libxcomposite-dev libxrandr-dev libxdamage-dev libxfixes-dev libwayland-dev pkg-config
  
  # Fedora/RHEL
  sudo dnf install libX11-devel libXcomposite-devel libXrandr-devel libXdamage-devel libXfixes-devel wayland-devel pkgconfig
  ```

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Peekaboo.git
   cd Peekaboo
   ```

2. **Build the Project**
   ```bash
   cd peekaboo-cli
   swift build
   ```

3. **Run Tests**
   ```bash
   swift test
   ```

4. **Test CLI Functionality**
   ```bash
   swift run peekaboo --help
   ```

## 🏗️ Project Structure

```
Peekaboo/
├── peekaboo-cli/                 # Main Swift package
│   ├── Sources/peekaboo/         # Source code
│   │   ├── Commands/             # CLI commands
│   │   ├── Platforms/            # Platform-specific implementations
│   │   │   ├── macOS/            # macOS implementations
│   │   │   ├── Windows/          # Windows implementations
│   │   │   └── Linux/            # Linux implementations
│   │   ├── Protocols/            # Cross-platform protocols
│   │   ├── Models.swift          # Data models
│   │   └── PlatformFactory.swift # Platform abstraction
│   ├── Tests/                    # Test files
│   └── Package.swift             # Swift package manifest
├── .github/                      # GitHub workflows and actions
├── scripts/                      # Installation scripts
├── FEATURE_PARITY_AUDIT.md      # Platform feature comparison
└── README.md                     # Project documentation
```

## 🎯 Contributing Guidelines

### Code Style

1. **Swift Style**
   - Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
   - Use 4 spaces for indentation
   - Maximum line length: 120 characters
   - Use meaningful variable and function names

2. **Platform-Specific Code**
   - Use `#if os(macOS)`, `#if os(Windows)`, `#if os(Linux)` for platform-specific code
   - Keep platform-specific implementations in their respective directories
   - Maintain consistent interfaces across platforms

3. **Error Handling**
   - Use Swift's error handling mechanisms (`throws`, `try`, `catch`)
   - Provide meaningful error messages
   - Use the `ScreenCaptureError` enum for capture-related errors

### Testing

1. **Unit Tests**
   - Write tests for all new functionality
   - Test platform-specific code on the target platform
   - Use descriptive test names: `testCrossplatformScreenCapture()`

2. **Integration Tests**
   - Test end-to-end functionality
   - May be skipped in CI environments without displays
   - Use `XCTSkip` for environment-dependent tests

3. **Performance Tests**
   - Include performance tests for critical operations
   - Use `measure` blocks for timing tests
   - Document expected performance characteristics

### Platform-Specific Contributions

#### macOS Contributions
- Test on both Intel and Apple Silicon Macs
- Ensure compatibility with macOS 14.0+
- Use ScreenCaptureKit when available, CGImage as fallback
- Handle Screen Recording permissions properly

#### Windows Contributions
- Test on Windows 10 and 11
- Use DXGI Desktop Duplication API for screen capture
- Handle UAC elevation when necessary
- Ensure proper COM initialization/cleanup

#### Linux Contributions
- Test on both X11 and Wayland (when possible)
- Handle different display server protocols
- Test on major distributions (Ubuntu, Fedora, etc.)
- Manage X11 library dependencies properly

### Pull Request Process

1. **Before Starting**
   - Check existing issues and PRs to avoid duplication
   - Create an issue for significant changes
   - Discuss architectural changes before implementation

2. **Development**
   - Create a feature branch: `git checkout -b feature/your-feature-name`
   - Make atomic commits with clear messages
   - Keep PRs focused and reasonably sized

3. **Testing**
   - Ensure all tests pass on your platform
   - Add tests for new functionality
   - Test on multiple platforms when possible

4. **Documentation**
   - Update README.md if adding user-facing features
   - Update FEATURE_PARITY_AUDIT.md for platform-specific changes
   - Add inline documentation for complex code

5. **Submission**
   - Push to your fork: `git push origin feature/your-feature-name`
   - Create a pull request with a clear description
   - Link to related issues
   - Be responsive to review feedback

### Commit Message Format

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(windows): add DXGI screen capture implementation
fix(macos): handle permission denial gracefully
docs: update cross-platform installation instructions
test(linux): add X11 integration tests
```

## 🐛 Bug Reports

When reporting bugs, please include:

1. **Environment Information**
   - Operating system and version
   - Swift version
   - Peekaboo version

2. **Steps to Reproduce**
   - Clear, numbered steps
   - Expected vs actual behavior
   - Screenshots if applicable

3. **Error Messages**
   - Full error output
   - Stack traces if available
   - Log files if relevant

4. **Additional Context**
   - Display configuration (multi-monitor, scaling, etc.)
   - Security software that might interfere
   - Other relevant system information

## 💡 Feature Requests

For feature requests:

1. **Check Existing Issues**
   - Search for similar requests
   - Comment on existing issues rather than creating duplicates

2. **Provide Context**
   - Describe the use case
   - Explain why the feature would be valuable
   - Consider cross-platform implications

3. **Implementation Ideas**
   - Suggest possible approaches
   - Consider platform-specific requirements
   - Think about backward compatibility

## 🔧 Development Tips

### Platform Testing

1. **Local Testing**
   ```bash
   # Run platform-specific tests
   swift test --filter macOSTests     # macOS only
   swift test --filter WindowsTests   # Windows only
   swift test --filter LinuxTests     # Linux only
   ```

2. **Cross-Platform Validation**
   - Use GitHub Actions for automated testing
   - Test on virtual machines when possible
   - Coordinate with other contributors for platform testing

### Debugging

1. **Enable Verbose Logging**
   ```bash
   swift run peekaboo capture-screen --verbose
   ```

2. **Platform-Specific Debugging**
   - macOS: Use Instruments for performance analysis
   - Windows: Use Visual Studio debugger
   - Linux: Use GDB or LLDB

### Performance Considerations

1. **Memory Management**
   - Be mindful of image memory usage
   - Clean up resources promptly
   - Use autoreleasing pools on macOS when needed

2. **Threading**
   - Use async/await for I/O operations
   - Keep UI operations on main thread (when applicable)
   - Consider platform-specific threading models

## 📚 Resources

- [Swift Documentation](https://swift.org/documentation/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [macOS ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Windows DXGI](https://docs.microsoft.com/en-us/windows/win32/direct3ddxgi/d3d10-graphics-programming-guide-dxgi)
- [X11 Programming](https://www.x.org/releases/current/doc/)
- [Wayland Documentation](https://wayland.freedesktop.org/docs/html/)

## 🤝 Community

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Requests**: Code contributions and reviews

## 📄 License

By contributing to Peekaboo, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Peekaboo! 🎉

