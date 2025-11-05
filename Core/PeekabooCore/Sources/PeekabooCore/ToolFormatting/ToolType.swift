//
//  ToolType.swift
//  PeekabooCore
//

import Foundation

/// Type-safe enumeration of all Peekaboo tools
public enum ToolType: String, CaseIterable, Sendable {
    // MARK: - Vision Tools

    case see
    case screenshot
    case windowCapture = "window_capture"
    case analyze

    // MARK: - UI Automation

    case click
    case type
    case scroll
    case hotkey
    case drag
    case move
    case swipe
    case press

    // MARK: - Application Management

    case launchApp = "launch_app"
    case listApps = "list_apps"
    case quitApp = "quit_app"
    case focusApp = "focus_app"
    case hideApp = "hide_app"
    case unhideApp = "unhide_app"
    case switchApp = "switch_app"

    // MARK: - Window Management

    case focusWindow = "focus_window"
    case resizeWindow = "resize_window"
    case listWindows = "list_windows"
    case minimizeWindow = "minimize_window"
    case maximizeWindow = "maximize_window"
    case listScreens = "list_screens"

    // MARK: - Menu & Dialog

    case menuClick = "menu_click"
    case listMenus = "list_menus"
    case dialogClick = "dialog_click"
    case dialogInput = "dialog_input"

    // MARK: - Dock

    case listDock = "list_dock"
    case dockClick = "dock_click"
    case dockLaunch = "dock_launch"

    // MARK: - Element Query

    case findElement = "find_element"
    case listElements = "list_elements"
    case focused

    // MARK: - System

    case shell
    case wait
    case copyToClipboard = "copy_to_clipboard"
    case pasteFromClipboard = "paste_from_clipboard"
    case listSpaces = "list_spaces"
    case switchSpace = "switch_space"
    case moveWindowToSpace = "move_window_to_space"

    // MARK: - Communication

    case taskCompleted = "task_completed"
    case needMoreInformation = "need_more_information"
    case needInfo = "need_info"

    // MARK: - Properties

    /// The category this tool belongs to
    var category: ToolCategory {
        switch self {
        case .see, .screenshot, .windowCapture, .analyze:
            .vision
        case .click, .type, .scroll, .hotkey, .drag, .move, .swipe, .press:
            .ui
        case .launchApp, .listApps, .quitApp, .focusApp, .hideApp, .unhideApp, .switchApp:
            .app
        case .focusWindow, .resizeWindow, .listWindows, .minimizeWindow, .maximizeWindow, .listScreens:
            .window
        case .menuClick, .listMenus, .dialogClick, .dialogInput:
            .menu
        case .listDock, .dockClick, .dockLaunch:
            .dock
        case .findElement, .listElements, .focused:
            .element
        case .shell, .wait, .copyToClipboard, .pasteFromClipboard, .listSpaces, .switchSpace, .moveWindowToSpace:
            .system
        case .taskCompleted, .needMoreInformation, .needInfo:
            .completion
        }
    }

    /// The icon to display for this tool
    public var icon: String {
        // Special cases first
        switch self {
        case .taskCompleted:
            "\(AgentDisplayTokens.Status.success)"
        case .needMoreInformation, .needInfo:
            "\(AgentDisplayTokens.Status.info)"
        case .wait:
            "\(AgentDisplayTokens.Status.time)"
        case .shell:
            "[sh]"
        case .scroll:
            "[scrl]"
        case .type, .hotkey, .press:
            "[type]"
        case .click, .dialogClick:
            "[tap]"
        default:
            // Use category icon
            self.category.icon
        }
    }

    /// Human-readable display name for the tool
    public var displayName: String {
        switch self {
        case .launchApp: "Launch Application"
        case .listApps: "List Applications"
        case .quitApp: "Quit Application"
        case .focusApp: "Focus Application"
        case .hideApp: "Hide Application"
        case .unhideApp: "Show Application"
        case .switchApp: "Switch Application"
        case .focusWindow: "Focus Window"
        case .resizeWindow: "Resize Window"
        case .listWindows: "List Windows"
        case .minimizeWindow: "Minimize Window"
        case .maximizeWindow: "Maximize Window"
        case .listScreens: "List Screens"
        case .menuClick: "Click Menu"
        case .listMenus: "List Menus"
        case .dialogClick: "Click Dialog"
        case .dialogInput: "Enter Dialog Input"
        case .listDock: "List Dock Items"
        case .dockClick: "Click Dock Item"
        case .dockLaunch: "Launch from Dock"
        case .findElement: "Find Element"
        case .listElements: "List Elements"
        case .windowCapture: "Capture Window"
        case .taskCompleted: "Task Completed"
        case .needMoreInformation: "Need More Information"
        case .needInfo: "Need Information"
        case .copyToClipboard: "Copy to Clipboard"
        case .pasteFromClipboard: "Paste from Clipboard"
        case .listSpaces: "List Spaces"
        case .switchSpace: "Switch Space"
        case .moveWindowToSpace: "Move Window to Space"
        default:
            // Default: capitalize and replace underscores
            rawValue
                .split(separator: "_")
                .map(\.capitalized)
                .joined(separator: " ")
        }
    }

    /// Whether this is a communication tool that should be displayed differently
    var isCommunicationTool: Bool {
        switch self {
        case .taskCompleted, .needMoreInformation, .needInfo:
            true
        default:
            false
        }
    }

    // MARK: - Initialization

    /// Initialize from a string tool name (for backward compatibility)
    init?(toolName: String) {
        // Try direct rawValue match first
        if let tool = ToolType(rawValue: toolName) {
            self = tool
        } else {
            // Handle any legacy naming variations
            switch toolName {
            case "need_info":
                self = .needInfo
            default:
                return nil
            }
        }
    }
}
