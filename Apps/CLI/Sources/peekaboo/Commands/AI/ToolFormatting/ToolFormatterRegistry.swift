//
//  ToolFormatterRegistry.swift
//  Peekaboo
//

import Foundation

/// Registry for tool formatters, providing type-safe lookup and management
public final class ToolFormatterRegistry: @unchecked Sendable {
    
    // Singleton instance for global access
    public static let shared = ToolFormatterRegistry()
    
    // Dictionary of formatters by tool type
    private var formatters: [ToolType: ToolFormatter] = [:]
    
    // MARK: - Initialization
    
    public init() {
        registerAllFormatters()
    }
    
    // MARK: - Registration
    
    private func registerAllFormatters() {
        // Register formatters by category for better organization
        
        // Application tools
        let appFormatter = ApplicationToolFormatter(toolType: .launchApp)
        register(appFormatter, for: [.launchApp, .listApps, .quitApp, .focusApp, .hideApp, .unhideApp, .switchApp])
        
        // Vision tools
        let visionFormatter = VisionToolFormatter(toolType: .see)
        register(visionFormatter, for: [.see, .screenshot, .windowCapture, .analyze])
        
        // UI Automation tools
        let uiFormatter = UIAutomationToolFormatter(toolType: .click)
        register(uiFormatter, for: [.click, .type, .scroll, .hotkey, .drag, .move, .swipe, .press])
        
        // Window management tools
        let windowFormatter = WindowToolFormatter(toolType: .focusWindow)
        register(windowFormatter, for: [.focusWindow, .resizeWindow, .listWindows, .minimizeWindow, .maximizeWindow, .listScreens])
        
        // Menu and dialog tools
        let menuFormatter = MenuDialogToolFormatter(toolType: .menuClick)
        register(menuFormatter, for: [.menuClick, .listMenus, .dialogClick, .dialogInput])
        
        // Dock tools
        let dockFormatter = DockToolFormatter(toolType: .listDock)
        register(dockFormatter, for: [.listDock, .dockClick, .dockLaunch])
        
        // Element query tools
        let elementFormatter = ElementToolFormatter(toolType: .findElement)
        register(elementFormatter, for: [.findElement, .listElements, .focused])
        
        // System tools
        let systemFormatter = SystemToolFormatter(toolType: .shell)
        register(systemFormatter, for: [.shell, .wait, .listSpaces, .switchSpace, .moveWindowToSpace])
        
        // Communication tools
        let commFormatter = CommunicationToolFormatter(toolType: .taskCompleted)
        register(commFormatter, for: [.taskCompleted, .needMoreInformation, .needInfo])
    }
    
    private func register(_ formatter: ToolFormatter, for toolTypes: [ToolType]) {
        for toolType in toolTypes {
            // Create a new instance with the correct tool type
            let specificFormatter = createFormatterInstance(formatter, for: toolType)
            formatters[toolType] = specificFormatter
        }
    }
    
    private func createFormatterInstance(_ formatter: ToolFormatter, for toolType: ToolType) -> ToolFormatter {
        // Create appropriate formatter instance based on type
        switch formatter {
        case is ApplicationToolFormatter:
            return ApplicationToolFormatter(toolType: toolType)
        case is VisionToolFormatter:
            return VisionToolFormatter(toolType: toolType)
        case is UIAutomationToolFormatter:
            return UIAutomationToolFormatter(toolType: toolType)
        case is WindowToolFormatter:
            return WindowToolFormatter(toolType: toolType)
        case is MenuDialogToolFormatter:
            return MenuDialogToolFormatter(toolType: toolType)
        case is DockToolFormatter:
            return DockToolFormatter(toolType: toolType)
        case is ElementToolFormatter:
            return ElementToolFormatter(toolType: toolType)
        case is SystemToolFormatter:
            return SystemToolFormatter(toolType: toolType)
        case is CommunicationToolFormatter:
            return CommunicationToolFormatter(toolType: toolType)
        default:
            return BaseToolFormatter(toolType: toolType)
        }
    }
    
    // MARK: - Lookup
    
    /// Get formatter for a specific tool type
    public func formatter(for toolType: ToolType) -> ToolFormatter {
        formatters[toolType] ?? BaseToolFormatter(toolType: toolType)
    }
    
    /// Get formatter for a tool name (backward compatibility)
    public func formatter(for toolName: String) -> ToolFormatter? {
        guard let toolType = ToolType(toolName: toolName) else {
            return nil
        }
        return formatter(for: toolType)
    }
    
    /// Check if a tool name is valid
    public func isValidTool(_ toolName: String) -> Bool {
        ToolType(toolName: toolName) != nil
    }
    
    /// Get the tool type for a name
    public func toolType(for toolName: String) -> ToolType? {
        ToolType(toolName: toolName)
    }
}