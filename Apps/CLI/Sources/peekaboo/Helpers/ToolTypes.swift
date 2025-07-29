import Foundation

/// Enum representing all available Peekaboo tools
public enum PeekabooTool: String, CaseIterable {
    // Screen and UI Tools
    case see
    case screenshot
    case windowCapture = "window_capture"
    
    // Interaction Tools
    case click
    case type
    case scroll
    case hotkey
    case drag
    case swipe
    
    // Window Management
    case listWindows = "list_windows"
    case focusWindow = "focus_window"
    case resizeWindow = "resize_window"
    case listSpaces = "list_spaces"
    case switchSpace = "switch_space"
    case moveWindowToSpace = "move_window_to_space"
    
    // Application Tools
    case listApps = "list_apps"
    case launchApp = "launch_app"
    case findElement = "find_element"
    case listElements = "list_elements"
    case focused
    
    // Menu and Dialog
    case menuClick = "menu_click"
    case listMenus = "list_menus"
    case dialogClick = "dialog_click"
    case dialogInput = "dialog_input"
    
    // Dock Tools
    case dockLaunch = "dock_launch"
    case listDock = "list_dock"
    
    // Other Tools
    case shell
    case taskCompleted = "task_completed"
    case needMoreInformation = "need_more_information"
}

/// Helper to get tool enum from string
public extension PeekabooTool {
    init?(from toolName: String) {
        // Try direct raw value match first
        if let tool = PeekabooTool(rawValue: toolName) {
            self = tool
            return
        }
        
        // Try case-insensitive match
        let lowercased = toolName.lowercased()
        for tool in PeekabooTool.allCases {
            if tool.rawValue.lowercased() == lowercased {
                self = tool
                return
            }
        }
        
        return nil
    }
}