import Foundation

/// Enumeration of all available agent tools
@available(macOS 14.0, *)
public enum AgentTool: String, CaseIterable, Sendable {
    // Vision tools
    case see = "see"
    case screenshot = "screenshot"
    case windowCapture = "window_capture"
    
    // UI Automation tools
    case click = "click"
    case type = "type"
    case scroll = "scroll"
    case press = "press"
    case hotkey = "hotkey"
    
    // Element tools
    case findElement = "find_element"
    case listElements = "list_elements"
    case focused = "focused"
    
    // Window management tools
    case listWindows = "list_windows"
    case focusWindow = "focus_window"
    case resizeWindow = "resize_window"
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
    case shell = "shell"
    
    // Utility tools
    case wait = "wait"
    
    /// The string identifier used for tool calls
    public var toolName: String {
        return self.rawValue
    }
    
    /// Initialize from a tool name string
    public init?(toolName: String) {
        self.init(rawValue: toolName)
    }
    
    /// Get a human-readable display name
    public var displayName: String {
        switch self {
        case .see: return "See"
        case .screenshot: return "Screenshot"
        case .windowCapture: return "Window Capture"
        case .click: return "Click"
        case .type: return "Type"
        case .scroll: return "Scroll"
        case .press: return "Press"
        case .hotkey: return "Hotkey"
        case .findElement: return "Find Element"
        case .listElements: return "List Elements"
        case .focused: return "Focused"
        case .listWindows: return "List Windows"
        case .focusWindow: return "Focus Window"
        case .resizeWindow: return "Resize Window"
        case .listSpaces: return "List Spaces"
        case .listScreens: return "List Screens"
        case .switchSpace: return "Switch Space"
        case .moveWindowToSpace: return "Move Window to Space"
        case .listApps: return "List Apps"
        case .launchApp: return "Launch App"
        case .menuClick: return "Menu Click"
        case .listMenus: return "List Menus"
        case .dialogClick: return "Dialog Click"
        case .dialogInput: return "Dialog Input"
        case .dockClick: return "Dock Click"
        case .listDock: return "List Dock"
        case .shell: return "Shell"
        case .wait: return "Wait"
        }
    }
    
    /// Get the tool category
    public var category: ToolCategory {
        switch self {
        case .see, .screenshot, .windowCapture:
            return .vision
        case .click, .type, .scroll, .press, .hotkey:
            return .automation
        case .findElement, .listElements, .focused:
            return .element
        case .listWindows, .focusWindow, .resizeWindow, .listSpaces, .listScreens, .switchSpace, .moveWindowToSpace:
            return .window
        case .listApps, .launchApp:
            return .app
        case .menuClick, .listMenus, .dialogClick, .dialogInput:
            return .menu
        case .dockClick, .listDock:
            return .system
        case .shell:
            return .system
        case .wait:
            return .system
        }
    }
}