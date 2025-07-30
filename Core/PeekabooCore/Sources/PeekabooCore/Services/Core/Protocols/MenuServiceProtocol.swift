import CoreGraphics
import Foundation

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
}

/// Structure representing an application's menu bar
public struct MenuStructure: Sendable {
    /// Application information
    public let application: ServiceApplicationInfo

    /// Top-level menus
    public let menus: [Menu]

    /// Total number of menu items
    public var totalItems: Int {
        self.menus.reduce(0) { $0 + $1.totalItems }
    }

    public init(application: ServiceApplicationInfo, menus: [Menu]) {
        self.application = application
        self.menus = menus
    }
}

/// A menu in the menu bar
public struct Menu: Sendable {
    /// Menu title
    public let title: String

    /// Menu items
    public let items: [MenuItem]

    /// Whether the menu is enabled
    public let isEnabled: Bool

    /// Total items including submenu items
    public var totalItems: Int {
        self.items.reduce(0) { $0 + 1 + $1.totalSubitems }
    }

    public init(title: String, items: [MenuItem], isEnabled: Bool = true) {
        self.title = title
        self.items = items
        self.isEnabled = isEnabled
    }
}

/// A menu item
public struct MenuItem: Sendable {
    /// Item title
    public let title: String

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
    public var totalSubitems: Int {
        self.submenu.reduce(0) { $0 + 1 + $1.totalSubitems }
    }

    public init(
        title: String,
        keyboardShortcut: KeyboardShortcut? = nil,
        isEnabled: Bool = true,
        isChecked: Bool = false,
        isSeparator: Bool = false,
        submenu: [MenuItem] = [],
        path: String)
    {
        self.title = title
        self.keyboardShortcut = keyboardShortcut
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.isSeparator = isSeparator
        self.submenu = submenu
        self.path = path
    }
}

/// Keyboard shortcut information
public struct KeyboardShortcut: Sendable {
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

/// Information about a system menu extra (status bar item)
public struct MenuExtraInfo: Sendable {
    /// Title of the menu extra
    public let title: String

    /// Position in the menu bar
    public let position: CGPoint

    /// Whether it's currently visible
    public let isVisible: Bool

    public init(title: String, position: CGPoint, isVisible: Bool = true) {
        self.title = title
        self.position = position
        self.isVisible = isVisible
    }
}
