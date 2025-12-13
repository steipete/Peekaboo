import CoreGraphics
import Foundation

/// Result of a click operation
public struct ClickResult: Sendable, Codable {
    public let elementDescription: String
    public let location: CGPoint?

    public init(elementDescription: String, location: CGPoint?) {
        self.elementDescription = elementDescription
        self.location = location
    }
}

/// Protocol defining menu interaction operations
@MainActor
public protocol MenuServiceProtocol: Sendable {
    /// List all menus and items for an application
    /// - Parameter appIdentifier: Application name or bundle ID
    /// - Returns: Menu structure information
    func listMenus(for appIdentifier: String) async throws -> MenuStructure

    /// List menus for the frontmost application
    /// - Returns: Menu structure information
    func listFrontmostMenus() async throws -> MenuStructure

    /// Click a menu item
    /// - Parameters:
    ///   - appIdentifier: Application name or bundle ID
    ///   - itemPath: Menu item path (e.g., "File > New" or just "New Window")
    func clickMenuItem(app: String, itemPath: String) async throws

    /// Click a menu item by searching for it recursively in the menu hierarchy
    /// - Parameters:
    ///   - app: Application name or bundle ID
    ///   - itemName: The name of the menu item to click (searches recursively)
    func clickMenuItemByName(app: String, itemName: String) async throws

    /// Click a system menu extra (status bar item)
    /// - Parameter title: Title of the menu extra
    func clickMenuExtra(title: String) async throws

    /// List all system menu extras
    /// - Returns: Array of menu extra information
    func listMenuExtras() async throws -> [MenuExtraInfo]

    /// List all menu bar items (status items) - compatibility method
    /// - Parameter includeRaw: Include raw debug metadata (window/layer/owner) if available.
    /// - Returns: Array of menu bar item information
    func listMenuBarItems(includeRaw: Bool) async throws -> [MenuBarItemInfo]

    /// Click a menu bar item by name - compatibility method
    /// - Parameter name: Name of the menu bar item
    /// - Returns: Click result
    func clickMenuBarItem(named name: String) async throws -> ClickResult

    /// Click a menu bar item by index - compatibility method
    /// - Parameter index: Index of the menu bar item
    /// - Returns: Click result
    func clickMenuBarItem(at index: Int) async throws -> ClickResult
}

/// Structure representing an application's menu bar
public struct MenuStructure: Sendable, Codable {
    /// Application information
    public let application: ServiceApplicationInfo

    /// Top-level menus
    public let menus: [Menu]

    /// Total number of menu items
    public nonisolated var totalItems: Int {
        self.menus.reduce(0) { $0 + $1.totalItems }
    }

    public init(application: ServiceApplicationInfo, menus: [Menu]) {
        self.application = application
        self.menus = menus
    }
}

/// A menu in the menu bar
public struct Menu: Sendable, Codable {
    /// Menu title
    public let title: String

    /// Owning bundle identifier (inherited from application)
    public let bundleIdentifier: String?

    /// Owning application name
    public let ownerName: String?

    /// Menu items
    public let items: [MenuItem]

    /// Whether the menu is enabled
    public let isEnabled: Bool

    /// Total items including submenu items
    public nonisolated var totalItems: Int {
        self.items.reduce(0) { $0 + 1 + $1.totalSubitems }
    }

    public init(
        title: String,
        bundleIdentifier: String? = nil,
        ownerName: String? = nil,
        items: [MenuItem],
        isEnabled: Bool = true)
    {
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.ownerName = ownerName
        self.items = items
        self.isEnabled = isEnabled
    }
}

/// A menu item
public struct MenuItem: Sendable, Codable {
    /// Item title
    public let title: String

    /// Owning bundle identifier
    public let bundleIdentifier: String?

    /// Owning application name
    public let ownerName: String?

    /// Keyboard shortcut if available
    public let keyboardShortcut: KeyboardShortcut?

    /// Whether the item is enabled
    public let isEnabled: Bool

    /// Whether the item is checked/selected
    public let isChecked: Bool

    /// Whether this is a separator
    public let isSeparator: Bool

    /// Submenu items if this is a submenu
    public let submenu: [MenuItem]

    /// Full path to this item (e.g., "File > Recent > Document.txt")
    public let path: String

    /// Total subitems in submenu
    public nonisolated var totalSubitems: Int {
        self.submenu.reduce(0) { $0 + 1 + $1.totalSubitems }
    }

    public init(
        title: String,
        bundleIdentifier: String? = nil,
        ownerName: String? = nil,
        keyboardShortcut: KeyboardShortcut? = nil,
        isEnabled: Bool = true,
        isChecked: Bool = false,
        isSeparator: Bool = false,
        submenu: [MenuItem] = [],
        path: String)
    {
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.ownerName = ownerName
        self.keyboardShortcut = keyboardShortcut
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.isSeparator = isSeparator
        self.submenu = submenu
        self.path = path
    }
}

