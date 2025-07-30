import Foundation
import CoreGraphics

/// Protocol defining application and window management operations
@MainActor
public protocol ApplicationServiceProtocol: Sendable {
    /// List all running applications
    /// - Returns: Array of application information
    func listApplications() async throws -> [ServiceApplicationInfo]
    
    /// Find an application by name or bundle ID
    /// - Parameter identifier: Application name or bundle ID (supports fuzzy matching)
    /// - Returns: Application information if found
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo
    
    /// List all windows for a specific application
    /// - Parameter appIdentifier: Application name or bundle ID
    /// - Returns: Array of window information
    func listWindows(for appIdentifier: String) async throws -> [ServiceWindowInfo]
    
    /// Get information about the frontmost application
    /// - Returns: Application information
    func getFrontmostApplication() async throws -> ServiceApplicationInfo
    
    /// Check if an application is running
    /// - Parameter identifier: Application name or bundle ID
    /// - Returns: True if the application is running
    func isApplicationRunning(identifier: String) async -> Bool
    
    /// Launch an application
    /// - Parameter identifier: Application name or bundle ID
    /// - Returns: Application information after launch
    func launchApplication(identifier: String) async throws -> ServiceApplicationInfo
    
    /// Activate (bring to front) an application
    /// - Parameter identifier: Application name or bundle ID
    func activateApplication(identifier: String) async throws
    
    /// Quit an application
    /// - Parameters:
    ///   - identifier: Application name or bundle ID
    ///   - force: Force quit without saving
    /// - Returns: True if the application was successfully quit
    func quitApplication(identifier: String, force: Bool) async throws -> Bool
    
    /// Hide an application
    /// - Parameter identifier: Application name or bundle ID
    func hideApplication(identifier: String) async throws
    
    /// Unhide an application
    /// - Parameter identifier: Application name or bundle ID
    func unhideApplication(identifier: String) async throws
    
    /// Hide all other applications
    /// - Parameter identifier: Application to keep visible
    func hideOtherApplications(identifier: String) async throws
    
    /// Show all hidden applications
    func showAllApplications() async throws
}

/// Information about an application for service layer
public struct ServiceApplicationInfo: Sendable, Codable, Equatable {
    /// Process identifier
    public let processIdentifier: Int32
    
    /// Bundle identifier (e.g., "com.apple.Safari")
    public let bundleIdentifier: String?
    
    /// Application name
    public let name: String
    
    /// Path to the application bundle
    public let bundlePath: String?
    
    /// Whether the application is currently active (frontmost)
    public let isActive: Bool
    
    /// Whether the application is hidden
    public let isHidden: Bool
    
    /// Number of windows
    public var windowCount: Int
    
    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        name: String,
        bundlePath: String? = nil,
        isActive: Bool = false,
        isHidden: Bool = false,
        windowCount: Int = 0
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.bundlePath = bundlePath
        self.isActive = isActive
        self.isHidden = isHidden
        self.windowCount = windowCount
    }
}

/// Information about a window for service layer
public struct ServiceWindowInfo: Sendable, Codable, Equatable {
    /// Window identifier
    public let windowID: Int
    
    /// Window title
    public let title: String
    
    /// Window bounds in screen coordinates
    public let bounds: CGRect
    
    /// Whether the window is minimized
    public let isMinimized: Bool
    
    /// Whether the window is the main window
    public let isMainWindow: Bool
    
    /// Window level (z-order)
    public let windowLevel: Int
    
    /// Alpha value (transparency)
    public let alpha: CGFloat
    
    /// Window index within the application (0 = frontmost)
    public let index: Int
    
    /// Space (virtual desktop) ID this window belongs to
    public let spaceID: UInt64?
    
    /// Human-readable name of the Space (if available)
    public let spaceName: String?
    
    public init(
        windowID: Int,
        title: String,
        bounds: CGRect,
        isMinimized: Bool = false,
        isMainWindow: Bool = false,
        windowLevel: Int = 0,
        alpha: CGFloat = 1.0,
        index: Int = 0,
        spaceID: UInt64? = nil,
        spaceName: String? = nil
    ) {
        self.windowID = windowID
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.isMainWindow = isMainWindow
        self.windowLevel = windowLevel
        self.alpha = alpha
        self.index = index
        self.spaceID = spaceID
        self.spaceName = spaceName
    }
}