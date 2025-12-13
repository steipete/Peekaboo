import AppKit
import CoreGraphics
import Foundation

/// Protocol defining application and window management operations
@MainActor
public protocol ApplicationServiceProtocol: Sendable {
    /// List all running applications
    /// - Returns: UnifiedToolOutput containing application information
    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData>

    /// Find an application by name or bundle ID
    /// - Parameter identifier: Application name or bundle ID (supports fuzzy matching)
    /// - Returns: Application information if found
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo

    /// List all windows for a specific application
    /// - Parameters:
    ///   - appIdentifier: Application name or bundle ID
    ///   - timeout: Optional timeout in seconds (defaults to 2 seconds)
    /// - Returns: UnifiedToolOutput containing window information
    func listWindows(for appIdentifier: String, timeout: Float?) async throws
        -> UnifiedToolOutput<ServiceWindowListData>

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
        windowCount: Int = 0)
    {
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
public enum WindowSharingState: Int, Codable, Sendable {
    case none = 0
    case readOnly = 1
    case readWrite = 2
}

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

    /// Screen index (position in NSScreen.screens array)
    public let screenIndex: Int?

    /// Screen name (e.g., "Built-in Display", "LG UltraFine")
    public let screenName: String?

    /// Whether the window is off-screen
    public let isOffScreen: Bool

    /// CG window layer (0 == standard app window)
    public let layer: Int

    /// Whether CoreGraphics reports the window as on-screen
    public let isOnScreen: Bool

    /// Sharing state exposed by AppKit/CoreGraphics
    public let sharingState: WindowSharingState?

    /// Whether our own NSWindow asked to hide from the Windows menu
    public let isExcludedFromWindowsMenu: Bool

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
        spaceName: String? = nil,
        screenIndex: Int? = nil,
        screenName: String? = nil,
        layer: Int = 0,
        isOnScreen: Bool = true,
        sharingState: WindowSharingState? = nil,
        isExcludedFromWindowsMenu: Bool = false)
    {
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
        self.screenIndex = screenIndex
        self.screenName = screenName
        self.isOffScreen = !NSScreen.screens.contains { screen in
            screen.frame.intersects(bounds)
        }
        self.layer = layer
        self.isOnScreen = isOnScreen
        self.sharingState = sharingState
        self.isExcludedFromWindowsMenu = isExcludedFromWindowsMenu
    }

    public var isShareableWindow: Bool {
        guard let sharingState else {
            return true
        }
        return sharingState != .none
    }
}
