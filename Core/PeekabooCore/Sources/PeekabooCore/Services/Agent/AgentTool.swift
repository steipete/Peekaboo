import Foundation

/// Enumeration of all available agent tools (legacy - will be removed)
@available(macOS 14.0, *)
public enum LegacyAgentTool: String, CaseIterable, Sendable {
    // Vision tools
    case see
    case screenshot
    case windowCapture = "window_capture"

    // UI Automation tools
    case click
    case type
    case scroll
    case press
    case hotkey

    // Screen and space tools
    case listSpaces = "list_spaces"
    case listScreens = "list_screens"
    case switchSpace = "switch_space"
    case moveWindowToSpace = "move_window_to_space"

    // Application tools
    case listApps = "list_apps"
    case launchApp = "launch_app"

    // Menu tools
    case menuClick = "menu_click"
    case listMenus = "list_menus"

    // Dialog tools
    case dialogClick = "dialog_click"
    case dialogInput = "dialog_input"

    // Dock tools
    case dockClick = "dock_click"
    case listDock = "list_dock"

    // Shell tool
    case shell

    // Utility tools
    case wait

    /// The string identifier used for tool calls
    public var toolName: String {
        self.rawValue
    }

    /// Initialize from a tool name string
    public init?(toolName: String) {
        self.init(rawValue: toolName)
    }

    /// Get a human-readable display name
    public var displayName: String {
        switch self {
        case .see: "See"
        case .screenshot: "Screenshot"
        case .windowCapture: "Window Capture"
        case .click: "Click"
        case .type: "Type"
        case .scroll: "Scroll"
        case .press: "Press"
        case .hotkey: "Hotkey"
        case .listSpaces: "List Spaces"
        case .listScreens: "List Screens"
        case .switchSpace: "Switch Space"
        case .moveWindowToSpace: "Move Window to Space"
        case .listApps: "List Apps"
        case .launchApp: "Launch App"
        case .menuClick: "Menu Click"
        case .listMenus: "List Menus"
        case .dialogClick: "Dialog Click"
        case .dialogInput: "Dialog Input"
        case .dockClick: "Dock Click"
        case .listDock: "List Dock"
        case .shell: "Shell"
        case .wait: "Wait"
        }
    }

    /// Get the tool category
    public var category: ToolCategory {
        switch self {
        case .see, .screenshot, .windowCapture:
            .vision
        case .click, .type, .scroll, .press, .hotkey:
            .automation
        case .listSpaces, .listScreens, .switchSpace, .moveWindowToSpace:
            .window
        case .listApps, .launchApp:
            .app
        case .menuClick, .listMenus, .dialogClick, .dialogInput:
            .menu
        case .dockClick, .listDock:
            .system
        case .shell:
            .system
        case .wait:
            .system
        }
    }
}
