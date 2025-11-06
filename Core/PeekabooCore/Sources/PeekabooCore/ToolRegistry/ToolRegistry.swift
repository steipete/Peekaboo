import Foundation
import Tachikoma

/// Central registry for all Peekaboo tools
/// This registry collects tool definitions from various tool implementation files
@available(macOS 14.0, *)
public enum ToolRegistry {
    // MARK: - Registry Access

    /// All registered tools collected from various definition structs
    @MainActor
    public static var allTools: [PeekabooToolDefinition] {
        // Tools have been refactored into PeekabooAgentService+Tools.swift
        // We now create PeekabooToolDefinitions from the agent service
        guard let agentService = try? PeekabooAgentService(services: PeekabooServices.shared) else {
            return []
        }

        // Get all agent tools
        let agentTools = agentService.createAgentTools()

        // Convert AgentTools to PeekabooToolDefinitions
        return agentTools.compactMap { agentTool in
            convertAgentToolToDefinition(agentTool)
        }
    }

    /// Get tool by name
    @MainActor
    public static func tool(named name: String) -> PeekabooToolDefinition? {
        self.allTools.first { $0.name == name || $0.commandName == name }
    }

    /// Get tools grouped by category
    @MainActor
    public static func toolsByCategory() -> [ToolCategory: [PeekabooToolDefinition]] {
        Dictionary(grouping: self.allTools, by: { $0.category })
    }

    /// Get parameter by name from a tool
    public static func parameter(named name: String, from tool: PeekabooToolDefinition) -> ParameterDefinition? {
        // Get parameter by name from a tool
        tool.parameters.first { $0.name == name }
    }

    // MARK: - Private Helpers

    /// Convert an AgentTool to PeekabooToolDefinition
    private static func convertAgentToolToDefinition(_ tool: AgentTool) -> PeekabooToolDefinition? {
        // Map common tool names to categories
        let category: ToolCategory = switch tool.name {
        case "see", "screenshot", "window_capture":
            .vision
        case "click", "type", "press", "scroll", "hotkey":
            .ui
        case "list_apps", "launch_app":
            .application
        case "menu_click", "list_menus":
            .menu
        case "dialog_click", "dialog_input":
            .dialog
        case "dock_launch", "list_dock":
            .dock
        case "shell":
            .system
        case "done", "need_info":
            .completion
        default:
            .system
        }

        // Convert parameters from agent tool schema
        let parameters = self.convertAgentParameters(tool.parameters)

        return PeekabooToolDefinition(
            name: tool.name,
            commandName: tool.name.replacingOccurrences(of: "_", with: "-"),
            abstract: tool.description,
            discussion: tool.description,
            category: category,
            parameters: parameters,
            examples: [],
            agentGuidance: "")
    }

    /// Convert agent tool parameters to parameter definitions
    private static func convertAgentParameters(_ params: AgentToolParameters?) -> [ParameterDefinition] {
        // Convert agent tool parameters to parameter definitions
        guard let params else { return [] }

        var definitions: [ParameterDefinition] = []

        // Extract properties from the schema
        for (name, property) in params.properties {
            let type: UnifiedParameterType = switch property.type {
            case .string:
                .string
            case .number:
                .number
            case .integer:
                .integer
            case .boolean:
                .boolean
            case .array:
                .array
            case .object:
                .object
            case .null:
                .string
            }

            let isRequired = params.required.contains(name)

            definitions.append(ParameterDefinition(
                name: name,
                type: type,
                description: property.description,
                required: isRequired,
                defaultValue: nil,
                options: property.enumValues,
                cliOptions: CLIOptions(argumentType: isRequired ? .argument : .option)))
        }

        return definitions
    }
}
