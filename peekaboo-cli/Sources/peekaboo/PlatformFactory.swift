import Foundation

/// Factory class for creating platform-specific implementations
class PlatformFactory {
    
    /// Current platform detection
    static var currentPlatform: Platform {
        #if os(macOS)
        return .macOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #else
        return .unsupported
        #endif
    }
    
    /// Create a screen capture implementation for the current platform
    static func createScreenCapture() -> ScreenCaptureProtocol {
        switch currentPlatform {
        #if os(macOS)
        case .macOS:
            return macOSScreenCapture()
        #endif
        #if os(Windows)
        case .windows:
            return WindowsScreenCapture()
        #endif
        #if os(Linux)
        case .linux:
            return LinuxScreenCapture()
        #endif
        default:
            fatalError("Screen capture not supported on platform: \(currentPlatform)")
        }
    }
    
    /// Create a window manager implementation for the current platform
    static func createWindowManager() -> WindowManagerProtocol {
        switch currentPlatform {
        #if os(macOS)
        case .macOS:
            return macOSWindowManager()
        #endif
        #if os(Windows)
        case .windows:
            return WindowsWindowManager()
        #endif
        #if os(Linux)
        case .linux:
            return LinuxWindowManager()
        #endif
        default:
            fatalError("Window management not supported on platform: \(currentPlatform)")
        }
    }
    
    /// Create an application finder implementation for the current platform
    static func createApplicationFinder() -> ApplicationFinderProtocol {
        switch currentPlatform {
        #if os(macOS)
        case .macOS:
            return macOSApplicationFinder()
        #endif
        #if os(Windows)
        case .windows:
            return WindowsApplicationFinder()
        #endif
        #if os(Linux)
        case .linux:
            return LinuxApplicationFinder()
        #endif
        default:
            fatalError("Application management not supported on platform: \(currentPlatform)")
        }
    }
    
    /// Create a permissions manager implementation for the current platform
    static func createPermissionsManager() -> PermissionsProtocol {
        switch currentPlatform {
        #if os(macOS)
        case .macOS:
            return macOSPermissions()
        #endif
        #if os(Windows)
        case .windows:
            return WindowsPermissions()
        #endif
        #if os(Linux)
        case .linux:
            return LinuxPermissions()
        #endif
        default:
            fatalError("Permission management not supported on platform: \(currentPlatform)")
        }
    }
    
    /// Check if the current platform is supported
    static func isPlatformSupported() -> Bool {
        return currentPlatform != .unsupported
    }
    
    /// Get platform-specific information
    static func getPlatformInfo() -> PlatformInfo {
        return PlatformInfo(
            platform: currentPlatform,
            version: getPlatformVersion(),
            architecture: getArchitecture(),
            capabilities: getPlatformCapabilities()
        )
    }
    
    /// Get the current platform version
    private static func getPlatformVersion() -> String {
        #if os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #elseif os(Windows)
        // Windows version detection would go here
        return "Unknown"
        #elseif os(Linux)
        // Linux version detection would go here
        return "Unknown"
        #else
        return "Unknown"
        #endif
    }
    
    /// Get the current architecture
    private static func getArchitecture() -> ProcessArchitecture {
        #if arch(x86_64)
        return .x86_64
        #elseif arch(arm64)
        return .arm64
        #elseif arch(i386)
        return .x86
        #else
        return .unknown
        #endif
    }
    
    /// Get platform-specific capabilities
    private static func getPlatformCapabilities() -> PlatformCapabilities {
        switch currentPlatform {
        case .macOS:
            return PlatformCapabilities(
                screenCapture: true,
                windowManagement: true,
                applicationManagement: true,
                permissionManagement: true,
                multiDisplay: true,
                windowComposition: true,
                highDPI: true
            )
        case .windows:
            return PlatformCapabilities(
                screenCapture: true,
                windowManagement: true,
                applicationManagement: true,
                permissionManagement: false, // Windows doesn't require explicit screen recording permission
                multiDisplay: true,
                windowComposition: true,
                highDPI: true
            )
        case .linux:
            return PlatformCapabilities(
                screenCapture: true,
                windowManagement: true,
                applicationManagement: true,
                permissionManagement: true, // Depends on desktop environment
                multiDisplay: true,
                windowComposition: true, // Depends on compositor
                highDPI: true
            )
        case .unsupported:
            return PlatformCapabilities(
                screenCapture: false,
                windowManagement: false,
                applicationManagement: false,
                permissionManagement: false,
                multiDisplay: false,
                windowComposition: false,
                highDPI: false
            )
        }
    }
}

/// Supported platforms
enum Platform: String, CaseIterable {
    case macOS = "macOS"
    case windows = "Windows"
    case linux = "Linux"
    case unsupported = "Unsupported"
    
    var displayName: String {
        return rawValue
    }
}

/// Platform information
struct PlatformInfo {
    let platform: Platform
    let version: String
    let architecture: ProcessArchitecture
    let capabilities: PlatformCapabilities
}

/// Platform capabilities
struct PlatformCapabilities {
    let screenCapture: Bool
    let windowManagement: Bool
    let applicationManagement: Bool
    let permissionManagement: Bool
    let multiDisplay: Bool
    let windowComposition: Bool
    let highDPI: Bool
    
    var allSupported: Bool {
        return screenCapture && windowManagement && applicationManagement
    }
}

