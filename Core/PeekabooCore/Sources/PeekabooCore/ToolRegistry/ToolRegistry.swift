import Foundation

/// Central registry for all Peekaboo tools
/// This registry collects tool definitions from various tool implementation files
@available(macOS 14.0, *)
public enum ToolRegistry {
    // MARK: - Registry Access

    /// All registered tools collected from various definition structs
    public static let allTools: [UnifiedToolDefinition] = {
        var tools: [UnifiedToolDefinition] = []

        // Vision tools
        tools.append(VisionToolDefinitions.see)
        tools.append(VisionToolDefinitions.screenshot)

        // UI Automation tools
        tools.append(UIAutomationToolDefinitions.click)
        tools.append(UIAutomationToolDefinitions.type)
        tools.append(UIAutomationToolDefinitions.press)
        tools.append(UIAutomationToolDefinitions.scroll)
        tools.append(UIAutomationToolDefinitions.hotkey)

        // Window Management tools
        // TODO: WindowManagementTools.swift needs to be refactored to use ToolDefinitions pattern
        // tools.append(WindowManagementToolDefinitions.listWindows)
        // tools.append(WindowManagementToolDefinitions.focusWindow)
        // tools.append(WindowManagementToolDefinitions.resizeWindow)
        // tools.append(WindowManagementToolDefinitions.listSpaces)
        // tools.append(WindowManagementToolDefinitions.switchSpace)
        // tools.append(WindowManagementToolDefinitions.moveWindowToSpace)

        // Application tools
        tools.append(ApplicationToolDefinitions.listApps)
        tools.append(ApplicationToolDefinitions.launchApp)

        // Menu tools
        tools.append(MenuToolDefinitions.menuClick)
        tools.append(MenuToolDefinitions.listMenus)

        // Dialog tools
        tools.append(DialogToolDefinitions.dialogClick)
        tools.append(DialogToolDefinitions.dialogInput)

        // Dock tools
        tools.append(DockToolDefinitions.dockLaunch)
        tools.append(DockToolDefinitions.listDock)

        // System tools
        tools.append(ShellToolDefinitions.shell)

        return tools
    }()

    /// Get tool by name
    public static func tool(named name: String) -> UnifiedToolDefinition? {
        self.allTools.first { $0.name == name || $0.commandName == name }
    }

    /// Get tools grouped by category
    public static func toolsByCategory() -> [ToolCategory: [UnifiedToolDefinition]] {
        Dictionary(grouping: self.allTools, by: { $0.category })
    }

    /// Get parameter by name from a tool
    public static func parameter(named name: String, from tool: UnifiedToolDefinition) -> ParameterDefinition? {
        tool.parameters.first { $0.name == name }
    }
}
