import CoreGraphics
import Foundation

/// Protocol defining Dock interaction operations
@MainActor
public protocol DockServiceProtocol: Sendable {
    /// List all items in the Dock
    /// - Parameter includeAll: Include separators and spacers
    /// - Returns: Array of Dock items
    func listDockItems(includeAll: Bool) async throws -> [DockItem]

    /// Launch an application from the Dock
    /// - Parameter appName: Name of the application in the Dock
    func launchFromDock(appName: String) async throws

    /// Add an item to the Dock
    /// - Parameters:
    ///   - path: Path to the application or folder to add
    ///   - persistent: Whether to add as persistent item (default true)
    func addToDock(path: String, persistent: Bool) async throws

    /// Remove an item from the Dock
    /// - Parameter appName: Name of the application to remove
    func removeFromDock(appName: String) async throws

    /// Right-click a Dock item and optionally select from context menu
    /// - Parameters:
    ///   - appName: Name of the application in the Dock
    ///   - menuItem: Optional menu item to select from context menu
    func rightClickDockItem(appName: String, menuItem: String?) async throws

    /// Hide the Dock (enable auto-hide)
    func hideDock() async throws

    /// Show the Dock (disable auto-hide)
    func showDock() async throws

    /// Get current Dock visibility state
    /// - Returns: True if Dock is auto-hidden
    func isDockAutoHidden() async -> Bool

    /// Find a specific Dock item by name
    /// - Parameter name: Name or partial name of the item
    /// - Returns: Dock item if found
    func findDockItem(name: String) async throws -> DockItem
}

/// Information about a Dock item
public struct DockItem: Sendable, Codable, Equatable {
    /// Zero-based index in the Dock
    public let index: Int

    /// Display title of the item
    public let title: String

    /// Type of Dock item
    public let itemType: DockItemType

    /// Whether the application is currently running (for app items)
    public let isRunning: Bool?

    /// Bundle identifier (for applications)
    public let bundleIdentifier: String?

    /// Position in screen coordinates
    public let position: CGPoint?

    /// Size of the Dock item
    public let size: CGSize?

    public init(
        index: Int,
        title: String,
        itemType: DockItemType,
        isRunning: Bool? = nil,
        bundleIdentifier: String? = nil,
        position: CGPoint? = nil,
        size: CGSize? = nil)
    {
        self.index = index
        self.title = title
        self.itemType = itemType
        self.isRunning = isRunning
        self.bundleIdentifier = bundleIdentifier
        self.position = position
        self.size = size
    }
}

/// Type of Dock item
public enum DockItemType: String, Sendable, Codable {
    case application
    case folder
    case file
    case url
    case separator
    case spacer
    case minimizedWindow = "minimized_window"
    case trash
    case unknown
}
