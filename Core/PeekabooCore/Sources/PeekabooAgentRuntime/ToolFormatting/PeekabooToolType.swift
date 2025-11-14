//
//  PeekabooToolType.swift
//  PeekabooCore
//

import Foundation
import PeekabooAutomation

/// Comprehensive enum of all Peekaboo tools with their metadata
public enum PeekabooToolType: String, CaseIterable, Sendable {
    // Vision & Screenshot Tools
    case see
    case screenshot
    case windowCapture = "window_capture"

    // UI Automation Tools
    case click
    case type
    case scroll
    case hotkey
    case press

    // Application Management
    case launchApp = "launch_app"
    case listApps = "list_apps"
    case focusWindow = "focus_window"
    case listWindows = "list_windows"
    case resizeWindow = "resize_window"

    // Element Interaction
    case findElement = "find_element"
    case listElements = "list_elements"
    case focused

    // Menu & Dock
    case menuClick = "menu_click"
    case listMenus = "list_menus"
    case listDock = "list_dock"
    case dockClick = "dock_click"

    // Dialog Interaction
    case dialogClick = "dialog_click"
    case dialogInput = "dialog_input"

    // System Operations
    case shell
    case wait

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
        case .see: "Capture Screen"
        case .screenshot: "Take Screenshot"
        case .windowCapture: "Capture Window"
        case .click: "Click"
        case .type: "Type Text"
        case .scroll: "Scroll"
        case .hotkey: "Press Hotkey"
        case .press: "Press Key"
        case .launchApp: "Launch Application"
        case .listApps: "List Applications"
        case .focusWindow: "Focus Window"
        case .listWindows: "List Windows"
        case .resizeWindow: "Resize Window"
        case .findElement: "Find Element"
        case .listElements: "List Elements"
        case .focused: "Get Focused Element"
        case .menuClick: "Click Menu"
        case .listMenus: "List Menus"
        case .listDock: "List Dock Items"
        case .dockClick: "Click Dock Item"
        case .dialogClick: "Click Dialog Button"
        case .dialogInput: "Enter Dialog Text"
        case .shell: "Run Shell Command"
        case .wait: "Wait"
        case .listSpaces: "List Spaces"
        case .switchSpace: "Switch Space"
        case .moveWindowToSpace: "Move Window to Space"
        case .listScreens: "List Displays"
        case .taskCompleted: "Task Completed"
        case .needMoreInformation: "Need More Information"
        }
    }

    /// Icon for the tool
    public var icon: String {
        switch self {
        case .see, .screenshot, .windowCapture: "[see]"
        case .click, .dialogClick: "[tap]"
        case .type, .dialogInput, .hotkey, .press: "[type]"
        case .listApps, .launchApp: "[apps]"
        case .listWindows, .focusWindow, .resizeWindow: "[win]"
        case .scroll: "[scrl]"
        case .findElement, .listElements, .focused: "🔍"
        case .shell: "[sh]"
        case .menuClick, .listMenus: "[menu]"
        case .listDock, .dockClick: "[menu]"
        case .listSpaces, .switchSpace, .moveWindowToSpace: "[win]"
        case .listScreens: "[scrn]"
        case .wait: "\(AgentDisplayTokens.Status.time)"
        case .taskCompleted: "\(AgentDisplayTokens.Status.success)"
        case .needMoreInformation: "\(AgentDisplayTokens.Status.info)"
        }
    }

    /// Tool category for grouping (mapped to canonical categories)
    public var category: ToolCategory {
        switch self {
        case .see, .screenshot, .windowCapture:
            .vision
        case .click, .type, .scroll, .hotkey, .press:
            .ui
        case .launchApp, .listApps:
            .app
        case .focusWindow, .listWindows, .resizeWindow, .listSpaces, .switchSpace, .moveWindowToSpace, .listScreens:
            .window
        case .findElement, .listElements, .focused:
            .element
        case .menuClick, .listMenus:
            .menu
        case .listDock, .dockClick:
            .dock
        case .dialogClick, .dialogInput:
            .dialog
        case .shell, .wait:
            .system
        case .taskCompleted, .needMoreInformation:
            .completion
        }
    }

    /// Whether this is a communication tool (shouldn't show output)
    public var isCommunicationTool: Bool {
        switch self {
        case .taskCompleted, .needMoreInformation: true
        default: false
        }
    }
}
