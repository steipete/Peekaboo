//
//  PeekabooAgentService+Tools.swift
//  PeekabooCore
//

import Foundation
import Tachikoma
import TachikomaMCP
import MCP

// MARK: - Tool Creation Extension

@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    // MARK: - Vision Tools
    
    public func createSeeTool() -> AgentTool {
        let tool = SeeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createImageTool() -> AgentTool {
        let tool = ImageTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - UI Automation Tools
    
    public func createClickTool() -> AgentTool {
        let tool = ClickTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createTypeTool() -> AgentTool {
        let tool = TypeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createScrollTool() -> AgentTool {
        let tool = ScrollTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createHotkeyTool() -> AgentTool {
        let tool = HotkeyTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createDragTool() -> AgentTool {
        let tool = DragTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createMoveTool() -> AgentTool {
        let tool = MoveTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Vision Tools
    
    public func createAnalyzeTool() -> AgentTool {
        let tool = AnalyzeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - List Tool (Full Access)
    
    public func createListTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Screen Tools
    
    public func createListScreensTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: "list_screens",
            description: "List all available screens/displays",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            execute: { _ in
                let args = ToolArguments(from: ["item_type": "screens"])
                let response = try await tool.execute(arguments: args)
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Application Tools
    
    public func createListAppsTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: "list_apps",
            description: "List running applications",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            execute: { _ in
                let args = ToolArguments(from: ["item_type": "running_applications"])
                let response = try await tool.execute(arguments: args)
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createLaunchAppTool() -> AgentTool {
        let tool = AppTool()
        return AgentTool(
            name: "launch_app",
            description: "Launch an application",
            parameters: AgentToolParameters(
                properties: [
                    "name": AgentToolParameterProperty(name: "name", type: .string, description: "Application name to launch")
                ],
                required: ["name"]
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "launch"
                let newArgs = AgentToolArguments(argsDict.mapValues { AnyAgentToolValue.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Space Management
    
    public func createSpaceTool() -> AgentTool {
        let tool = SpaceTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Window Management
    
    public func createWindowTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Menu Interaction
    
    public func createMenuTool() -> AgentTool {
        let tool = MenuTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Dialog Handling
    
    public func createDialogTool() -> AgentTool {
        let tool = DialogTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Dock Management
    
    public func createDockTool() -> AgentTool {
        let tool = DockTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Timing Control
    
    public func createSleepTool() -> AgentTool {
        let tool = SleepTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Gesture Support
    
    public func createSwipeTool() -> AgentTool {
        let tool = SwipeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Permissions Check
    
    public func createPermissionsTool() -> AgentTool {
        let tool = PermissionsTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Full App Management
    
    public func createAppTool() -> AgentTool {
        let tool = AppTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Shell Tool
    
    public func createShellTool() -> AgentTool {
        let tool = ShellTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Completion Tools
    
    public func createDoneTool() -> AgentTool {
        return AgentTool(
            name: "done",
            description: "Indicate that the task is complete",
            parameters: AgentToolParameters(
                properties: [
                    "message": AgentToolParameterProperty(name: "message", type: .string, description: "Completion message")
                ],
                required: []
            ),
            execute: { arguments in
                let message: String
                if let messageArg = arguments["message"],
                   let msg = messageArg.stringValue {
                    message = msg
                } else {
                    message = "Task completed successfully"
                }
                return AnyAgentToolValue(string: "✅ \(message)")
            }
        )
    }
    
    public func createNeedInfoTool() -> AgentTool {
        return AgentTool(
            name: "need_info",
            description: "Request additional information from the user",
            parameters: AgentToolParameters(
                properties: [
                    "question": AgentToolParameterProperty(name: "question", type: .string, description: "Question to ask the user")
                ],
                required: ["question"]
            ),
            execute: { arguments in
                guard let questionArg = arguments["question"],
                      let question = questionArg.stringValue else {
                    return AnyAgentToolValue(string: "Please provide a question")
                }
                return AnyAgentToolValue(string: "❓ Need more information: \(question)")
            }
        )
    }
    
    // MARK: - Helper Functions
    
    private func convertMCPSchemaToAgentSchema(_ mcpSchema: Value) -> AgentToolParameters {
        // Convert MCP Value schema to AgentToolParameters
        guard case let .object(schemaDict) = mcpSchema,
              let propertiesValue = schemaDict["properties"],
              case let .object(properties) = propertiesValue else {
            return AgentToolParameters(properties: [:], required: [])
        }
        
        var agentProperties: [String: AgentToolParameterProperty] = [:]
        var required: [String] = []
        
        // Get required fields
        if let requiredValue = schemaDict["required"],
           case let .array(requiredArray) = requiredValue {
            required = requiredArray.compactMap { value in
                if case let .string(str) = value {
                    return str
                }
                return nil
            }
        }
        
        // Convert properties
        for (key, value) in properties {
            if case let .object(propDict) = value {
                let description = propDict["description"].flatMap { value in
                    if case let .string(desc) = value {
                        return desc
                    }
                    return nil
                } ?? ""
                
                // Determine type
                if let typeValue = propDict["type"],
                   case let .string(typeStr) = typeValue {
                    let paramType: AgentToolParameterProperty.ParameterType
                    switch typeStr {
                    case "string":
                        paramType = .string
                    case "number":
                        paramType = .number
                    case "integer":
                        paramType = .integer
                    case "boolean":
                        paramType = .boolean
                    case "array":
                        paramType = .array
                    case "object":
                        paramType = .object
                    default:
                        paramType = .string
                    }
                    
                    // Handle array items if present
                    var items: AgentToolParameterItems? = nil
                    if typeStr == "array", let itemsValue = propDict["items"],
                       case let .object(itemsDict) = itemsValue {
                        // Extract item type
                        if let itemTypeValue = itemsDict["type"],
                           case let .string(itemTypeStr) = itemTypeValue {
                            let itemType: AgentToolParameterProperty.ParameterType
                            switch itemTypeStr {
                            case "string":
                                itemType = .string
                            case "number":
                                itemType = .number
                            case "integer":
                                itemType = .integer
                            case "boolean":
                                itemType = .boolean
                            case "object":
                                itemType = .object
                            default:
                                itemType = .string
                            }
                            
                            // Extract enum values if present
                            var enumValues: [String]? = nil
                            if let enumValue = itemsDict["enum"],
                               case let .array(enumArray) = enumValue {
                                enumValues = enumArray.compactMap { value in
                                    if case let .string(str) = value {
                                        return str
                                    }
                                    return nil
                                }
                            }
                            
                            items = AgentToolParameterItems(type: itemType, enumValues: enumValues)
                        }
                    }
                    
                    // For array types, ensure we always have items (default to string if not specified)
                    let finalItems: AgentToolParameterItems? = if paramType == .array {
                        items ?? AgentToolParameterItems(type: .string)
                    } else {
                        items
                    }
                    
                    agentProperties[key] = AgentToolParameterProperty(
                        name: key,
                        type: paramType,
                        description: description,
                        items: finalItems
                    )
                }
            }
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
                dict[key] = try! value.toJSON()  // AnyAgentToolValue has toJSON()
            }
        }
        self.init(raw: dict)
    }
    
    /// Initialize from dictionary
    init(from dict: [String: Any]) {
        self.init(raw: dict)
    }
}

// MARK: AnyAgentToolValue Extension for Interop
extension AnyAgentToolValue {
    /// Convert to Any type for interop
    func toAny() -> Any {
        do {
            return try self.toJSON()
        } catch {
            // Fallback to string representation if conversion fails
            return String(describing: self)
        }
    }
    
    /// Initialize from Any type
    static func from(_ any: Any) -> AnyAgentToolValue {
        do {
            return try AnyAgentToolValue.fromJSON(any)
        } catch {
            // Fallback: convert to string representation
            return AnyAgentToolValue(string: String(describing: any))
        }
    }
    
    /// Convert to Value for MCP interop
    func toValue() -> Value {
        if let str = self.stringValue {
            return .string(str)
        } else if let num = self.intValue {
            return .int(num)
        } else if let num = self.doubleValue {
            return .double(num)
        } else if let bool = self.boolValue {
            return .bool(bool)
        } else if let array = self.arrayValue {
            return .array(array.map { $0.toValue() })
        } else if let dict = self.objectValue {
            return .object(dict.mapValues { $0.toValue() })
        } else if self.isNull {
            return .null
        } else {
            return .null
        }
    }
}

// MARK: Value Extension
extension Value {
    /// Convert from Any type
    static func from(_ any: Any) -> Value {
        switch any {
        case let str as String:
            return .string(str)
        case let num as Int:
            return .int(num)
        case let num as Double:
            return .double(num)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { Value.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { Value.from($0) })
        case is NSNull:
            return .null
        default:
            // Fallback: convert to string representation
            return .string(String(describing: any))
        }
    }
    
    /// Convert to AnyAgentToolValue
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        switch self {
        case .string(let str):
            return AnyAgentToolValue(string: str)
        case .int(let num):
            return AnyAgentToolValue(int: num)
        case .double(let num):
            return AnyAgentToolValue(double: num)
        case .bool(let bool):
            return AnyAgentToolValue(bool: bool)
        case .array(let array):
            return AnyAgentToolValue(array: array.map { $0.toAnyAgentToolValue() })
        case .object(let dict):
            return AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue() })
        case .null:
            return AnyAgentToolValue(null: ())
        case .data(let mimeType, let data):
            // Convert data to a special object representation
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "data"),
                "mimeType": AnyAgentToolValue(string: mimeType ?? "application/octet-stream"),
                "dataSize": AnyAgentToolValue(int: data.count)
            ])
        }
    }
}

// MARK: - Helper function to convert ToolResponse to AnyAgentToolValue

private func convertToolResponseToAgentToolResult(_ response: ToolResponse) -> AnyAgentToolValue {
    // If there's an error, return error message
    if response.isError {
        let errorMessage = response.content.compactMap { content -> String? in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined(separator: "\n")
        
        return AnyAgentToolValue(string: "Error: \(errorMessage)")
    }
    
    // Convert the first content item to a result
    if let firstContent = response.content.first {
        switch firstContent {
        case .text(let text):
            return AnyAgentToolValue(string: text)
        case .image(let data, let mimeType, _):
            // For images, return a descriptive string
            return AnyAgentToolValue(string: "[Image: \(mimeType), size: \(data.count) bytes]")
        case .resource(let uri, _, let text):
            // For resources, return the text content if available
            return AnyAgentToolValue(string: text ?? "[Resource: \(uri)]")
        case .audio(let data, let mimeType):
            return AnyAgentToolValue(string: "[Audio: \(mimeType), size: \(data.count) bytes]")
        }
    }
    
    // No content
    return AnyAgentToolValue(string: "Success")
}

// MARK: - Helper Extensions

extension AgentToolArguments {
    /// Convert to dictionary for mutation
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for key in self.keys {
            if let value = self[key] {
                dict[key] = value.toAny()
            }
        }
        return dict
    }
}