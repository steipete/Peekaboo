# Cross-Platform Architecture for Peekaboo

## Overview

This document outlines the architecture for making Peekaboo cross-platform, supporting macOS, Windows, and Linux while maintaining a unified CLI interface and preserving all existing functionality.

## Architecture Principles

1. **Protocol-Based Design**: Use Swift protocols to define common interfaces for screen capture, window management, and application discovery
2. **Platform Factory Pattern**: A factory class determines the current platform and returns appropriate implementations
3. **Conditional Compilation**: Use Swift's `#if` directives for platform-specific code
4. **API Preservation**: Maintain identical CLI interface across all platforms
5. **Performance Parity**: Ensure cross-platform implementations match macOS performance

## Platform-Specific Technologies

### macOS (Current)
- **Screen Capture**: ScreenCaptureKit (macOS 14+), fallback to CoreGraphics
- **Window Management**: AppKit, CoreGraphics Window Services
- **Application Discovery**: NSWorkspace, NSRunningApplication
- **Permissions**: Accessibility API, Screen Recording permissions

### Windows (New)
- **Screen Capture**: 
  - Primary: DXGI Desktop Duplication API (Windows 8+)
  - Fallback: GDI+ BitBlt (Windows 7+)
  - Modern: Windows.Graphics.Capture API (Windows 10 1903+)
- **Window Management**: Win32 API (EnumWindows, GetWindowInfo, GetWindowRect)
- **Application Discovery**: Process32First/Next, GetModuleFileNameEx
- **Permissions**: UAC elevation for some operations, no explicit screen recording permission

### Linux (New)
- **Screen Capture**:
  - X11: XGetImage, XComposite extension
  - Wayland: wlr-screencopy protocol, xdg-desktop-portal
- **Window Management**: 
  - X11: XQueryTree, XGetWindowProperty
  - Wayland: Compositor-specific protocols
- **Application Discovery**: /proc filesystem, .desktop files
- **Permissions**: Varies by desktop environment (GNOME requires portal permissions)

## Protocol Definitions

### ScreenCaptureProtocol
```swift
protocol ScreenCaptureProtocol {
    func captureScreen(displayIndex: Int?) async throws -> CGImage
    func captureWindow(windowId: UInt32) async throws -> CGImage
    func captureApplication(pid: pid_t, windowIndex: Int?) async throws -> [CGImage]
    func getAvailableDisplays() throws -> [DisplayInfo]
}
```

### WindowManagerProtocol
```swift
protocol WindowManagerProtocol {
    func getWindowsForApp(pid: pid_t) throws -> [WindowData]
    func getWindowInfo(windowId: UInt32) throws -> WindowData?
    func getAllWindows() throws -> [WindowData]
}
```

### ApplicationFinderProtocol
```swift
protocol ApplicationFinderProtocol {
    func findApplication(identifier: String) throws -> RunningApplication
    func getRunningApplications() -> [RunningApplication]
    func activateApplication(pid: pid_t) throws
}
```

### PermissionsProtocol
```swift
protocol PermissionsProtocol {
    func checkScreenCapturePermission() -> Bool
    func checkWindowAccessPermission() -> Bool
    func requestPermissions() throws
}
```

## Platform Factory

The `PlatformFactory` class detects the current operating system and returns appropriate implementations:

```swift
class PlatformFactory {
    static func createScreenCapture() -> ScreenCaptureProtocol {
        #if os(macOS)
        return macOSScreenCapture()
        #elseif os(Windows)
        return WindowsScreenCapture()
        #elseif os(Linux)
        return LinuxScreenCapture()
        #endif
    }
    
    // Similar methods for other protocols...
}
```

## Implementation Strategy

### Phase 1: Foundation
1. Create protocol definitions
2. Update Package.swift for multi-platform support
3. Implement platform factory
4. Create basic platform detection

### Phase 2: Platform Implementations
1. Refactor macOS code to use protocols
2. Implement Windows platform support
3. Implement Linux platform support
4. Add platform-specific error handling

### Phase 3: Integration & Testing
1. Update CLI commands to use platform factory
2. Create comprehensive test suites
3. Set up cross-platform CI/CD
4. Performance testing and optimization

### Phase 4: Distribution
1. Update documentation
2. Create platform-specific build scripts
3. Update npm package for multi-platform binaries
4. Release and distribution

## Error Handling Strategy

Each platform will have its own error types that map to common `CaptureError` cases:

- **Permission Errors**: Map platform-specific permission failures
- **Not Found Errors**: Standardize application/window not found errors
- **Capture Failures**: Handle platform-specific capture API failures
- **System Errors**: Map OS-specific system errors to common types

## Performance Considerations

- **Async/Await**: Use Swift's async/await for all capture operations
- **Memory Management**: Proper CGImage lifecycle management across platforms
- **Caching**: Cache window lists and application information when appropriate
- **Fallback Strategies**: Implement fallback capture methods for older systems

## Testing Strategy

- **Unit Tests**: Test each protocol implementation independently
- **Integration Tests**: Test CLI interface with all platform backends
- **Mock Implementations**: Create mock platforms for CI environments
- **Performance Tests**: Ensure capture speed meets requirements
- **Cross-Platform Tests**: Verify identical behavior across platforms

## Future Considerations

- **Additional Platforms**: Framework designed to easily add new platforms
- **API Evolution**: Protocol-based design allows for easy API extensions
- **Performance Optimization**: Platform-specific optimizations without breaking interface
- **Feature Parity**: Ensure new features work across all supported platforms

