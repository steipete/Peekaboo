//
//  PeekabooAgentService+Tools.swift
//  PeekabooCore
//

import Foundation
import MCP
import Tachikoma
import TachikomaMCP
import PeekabooAutomation

// MARK: - Tool Creation Extension

@available(macOS 14.0, *)
extension PeekabooAgentService {
    private func makeToolContext() -> MCPToolContext {
        MCPToolContext(services: self.services)
    }

    // MARK: - Vision Tools

    public func createSeeTool() -> AgentTool {
        let tool = SeeTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createImageTool() -> AgentTool {
        let tool = ImageTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - UI Automation Tools

    public func createClickTool() -> AgentTool {
        let tool = ClickTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createTypeTool() -> AgentTool {
        let tool = TypeTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createScrollTool() -> AgentTool {
        let tool = ScrollTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createHotkeyTool() -> AgentTool {
        let tool = HotkeyTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createDragTool() -> AgentTool {
        let tool = DragTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createMoveTool() -> AgentTool {
        let tool = MoveTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Vision Tools

    public func createAnalyzeTool() -> AgentTool {
        let tool = AnalyzeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - List Tool (Full Access)

    public func createListTool() -> AgentTool {
        let tool = ListTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Screen Tools

    public func createListScreensTool() -> AgentTool {
        let tool = ListTool(context: self.makeToolContext())
        return AgentTool(
            name: "list_screens",
            description: "List all available screens/displays",
            parameters: AgentToolParameters(
                properties: [:],
                required: []),
            execute: { _ in
                let args = makeToolArguments(fromDict: ["item_type": "screens"])
                let response = try await tool.execute(arguments: args)
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Application Tools

    public func createListAppsTool() -> AgentTool {
        let tool = ListTool(context: self.makeToolContext())
        return AgentTool(
            name: "list_apps",
            description: "List running applications",
            parameters: AgentToolParameters(
                properties: [:],
                required: []),
            execute: { _ in
                let args = makeToolArguments(fromDict: ["item_type": "running_applications"])
                let response = try await tool.execute(arguments: args)
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createLaunchAppTool() -> AgentTool {
        let tool = AppTool(context: self.makeToolContext())
        return AgentTool(
            name: "launch_app",
            description: "Launch an application",
            parameters: AgentToolParameters(
                properties: [
                    "name": AgentToolParameterProperty(
                        name: "name",
                        type: .string,
                        description: "Application name to launch"),
                ],
                required: ["name"]),
            execute: { arguments in
                var argsDict = dictionaryFromArguments(arguments)
                argsDict["action"] = AnyAgentToolValue(string: "launch")
                let newArgs = AgentToolArguments(argsDict)
                let response = try await tool.execute(arguments: makeToolArguments(from: newArgs))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Space Management

    public func createSpaceTool() -> AgentTool {
        let tool = SpaceTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Window Management

    public func createWindowTool() -> AgentTool {
        let tool = WindowTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Menu Interaction

    public func createMenuTool() -> AgentTool {
        let tool = MenuTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Dialog Handling

    public func createDialogTool() -> AgentTool {
        let tool = DialogTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Dock Management

    public func createDockTool() -> AgentTool {
        let tool = DockTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Timing Control

    public func createSleepTool() -> AgentTool {
        let tool = SleepTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Gesture Support

    public func createSwipeTool() -> AgentTool {
        let tool = SwipeTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Permissions Check

    public func createPermissionsTool() -> AgentTool {
        let tool = PermissionsTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Full App Management

    public func createAppTool() -> AgentTool {
        let tool = AppTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Shell Tool

    public func createShellTool() -> AgentTool {
        let tool = ShellTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Completion Tools

    public func createDoneTool() -> AgentTool {
        AgentTool(
            name: "done",
            description: "Indicate that the task is complete",
            parameters: AgentToolParameters(
                properties: [
                    "message": AgentToolParameterProperty(
                        name: "message",
                        type: .string,
                        description: "Completion message"),
                ],
                required: []),
            execute: { arguments in
                let message: String = if let messageArg = arguments["message"],
                                         let msg = messageArg.stringValue
                {
                    msg
                } else {
                    "Task completed successfully"
                }
                return AnyAgentToolValue(string: "\(AgentDisplayTokens.Status.success) \(message)")
            })
    }

    public func createNeedInfoTool() -> AgentTool {
        AgentTool(
            name: "need_info",
            description: "Request additional information from the user",
            parameters: AgentToolParameters(
                properties: [
                    "question": AgentToolParameterProperty(
                        name: "question",
                        type: .string,
                        description: "Question to ask the user"),
                ],
                required: ["question"]),
            execute: { arguments in
                guard let questionArg = arguments["question"],
                      let question = questionArg.stringValue
                else {
                    return AnyAgentToolValue(string: "Please provide a question")
                }
                return AnyAgentToolValue(string: "\(AgentDisplayTokens.Status.info) Need more information: \(question)")
            })
    }

    // MARK: - Helper Functions

    private func convertMCPSchemaToAgentSchema(_ mcpSchema: Value) -> AgentToolParameters {
        guard case let .object(schemaDict) = mcpSchema,
              let propertiesValue = schemaDict["properties"],
              case let .object(properties) = propertiesValue
        else {
            return AgentToolParameters(properties: [:], required: [])
        }

        var agentProperties: [String: AgentToolParameterProperty] = [:]
        for (key, value) in properties {
            guard let property = self.makeAgentToolProperty(name: key, value: value) else { continue }
            agentProperties[key] = property
        }

        return AgentToolParameters(
            properties: agentProperties,
            required: self.requiredFields(from: schemaDict))
    }

    private func requiredFields(from schemaDict: [String: Value]) -> [String] {
        guard case let .array(requiredValues) = schemaDict["required"] else { return [] }
        return requiredValues.compactMap { value in
            if case let .string(str) = value { str } else { nil }
        }
    }

    private func makeAgentToolProperty(name: String, value: Value) -> AgentToolParameterProperty? {
        guard case let .object(propDict) = value,
              let typeValue = propDict["type"],
              case let .string(typeStr) = typeValue
        else {
            return nil
        }

        let paramType = AgentToolParameterProperty.ParameterType(rawValue: typeStr) ?? .string
        let description = self.descriptionValue(from: propDict["description"])
        let enumValues = self.enumValues(from: propDict["enum"])
        let items = self.itemsDefinition(for: paramType, itemsValue: propDict["items"])

        return AgentToolParameterProperty(
            name: name,
            type: paramType,
            description: description,
            enumValues: enumValues,
            items: items)
    }

    private func descriptionValue(from value: Value?) -> String {
        guard case let .string(description) = value else { return "" }
        return description
    }

    private func enumValues(from value: Value?) -> [String]? {
        guard case let .array(enumArray) = value else { return nil }
        let values = enumArray.compactMap { element -> String? in
            if case let .string(str) = element { str } else { nil }
        }
        return values.isEmpty ? nil : values
    }

    private func itemsDefinition(
        for parameterType: AgentToolParameterProperty.ParameterType,
        itemsValue: Value?) -> AgentToolParameterItems?
    {
        guard parameterType == .array else { return nil }

        guard case let .object(itemsDict) = itemsValue else {
            return AgentToolParameterItems(type: AgentToolParameterProperty.ParameterType.string.rawValue)
        }

        let itemType: AgentToolParameterProperty.ParameterType = if case let .string(typeString) = itemsDict["type"],
                                                                    let resolved = AgentToolParameterProperty
                                                                        .ParameterType(rawValue: typeString)
        {
            resolved
        } else {
            .string
        }

        return AgentToolParameterItems(
            type: itemType.rawValue,
            description: self.descriptionValue(from: itemsDict["description"]))
    }
}

// MARK: - Type Conversion Extensions

// MARK: ToolArguments Extension

extension ToolArguments {
    /// Initialize from AgentToolArguments
    init(from arguments: AgentToolArguments) {
        // Convert AgentToolArguments to [String: Any]
        var dict: [String: Any] = [:]
        for key in arguments.keys {
            guard let value = arguments[key], let json = try? value.toJSON() else { continue }
            dict[key] = json
        }
        self.init(raw: dict)
    }

    /// Initialize from dictionary
    init(from dict: [String: Any]) {
        self.init(raw: dict)
    }
}

// MARK: - Extension implementations moved to TypedValueBridge.swift

// All Value and AnyAgentToolValue conversion extensions are now centralized in TypedValueBridge
// to eliminate code duplication and use the unified TypedValue system

// MARK: - Helper function to convert ToolResponse to AnyAgentToolValue

@preconcurrency
func convertToolResponseToAgentToolResult(_ response: ToolResponse) -> AnyAgentToolValue {
    // If there's an error, return error message
    if response.isError {
        let errorMessage = response.content.compactMap { content -> String? in
            if case let .text(text) = content {
                return text
            }
            return nil
        }.joined(separator: "\n")

        return AnyAgentToolValue(string: "Error: \(errorMessage)")
    }

    // Convert the first content item to a result
    if let firstContent = response.content.first {
        switch firstContent {
        case let .text(text):
            return AnyAgentToolValue(string: text)
        case let .image(data, mimeType, _):
            // For images, return a descriptive string
            return AnyAgentToolValue(string: "[Image: \(mimeType), size: \(data.count) bytes]")
        case let .resource(uri, _, text):
            // For resources, return the text content if available
            return AnyAgentToolValue(string: text ?? "[Resource: \(uri)]")
        case let .audio(data, mimeType):
            return AnyAgentToolValue(string: "[Audio: \(mimeType), size: \(data.count) bytes]")
        }
    }

    // No content
    return AnyAgentToolValue(string: "Success")
}

@preconcurrency
func convertToolResponseToAgentToolResultAsync(_ response: ToolResponse) async -> AnyAgentToolValue {
    convertToolResponseToAgentToolResult(response)
}

private func makeToolArguments(from arguments: AgentToolArguments) -> ToolArguments {
    ToolArguments(from: arguments)
}

private func makeToolArguments(fromDict dict: [String: Any]) -> ToolArguments {
    ToolArguments(from: dict)
}

private func dictionaryFromArguments(_ arguments: AgentToolArguments) -> [String: AnyAgentToolValue] {
    var dict: [String: AnyAgentToolValue] = [:]
    for key in arguments.keys {
        if let value = arguments[key] {
            dict[key] = value
        }
    }
    return dict
}
