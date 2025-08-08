//
//  ToolType.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

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
            return .vision
        case .click, .type, .scroll, .hotkey, .drag, .move, .swipe, .press:
            return .ui
        case .launchApp, .listApps, .quitApp, .focusApp, .hideApp, .unhideApp, .switchApp:
            return .app
        case .focusWindow, .resizeWindow, .listWindows, .minimizeWindow, .maximizeWindow, .listScreens:
            return .window
        case .menuClick, .listMenus, .dialogClick, .dialogInput:
            return .menu
        case .listDock, .dockClick, .dockLaunch:
            return .dock
        case .findElement, .listElements, .focused:
            return .element
        case .shell, .wait, .listSpaces, .switchSpace, .moveWindowToSpace:
            return .system
        case .taskCompleted, .needMoreInformation, .needInfo:
            return .completion
        }
    }
    
    /// The icon to display for this tool
    var icon: String {
        // Special cases first
        switch self {
        case .taskCompleted:
            return "✅"
        case .needMoreInformation, .needInfo:
            return "❓"
        case .wait:
            return "⏱"
        case .shell:
            return "💻"
        case .scroll:
            return "📜"
        case .type, .hotkey, .press:
            return "⌨️"
        case .click, .dialogClick:
            return "🖱"
        default:
            // Use category icon
            return category.icon
        }
    }
    
    /// Human-readable display name for the tool
    var displayName: String {
        switch self {
        case .launchApp: return "Launch Application"
        case .listApps: return "List Applications"
        case .quitApp: return "Quit Application"
        case .focusApp: return "Focus Application"
        case .hideApp: return "Hide Application"
        case .unhideApp: return "Show Application"
        case .switchApp: return "Switch Application"
        case .focusWindow: return "Focus Window"
        case .resizeWindow: return "Resize Window"
        case .listWindows: return "List Windows"
        case .minimizeWindow: return "Minimize Window"
        case .maximizeWindow: return "Maximize Window"
        case .listScreens: return "List Screens"
        case .menuClick: return "Click Menu"
        case .listMenus: return "List Menus"
        case .dialogClick: return "Click Dialog"
        case .dialogInput: return "Enter Dialog Input"
        case .listDock: return "List Dock Items"
        case .dockClick: return "Click Dock Item"
        case .dockLaunch: return "Launch from Dock"
        case .findElement: return "Find Element"
        case .listElements: return "List Elements"
        case .windowCapture: return "Capture Window"
        case .taskCompleted: return "Task Completed"
        case .needMoreInformation: return "Need More Information"
        case .needInfo: return "Need Information"
        case .listSpaces: return "List Spaces"
        case .switchSpace: return "Switch Space"
        case .moveWindowToSpace: return "Move Window to Space"
        default:
            // Default: capitalize and replace underscores
            return rawValue
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }
    
    /// Whether this is a communication tool that should be displayed differently
    var isCommunicationTool: Bool {
        switch self {
        case .taskCompleted, .needMoreInformation, .needInfo:
            return true
        default:
            return false
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