/// Keyboard shortcut information
public struct KeyboardShortcut: Sendable, Codable {
    /// Modifier keys (cmd, shift, option, ctrl)
    public let modifiers: Set<String>

    /// Main key
    public let key: String

    /// Display string (e.g., "⌘C")
    public let displayString: String

    public init(modifiers: Set<String>, key: String, displayString: String) {
        self.modifiers = modifiers
        self.key = key
        self.displayString = displayString
    }
}

/// Information about a menu bar item (status bar item)
public struct MenuBarItemInfo: Sendable, Codable {
    /// Title to surface to users
    public let title: String?

    /// Original raw title reported by the system (Item-0, etc.)
    public let rawTitle: String?

    /// Owning bundle identifier, if known
    public let bundleIdentifier: String?

    /// Owning application name or owner string
    public let ownerName: String?

    /// Index in the menu bar
    public let index: Int

    /// Whether it's currently visible
    public let isVisible: Bool

    /// Optional description
    public let description: String?

    /// Bounding rectangle in screen coordinates, if available
    public let frame: CGRect?

    /// Accessibility identifier or other stable identifier if available.
    public let identifier: String?

    /// AXIdentifier, if available from accessibility traversal.
    public let axIdentifier: String?

    /// AXDescription or help text, if available.
    public let axDescription: String?

    /// Raw window ID (CGS/CGWindow) if requested for debugging.
    public let rawWindowID: CGWindowID?

    /// Raw window layer if available (e.g., 24/25 for menu extras).
    public let rawWindowLayer: Int?

    /// Owning process ID for the backing window, if known.
    public let rawOwnerPID: pid_t?

    /// Source used to collect the item (e.g., "cgs", "cgwindow", "ax-control-center").
    public let rawSource: String?

    public init(
        title: String?,
        index: Int,
        isVisible: Bool = true,
        description: String? = nil,
        rawTitle: String? = nil,
        bundleIdentifier: String? = nil,
        ownerName: String? = nil,
        frame: CGRect? = nil,
        identifier: String? = nil,
        axIdentifier: String? = nil,
        axDescription: String? = nil,
        rawWindowID: CGWindowID? = nil,
        rawWindowLayer: Int? = nil,
        rawOwnerPID: pid_t? = nil,
        rawSource: String? = nil)
    {
        self.title = title
        self.rawTitle = rawTitle
        self.bundleIdentifier = bundleIdentifier
        self.ownerName = ownerName
        self.index = index
        self.isVisible = isVisible
        self.description = description
        self.frame = frame
        self.identifier = identifier
        self.axIdentifier = axIdentifier
        self.axDescription = axDescription
        self.rawWindowID = rawWindowID
        self.rawWindowLayer = rawWindowLayer
        self.rawOwnerPID = rawOwnerPID
        self.rawSource = rawSource
    }
}

/// Information about a system menu extra (status bar item)
public struct MenuExtraInfo: Sendable, Codable {
    /// Display title chosen for automation clients (maybe localized/humanized).
    public let title: String

    /// Raw title reported by the OS (may be generic like Item-0).
    public let rawTitle: String?

    /// The owning bundle identifier for the extra, if known.
    public let bundleIdentifier: String?

    /// The owning application name, if available.
    public let ownerName: String?

    /// Position in the menu bar
    public let position: CGPoint

    /// Whether it's currently visible
    public let isVisible: Bool

    /// Optional accessibility identifier for the extra, if known.
    public let identifier: String?

    /// Raw CGWindow ID backing the menu extra if available.
    public let windowID: CGWindowID?

    /// Raw window layer (e.g., 24/25) if available.
    public let windowLayer: Int?

    /// Owning process ID backing the menu extra, if known.
    public let ownerPID: pid_t?

    /// Source used to collect the item (cgs, cgwindow, ax-control-center, ax-menubar).
    public let source: String?

    public init(
        title: String,
        rawTitle: String? = nil,
        bundleIdentifier: String? = nil,
        ownerName: String? = nil,
        position: CGPoint,
        isVisible: Bool = true,
        identifier: String? = nil,
        windowID: CGWindowID? = nil,
        windowLayer: Int? = nil,
        ownerPID: pid_t? = nil,
        source: String? = nil)
    {
        self.title = title
        self.rawTitle = rawTitle
        self.bundleIdentifier = bundleIdentifier
        self.ownerName = ownerName
        self.position = position
        self.isVisible = isVisible
        self.identifier = identifier
        self.windowID = windowID
        self.windowLayer = windowLayer
        self.ownerPID = ownerPID
        self.source = source
    }
}
