import Foundation

/// Factory for creating platform-specific implementations
struct PlatformFactory: Sendable {
    
    /// Creates a screen capture implementation for the current platform
    static func createScreenCapture() -> any ScreenCaptureProtocol {
        #if os(macOS)
        return macOSScreenCapture()
        #elseif os(Windows)
        return WindowsScreenCapture()
        #elseif os(Linux)
        return LinuxScreenCapture()
        #else
        fatalError("Unsupported platform for screen capture")
        #endif
    }
    
    /// Creates a window manager implementation for the current platform
    static func createWindowManager() -> any WindowManagerProtocol {
        #if os(macOS)
        return macOSWindowManager()
        #elseif os(Windows)
        return WindowsWindowManager()
        #elseif os(Linux)
        return LinuxWindowManager()
        #else
        fatalError("Unsupported platform for window management")
        #endif
    }
    
    /// Creates an application finder implementation for the current platform
    static func createApplicationFinder() -> any ApplicationFinderProtocol {
        #if os(macOS)
        return macOSApplicationFinder()
        #elseif os(Windows)
        return WindowsApplicationFinder()
        #elseif os(Linux)
        return LinuxApplicationFinder()
        #else
        fatalError("Unsupported platform for application finding")
        #endif
    }
    
    /// Creates a permissions checker implementation for the current platform
    static func createPermissionsChecker() -> any PermissionsProtocol {
        #if os(macOS)
        return macOSPermissions()
        #elseif os(Windows)
        return WindowsPermissions()
        #elseif os(Linux)
        return LinuxPermissions()
        #else
        fatalError("Unsupported platform for permissions")
        #endif
    }
    
    /// Gets the current platform name
    static var currentPlatform: String {
        #if os(macOS)
        return "macOS"
        #elseif os(Windows)
        return "Windows"
        #elseif os(Linux)
        return "Linux"
        #else
        return "Unknown"
        #endif
    }
    
    /// Checks if the current platform is supported
    static var isSupported: Bool {
        #if os(macOS) || os(Windows) || os(Linux)
        return true
        #else
        return false
        #endif
    }
    
    /// Gets platform capabilities
    static var capabilities: PlatformCapabilities {
        return PlatformCapabilities(
            screenCapture: {
                #if os(macOS)
                return macOSScreenCapture.isSupported()
                #elseif os(Windows)
                return WindowsScreenCapture.isSupported()
                #elseif os(Linux)
                return LinuxScreenCapture.isSupported()
                #else
                return false
                #endif
            }(),
            windowManagement: {
                #if os(macOS)
                return macOSWindowManager.isSupported()
                #elseif os(Windows)
                return WindowsWindowManager.isSupported()
                #elseif os(Linux)
                return LinuxWindowManager.isSupported()
                #else
                return false
                #endif
            }(),
            applicationFinding: {
                #if os(macOS)
                return macOSApplicationFinder.isSupported()
                #elseif os(Windows)
                return WindowsApplicationFinder.isSupported()
                #elseif os(Linux)
                return LinuxApplicationFinder.isSupported()
                #else
                return false
                #endif
            }(),
            permissions: {
                #if os(macOS)
                return macOSPermissions.isSupported()
                #elseif os(Windows)
                return WindowsPermissions.isSupported()
                #elseif os(Linux)
                return LinuxPermissions.isSupported()
                #else
                return false
                #endif
            }()
        )
    }
}

/// Platform capabilities structure
struct PlatformCapabilities: Sendable, Codable {
    let screenCapture: Bool
    let windowManagement: Bool
    let applicationFinding: Bool
    let permissions: Bool
    
    var isFullySupported: Bool {
        return screenCapture && windowManagement && applicationFinding && permissions
    }
}

