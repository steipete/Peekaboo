//
//  PeekabooToolType.swift
//  PeekabooCore
//

import Foundation

/// Comprehensive enum of all Peekaboo tools with their metadata
public enum PeekabooToolType: String, CaseIterable, Sendable {
    // Vision & Screenshot Tools
    case see = "see"
    case screenshot = "screenshot"
    case windowCapture = "window_capture"
    
    // UI Automation Tools
    case click = "click"
    case type = "type"
    case scroll = "scroll"
    case hotkey = "hotkey"
    case press = "press"
    
    // Application Management
    case launchApp = "launch_app"
    case listApps = "list_apps"
    case focusWindow = "focus_window"
    case listWindows = "list_windows"
    case resizeWindow = "resize_window"
    
    // Element Interaction
    case findElement = "find_element"
    case listElements = "list_elements"
    case focused = "focused"
    
    // Menu & Dock
    case menuClick = "menu_click"
    case listMenus = "list_menus"
    case listDock = "list_dock"
    case dockClick = "dock_click"
    
    // Dialog Interaction
    case dialogClick = "dialog_click"
    case dialogInput = "dialog_input"
    
    // System Operations
    case shell = "shell"
    case wait = "wait"
    
    // Spaces & Screens
    case listSpaces = "list_spaces"
    case switchSpace = "switch_space"
    case moveWindowToSpace = "move_window_to_space"
    case listScreens = "list_screens"
    
    // Communication Tools
    case taskCompleted = "task_completed"
    case needMoreInformation = "need_more_information"
    
    /// Human-readable display name for the tool
    public var displayName: String {
        switch self {
        case .see: return "Capture Screen"
        case .screenshot: return "Take Screenshot"
        case .windowCapture: return "Capture Window"
        case .click: return "Click"
        case .type: return "Type Text"
        case .scroll: return "Scroll"
        case .hotkey: return "Press Hotkey"
        case .press: return "Press Key"
        case .launchApp: return "Launch Application"
        case .listApps: return "List Applications"
        case .focusWindow: return "Focus Window"
        case .listWindows: return "List Windows"
        case .resizeWindow: return "Resize Window"
        case .findElement: return "Find Element"
        case .listElements: return "List Elements"
        case .focused: return "Get Focused Element"
        case .menuClick: return "Click Menu"
        case .listMenus: return "List Menus"
        case .listDock: return "List Dock Items"
        case .dockClick: return "Click Dock Item"
        case .dialogClick: return "Click Dialog Button"
        case .dialogInput: return "Enter Dialog Text"
        case .shell: return "Run Shell Command"
        case .wait: return "Wait"
        case .listSpaces: return "List Spaces"
        case .switchSpace: return "Switch Space"
        case .moveWindowToSpace: return "Move Window to Space"
        case .listScreens: return "List Displays"
        case .taskCompleted: return "Task Completed"
        case .needMoreInformation: return "Need More Information"
        }
    }
    
    /// Icon for the tool
    public var icon: String {
        switch self {
        case .see, .screenshot, .windowCapture: return "👁"
        case .click, .dialogClick: return "🖱"
        case .type, .dialogInput, .hotkey, .press: return "⌨️"
        case .listApps, .launchApp: return "📱"
        case .listWindows, .focusWindow, .resizeWindow: return "🪟"
        case .scroll: return "📜"
        case .findElement, .listElements, .focused: return "🔍"
        case .shell: return "💻"
        case .menuClick, .listMenus: return "📋"
        case .listDock, .dockClick: return "📋"
        case .listSpaces, .switchSpace, .moveWindowToSpace: return "🪟"
        case .listScreens: return "🖥"
        case .wait: return "⏱"
        case .taskCompleted: return "✅"
        case .needMoreInformation: return "❓"
        }
    }
    
    /// Tool category for grouping (mapped to canonical categories)
    public var category: ToolCategory {
        switch self {
        case .see, .screenshot, .windowCapture:
            return .vision
        case .click, .type, .scroll, .hotkey, .press:
            return .ui
        case .launchApp, .listApps:
            return .app
        case .focusWindow, .listWindows, .resizeWindow, .listSpaces, .switchSpace, .moveWindowToSpace, .listScreens:
            return .window
        case .findElement, .listElements, .focused:
            return .element
        case .menuClick, .listMenus:
            return .menu
        case .listDock, .dockClick:
            return .dock
        case .dialogClick, .dialogInput:
            return .dialog
        case .shell, .wait:
            return .system
        case .taskCompleted, .needMoreInformation:
            return .completion
        }
    }
    
    /// Whether this is a communication tool (shouldn't show output)
    public var isCommunicationTool: Bool {
        switch self {
        case .taskCompleted, .needMoreInformation: return true
        default: return false
        }
    }
}