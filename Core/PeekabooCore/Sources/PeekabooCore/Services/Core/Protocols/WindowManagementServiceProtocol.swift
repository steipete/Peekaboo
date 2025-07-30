import CoreGraphics
import Foundation

/// Protocol defining window management operations
@MainActor
public protocol WindowManagementServiceProtocol: Sendable {
    /// Close a window
    /// - Parameters:
    ///   - target: Window targeting options
    func closeWindow(target: WindowTarget) async throws

    /// Minimize a window
    /// - Parameters:
    ///   - target: Window targeting options
    func minimizeWindow(target: WindowTarget) async throws

    /// Maximize/zoom a window
    /// - Parameters:
    ///   - target: Window targeting options
    func maximizeWindow(target: WindowTarget) async throws

    /// Move a window to specific coordinates
    /// - Parameters:
    ///   - target: Window targeting options
    ///   - position: New position for the window
    func moveWindow(target: WindowTarget, to position: CGPoint) async throws

    /// Resize a window
    /// - Parameters:
    ///   - target: Window targeting options
    ///   - size: New size for the window
    func resizeWindow(target: WindowTarget, to size: CGSize) async throws

    /// Set window bounds (position and size)
    /// - Parameters:
    ///   - target: Window targeting options
    ///   - bounds: New bounds for the window
    func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws

    /// Focus/activate a window
    /// - Parameters:
    ///   - target: Window targeting options
    func focusWindow(target: WindowTarget) async throws

    /// List all windows matching the target
    /// - Parameters:
    ///   - target: Window targeting options
    /// - Returns: Array of window information
    func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo]

    /// Get the currently focused window
    /// - Returns: Window information if a window is focused
    func getFocusedWindow() async throws -> ServiceWindowInfo?
}

/// Options for targeting a window
public enum WindowTarget: Sendable, CustomStringConvertible {
    /// Target by application name or bundle ID
    case application(String)

    /// Target by window title (substring match)
    case title(String)

    /// Target by application and window index
    case index(app: String, index: Int)

    /// Target the frontmost window
    case frontmost

    /// Target a specific window ID
    case windowId(Int)

    public var description: String {
        switch self {
        case let .application(app):
            "application(\(app))"
        case let .title(title):
            "title(\(title))"
        case let .index(app, index):
            "index(app: \(app), index: \(index))"
        case .frontmost:
            "frontmost"
        case let .windowId(id):
            "windowId(\(id))"
        }
    }
}

/// Result of a window operation
public struct WindowOperationResult: Sendable {
    /// Whether the operation succeeded
    public let success: Bool

    /// Window state after the operation
    public let windowInfo: ServiceWindowInfo?

    /// Any warnings or notes
    public let message: String?

    public init(success: Bool, windowInfo: ServiceWindowInfo? = nil, message: String? = nil) {
        self.success = success
        self.windowInfo = windowInfo
        self.message = message
    }
}
