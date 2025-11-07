//
//  PeekabooAgentService+Tools.swift
//  PeekabooCore
//

import Foundation
import MCP
import Tachikoma
import TachikomaMCP

// MARK: - Tool Creation Extension

@available(macOS 14.0, *)
extension PeekabooAgentService {
    // MARK: - Vision Tools

    public func createSeeTool() -> AgentTool {
        let tool = SeeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createImageTool() -> AgentTool {
        let tool = ImageTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - UI Automation Tools

    public func createClickTool() -> AgentTool {
        let tool = ClickTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createTypeTool() -> AgentTool {
        let tool = TypeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createScrollTool() -> AgentTool {
        let tool = ScrollTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createHotkeyTool() -> AgentTool {
        let tool = HotkeyTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createDragTool() -> AgentTool {
        let tool = DragTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createMoveTool() -> AgentTool {
        let tool = MoveTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
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
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - List Tool (Full Access)

    public func createListTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Screen Tools

    public func createListScreensTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: "list_screens",
            description: "List all available screens/displays",
            parameters: AgentToolParameters(
                properties: [:],
                required: []),
            execute: { _ in
                let args = await makeToolArguments(fromDict: ["item_type": "screens"])
                let response = try await tool.execute(arguments: args)
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Application Tools

    public func createListAppsTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: "list_apps",
            description: "List running applications",
            parameters: AgentToolParameters(
                properties: [:],
                required: []),
            execute: { _ in
                let args = await makeToolArguments(fromDict: ["item_type": "running_applications"])
                let response = try await tool.execute(arguments: args)
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createLaunchAppTool() -> AgentTool {
        let tool = AppTool()
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
                var argsDict = await dictionaryFromArguments(arguments)
                argsDict["action"] = AnyAgentToolValue(string: "launch")
                let newArgs = AgentToolArguments(argsDict)
                let response = try await tool.execute(arguments: await makeToolArguments(from: newArgs))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Space Management

    public func createSpaceTool() -> AgentTool {
        let tool = SpaceTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Window Management

    public func createWindowTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Menu Interaction

    public func createMenuTool() -> AgentTool {
        let tool = MenuTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Dialog Handling

    public func createDialogTool() -> AgentTool {
        let tool = DialogTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Dock Management

    public func createDockTool() -> AgentTool {
        let tool = DockTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
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
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Gesture Support

    public func createSwipeTool() -> AgentTool {
        let tool = SwipeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Permissions Check

    public func createPermissionsTool() -> AgentTool {
        let tool = PermissionsTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Full App Management

    public func createAppTool() -> AgentTool {
        let tool = AppTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
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
                let response = try await tool.execute(arguments: await makeToolArguments(from: arguments))
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
        // Convert MCP Value schema to AgentToolParameters
        guard case let .object(schemaDict) = mcpSchema,
              let propertiesValue = schemaDict["properties"],
              case let .object(properties) = propertiesValue
        else {
            return AgentToolParameters(properties: [:], required: [])
        }

        var agentProperties: [String: AgentToolParameterProperty] = [:]
        var required: [String] = []

        // Get required fields
        if let requiredValue = schemaDict["required"],
           case let .array(requiredArray) = requiredValue
        {
            required = requiredArray.compactMap { value in
                if case let .string(str) = value {
                    return str
                }
                return nil
            }
        }

        // Convert properties
        for (key, value) in properties {
            guard case let .object(propDict) = value else { continue }

            let description = propDict["description"].flatMap { value in
                if case let .string(desc) = value {
                    return desc
                }
                return nil
            } ?? ""

            guard let typeValue = propDict["type"],
                  case let .string(typeStr) = typeValue
            else {
                continue
            }

            let paramType = AgentToolParameterProperty.ParameterType(rawValue: typeStr) ?? .string

            var enumValues: [String]?
            if let enumValue = propDict["enum"],
               case let .array(enumArray) = enumValue
            {
                enumValues = enumArray.compactMap { value in
                    if case let .string(str) = value {
                        return str
                    }
                    return nil
                }
            }

            var items: AgentToolParameterItems?
            if paramType == .array {
                if let itemsValue = propDict["items"],
                   case let .object(itemsDict) = itemsValue
                {
                    var itemType: AgentToolParameterProperty.ParameterType = .string

                    if let itemTypeValue = itemsDict["type"],
                       case let .string(itemTypeStr) = itemTypeValue
                    {
                        itemType = AgentToolParameterProperty.ParameterType(rawValue: itemTypeStr) ?? .string
                    }

                    items = AgentToolParameterItems(
                        type: itemType.rawValue,
                        description: itemsDict["description"].flatMap { value in
                            if case let .string(desc) = value {
                                return desc
                            }
                            return nil
                        })
                    // Note: enum values on items are not currently supported by AgentToolParameterItems
                } else {
                    items = AgentToolParameterItems(
                        type: AgentToolParameterProperty.ParameterType.string.rawValue)
                }
            }

            agentProperties[key] = AgentToolParameterProperty(
                name: key,
                type: paramType,
                description: description,
                enumValues: enumValues,
                items: items)
        }

        return AgentToolParameters(properties: agentProperties, required: required)
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
            if let value = arguments[key] {
                dict[key] = try! value.toJSON() // AnyAgentToolValue has toJSON()
            }
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

private func makeToolArguments(from arguments: AgentToolArguments) async -> ToolArguments {
    await MainActor.run {
        ToolArguments(from: arguments)
    }
}

private func makeToolArguments(fromDict dict: [String: Any]) async -> ToolArguments {
    await MainActor.run {
        ToolArguments(from: dict)
    }
}

private func dictionaryFromArguments(_ arguments: AgentToolArguments) async -> [String: AnyAgentToolValue] {
    await MainActor.run {
        var dict: [String: AnyAgentToolValue] = [:]
        for key in arguments.keys {
            if let value = arguments[key] {
                dict[key] = value
            }
        }
        return dict
    }
}
