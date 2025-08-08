//
//  ToolFormatterRegistry.swift
//  Peekaboo
//

import Foundation

/// Main registry for tool formatters with comprehensive result formatting
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
        // Register all formatters with comprehensive output
        
        // Application tools
        let appFormatter = DetailedApplicationToolFormatter(toolType: .launchApp)
        register(appFormatter, for: [.launchApp, .listApps, .quitApp, .focusApp, .hideApp, .unhideApp, .switchApp])
        
        // Vision tools
        let visionFormatter = DetailedVisionToolFormatter(toolType: .see)
        register(visionFormatter, for: [.see, .screenshot, .windowCapture, .analyze])
        
        // UI Automation tools
        let uiFormatter = DetailedUIAutomationToolFormatter(toolType: .click)
        register(uiFormatter, for: [
            .click,
            .type, .scroll, .hotkey, .press,
            .move
        ])
        
        // Menu and System tools
        let menuSystemFormatter = DetailedMenuSystemToolFormatter(toolType: .menuClick)
        register(menuSystemFormatter, for: [
            // Menu tools
            .menuClick, .listMenus,
            // Dialog tools
            .dialogInput, .dialogClick,
            // System tools
            .shell, .wait,
            // Dock tools
            .dockClick
        ])
        
        // Window management tools (use standard for now)
        let windowFormatter = WindowToolFormatter(toolType: .focusWindow)
        register(windowFormatter, for: [
            .focusWindow, .resizeWindow, .listWindows,
            .minimizeWindow, .maximizeWindow, .listScreens,
            .listSpaces, .switchSpace, .moveWindowToSpace
        ])
        
        // Element query tools (use standard for now)
        let elementFormatter = ElementToolFormatter(toolType: .findElement)
        register(elementFormatter, for: [.findElement, .listElements, .focused])
        
        // Communication tools (use standard)
        let commFormatter = CommunicationToolFormatter(toolType: .taskCompleted)
        register(commFormatter, for: [.taskCompleted, .needMoreInformation, .needInfo])
        
        // Additional tools that might not have specific formatters yet
        registerRemainingTools()
    }
    
    private func registerRemainingTools() {
        // Register any remaining tools with appropriate formatters
        for toolType in ToolType.allCases {
            if formatters[toolType] == nil {
                // Determine best formatter based on category
                let formatter = createDefaultFormatter(for: toolType)
                formatters[toolType] = formatter
            }
        }
    }
    
    private func createDefaultFormatter(for toolType: ToolType) -> ToolFormatter {
        // Create appropriate formatter based on tool category
        switch toolType.category {
        case .vision:
            return DetailedVisionToolFormatter(toolType: toolType)
        case .automation:
            return DetailedUIAutomationToolFormatter(toolType: toolType)
        case .ui:
            return DetailedUIAutomationToolFormatter(toolType: toolType)
        case .app:
            return DetailedApplicationToolFormatter(toolType: toolType)
        case .application:
            return DetailedApplicationToolFormatter(toolType: toolType)
        case .window:
            return WindowToolFormatter(toolType: toolType)
        case .menu:
            return DetailedMenuSystemToolFormatter(toolType: toolType)
        case .dialog:
            return DetailedMenuSystemToolFormatter(toolType: toolType)
        case .dock:
            return DetailedMenuSystemToolFormatter(toolType: toolType)
        case .element:
            return ElementToolFormatter(toolType: toolType)
        case .query:
            return ElementToolFormatter(toolType: toolType)
        case .system:
            return DetailedMenuSystemToolFormatter(toolType: toolType)
        case .completion:
            return CommunicationToolFormatter(toolType: toolType)
        }
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
        case is DetailedApplicationToolFormatter:
            return DetailedApplicationToolFormatter(toolType: toolType)
        case is DetailedVisionToolFormatter:
            return DetailedVisionToolFormatter(toolType: toolType)
        case is DetailedUIAutomationToolFormatter:
            return DetailedUIAutomationToolFormatter(toolType: toolType)
        case is DetailedMenuSystemToolFormatter:
            return DetailedMenuSystemToolFormatter(toolType: toolType)
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