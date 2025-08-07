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
    
    public func createScreenshotTool() -> AgentTool {
        let tool = ImageTool()
        return AgentTool(
            name: "screenshot",
            description: "Take a screenshot of the screen or a specific window",
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: ToolArguments(from: arguments))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createWindowCaptureTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "window_capture",
            description: "Capture or manipulate application windows",
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
    
    public func createPressTool() -> AgentTool {
        let tool = HotkeyTool()
        return AgentTool(
            name: "press",
            description: "Press keyboard keys or key combinations",
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
    
    // MARK: - Window Management Tools
    
    public func createListWindowsTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "list_windows",
            description: "List all open windows",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            execute: { _ in
                let args = ToolArguments(from: ["action": "list"])
                let response = try await tool.execute(arguments: args)
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createFocusWindowTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "focus_window",
            description: "Focus a specific window",
            parameters: AgentToolParameters(
                properties: [
                    "app": AgentToolParameterProperty(name: "app", type: .string, description: "Application name"),
                    "index": AgentToolParameterProperty(name: "index", type: .integer, description: "Window index")
                ],
                required: ["app"]
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "focus"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createResizeWindowTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "resize_window",
            description: "Resize a window",
            parameters: AgentToolParameters(
                properties: [
                    "app": AgentToolParameterProperty(name: "app", type: .string, description: "Application name"),
                    "width": AgentToolParameterProperty(name: "width", type: .number, description: "New width"),
                    "height": AgentToolParameterProperty(name: "height", type: .number, description: "New height")
                ],
                required: ["app", "width", "height"]
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "resize"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
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
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Element Tools
    
    public func createFindElementTool() -> AgentTool {
        return AgentTool(
            name: "find_element",
            description: "Find a UI element by text or role",
            parameters: AgentToolParameters(
                properties: [
                    "text": AgentToolParameterProperty(name: "text", type: .string, description: "Text to search for"),
                    "role": AgentToolParameterProperty(name: "role", type: .string, description: "Element role/type")
                ],
                required: []
            ),
            execute: { arguments in
                // This would need to be implemented using ElementDetectionService
                .string("Element finding not yet implemented")
            }
        )
    }
    
    public func createListElementsTool() -> AgentTool {
        return AgentTool(
            name: "list_elements",
            description: "List all UI elements in the current context",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            execute: { arguments in
                // This would need to be implemented using ElementDetectionService
                .string("Element listing not yet implemented")
            }
        )
    }
    
    public func createFocusedTool() -> AgentTool {
        return AgentTool(
            name: "get_focused",
            description: "Get the currently focused UI element",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            execute: { arguments in
                // This would need to be implemented using FocusService
                .string("Focus detection not yet implemented")
            }
        )
    }
    
    // MARK: - Menu Tools
    
    public func createMenuClickTool() -> AgentTool {
        let tool = MenuTool()
        return AgentTool(
            name: "menu_click",
            description: "Click on a menu item",
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "click"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createListMenusTool() -> AgentTool {
        let tool = MenuTool()
        return AgentTool(
            name: "list_menus",
            description: "List available menu items",
            parameters: AgentToolParameters(
                properties: [
                    "app": AgentToolParameterProperty(name: "app", type: .string, description: "Application name")
                ],
                required: []
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "list"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Dialog Tools
    
    public func createDialogClickTool() -> AgentTool {
        let tool = DialogTool()
        return AgentTool(
            name: "dialog_click",
            description: "Click a button in a dialog",
            parameters: AgentToolParameters(
                properties: [
                    "button": AgentToolParameterProperty(name: "button", type: .string, description: "Button text to click")
                ],
                required: ["button"]
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "click"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createDialogInputTool() -> AgentTool {
        let tool = DialogTool()
        return AgentTool(
            name: "dialog_input",
            description: "Enter text in a dialog field",
            parameters: AgentToolParameters(
                properties: [
                    "text": AgentToolParameterProperty(name: "text", type: .string, description: "Text to enter"),
                    "field": AgentToolParameterProperty(name: "field", type: .string, description: "Field identifier")
                ],
                required: ["text"]
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "input"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Dock Tools
    
    public func createDockLaunchTool() -> AgentTool {
        let tool = DockTool()
        return AgentTool(
            name: "dock_launch",
            description: "Launch an app from the dock",
            parameters: AgentToolParameters(
                properties: [
                    "app": AgentToolParameterProperty(name: "app", type: .string, description: "Application name")
                ],
                required: ["app"]
            ),
            execute: { arguments in
                var argsDict = arguments.toDictionary()
                argsDict["action"] = "launch"
                let newArgs = AgentToolArguments(argsDict.mapValues { AgentToolArgument.from($0) })
                let response = try await tool.execute(arguments: ToolArguments(from: newArgs))
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    public func createListDockTool() -> AgentTool {
        let tool = DockTool()
        return AgentTool(
            name: "list_dock",
            description: "List apps in the dock",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            execute: { _ in
                let args = ToolArguments(from: ["action": "list"])
                let response = try await tool.execute(arguments: args)
                return convertToolResponseToAgentToolResult(response)
            }
        )
    }
    
    // MARK: - Shell Tool
    
    public func createShellTool() -> AgentTool {
        return AgentTool(
            name: "shell",
            description: "Execute shell commands",
            parameters: AgentToolParameters(
                properties: [
                    "command": AgentToolParameterProperty(name: "command", type: .string, description: "Shell command to execute")
                ],
                required: ["command"]
            ),
            execute: { arguments in
                guard let command = arguments["command"] as? String else {
                    return .string("Command is required")
                }
                
                // Execute shell command
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus != 0 {
                        return .string("Command failed: \(error.isEmpty ? output : error)")
                    }
                    
                    return .string(output)
                } catch {
                    return .string("Failed to execute command: \(error.localizedDescription)")
                }
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
                let message = arguments["message"] as? String ?? "Task completed successfully"
                return .string("✅ \(message)")
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
                guard let question = arguments["question"] as? String else {
                    return .string("Please provide a question")
                }
                return .string("❓ Need more information: \(question)")
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
                    let paramType: ParameterType
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
                    agentProperties[key] = AgentToolParameterProperty(
                        name: key,
                        type: paramType,
                        description: description
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
                dict[key] = value.toAny()
            }
        }
        self.init(raw: dict)
    }
    
    /// Initialize from dictionary
    init(from dict: [String: Any]) {
        self.init(raw: dict)
    }
}

// MARK: AgentToolArgument Extension
extension AgentToolArgument {
    /// Convert to Any type for interop
    func toAny() -> Any {
        switch self {
        case .string(let str):
            return str
        case .int(let num):
            return num
        case .double(let num):
            return num
        case .bool(let bool):
            return bool
        case .array(let array):
            return array.map { $0.toAny() }
        case .object(let dict):
            return dict.mapValues { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
    
    /// Initialize from Any type
    static func from(_ any: Any) -> AgentToolArgument {
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
            return .array(array.map { AgentToolArgument.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { AgentToolArgument.from($0) })
        case is NSNull:
            return .null
        default:
            // Fallback: convert to string representation
            return .string(String(describing: any))
        }
    }
    
    /// Convert to Value for MCP interop
    func toValue() -> Value {
        switch self {
        case .string(let str):
            return .string(str)
        case .int(let num):
            return .int(num)
        case .double(let num):
            return .double(num)
        case .bool(let bool):
            return .bool(bool)
        case .array(let array):
            return .array(array.map { $0.toValue() })
        case .object(let dict):
            return .object(dict.mapValues { $0.toValue() })
        case .null:
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
    
    /// Convert to AgentToolArgument
    func toAgentToolArgument() -> AgentToolArgument {
        switch self {
        case .string(let str):
            return .string(str)
        case .int(let num):
            return .int(num)
        case .double(let num):
            return .double(num)
        case .bool(let bool):
            return .bool(bool)
        case .array(let array):
            return .array(array.map { $0.toAgentToolArgument() })
        case .object(let dict):
            return .object(dict.mapValues { $0.toAgentToolArgument() })
        case .null:
            return .null
        }
    }
}

// MARK: - Helper function to convert ToolResponse to AgentToolArgument

private func convertToolResponseToAgentToolResult(_ response: ToolResponse) -> AgentToolArgument {
    // If there's an error, return error message
    if response.isError {
        let errorMessage = response.content.compactMap { content -> String? in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined(separator: "\n")
        
        return .string("Error: \(errorMessage)")
    }
    
    // Convert the first content item to a result
    if let firstContent = response.content.first {
        switch firstContent {
        case .text(let text):
            return .string(text)
        case .image(let data, let mimeType, _):
            // For images, return a descriptive string
            return .string("[Image: \(mimeType), size: \(data.count) bytes]")
        case .resource(let uri, _, let text):
            // For resources, return the text content if available
            return .string(text ?? "[Resource: \(uri)]")
        case .audio(let data, let mimeType):
            return .string("[Audio: \(mimeType), size: \(data.count) bytes]")
        }
    }
    
    // No content
    return .string("Success")
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