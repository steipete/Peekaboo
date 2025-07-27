import Foundation
import CoreGraphics

/// UI automation session data for storing screen state and element information
public struct UIAutomationSession: Codable, Sendable {
    public static let currentVersion = 5
    
    public let version: Int
    public var screenshotPath: String?
    public var annotatedPath: String?
    public var uiMap: [String: UIElement]
    public var lastUpdateTime: Date
    public var applicationName: String?
    public var windowTitle: String?
    public var windowBounds: CGRect?
    public var menuBar: MenuBarData?
    
    public init(
        version: Int = UIAutomationSession.currentVersion,
        screenshotPath: String? = nil,
        annotatedPath: String? = nil,
        uiMap: [String: UIElement] = [:],
        lastUpdateTime: Date = Date(),
        applicationName: String? = nil,
        windowTitle: String? = nil,
        windowBounds: CGRect? = nil,
        menuBar: MenuBarData? = nil
    ) {
        self.version = version
        self.screenshotPath = screenshotPath
        self.annotatedPath = annotatedPath
        self.uiMap = uiMap
        self.lastUpdateTime = lastUpdateTime
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowBounds = windowBounds
        self.menuBar = menuBar
    }
}

/// UI element information stored in session
public struct UIElement: Codable, Sendable {
    public let id: String
    public let elementId: String
    public let role: String
    public let title: String?
    public let label: String?
    public let value: String?
    public let description: String?
    public let help: String?
    public let roleDescription: String?
    public let identifier: String?
    public var frame: CGRect
    public let isActionable: Bool
    public let parentId: String?
    public let children: [String]
    public let keyboardShortcut: String?
    
    public init(
        id: String,
        elementId: String,
        role: String,
        title: String? = nil,
        label: String? = nil,
        value: String? = nil,
        description: String? = nil,
        help: String? = nil,
        roleDescription: String? = nil,
        identifier: String? = nil,
        frame: CGRect,
        isActionable: Bool,
        parentId: String? = nil,
        children: [String] = [],
        keyboardShortcut: String? = nil
    ) {
        self.id = id
        self.elementId = elementId
        self.role = role
        self.title = title
        self.label = label
        self.value = value
        self.description = description
        self.help = help
        self.roleDescription = roleDescription
        self.identifier = identifier
        self.frame = frame
        self.isActionable = isActionable
        self.parentId = parentId
        self.children = children
        self.keyboardShortcut = keyboardShortcut
    }
}

/// Menu bar information
public struct MenuBarData: Codable, Sendable {
    public let menus: [Menu]
    
    public init(menus: [Menu]) {
        self.menus = menus
    }
    
    public struct Menu: Codable, Sendable {
        public let title: String
        public let items: [MenuItem]
        public let enabled: Bool
        
        public init(title: String, items: [MenuItem], enabled: Bool) {
            self.title = title
            self.items = items
            self.enabled = enabled
        }
    }
    
    public struct MenuItem: Codable, Sendable {
        public let title: String
        public let enabled: Bool
        public let hasSubmenu: Bool
        public let keyboardShortcut: String?
        public let items: [MenuItem]?
        
        public init(
            title: String,
            enabled: Bool,
            hasSubmenu: Bool,
            keyboardShortcut: String? = nil,
            items: [MenuItem]? = nil
        ) {
            self.title = title
            self.enabled = enabled
            self.hasSubmenu = hasSubmenu
            self.keyboardShortcut = keyboardShortcut
            self.items = items
        }
    }
}

/// Session storage error types
public enum SessionError: LocalizedError, Sendable {
    case sessionNotFound
    case noValidSessionFound
    case versionMismatch(found: Int, expected: Int)
    case corruptedData
    case storageError(String)
    
    public var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found or expired"
        case .noValidSessionFound:
            return "No valid session found. Create a new session first."
        case .versionMismatch(let found, let expected):
            return "Session version mismatch (found: \(found), expected: \(expected))"
        case .corruptedData:
            return "Session data is corrupted"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        }
    }
}