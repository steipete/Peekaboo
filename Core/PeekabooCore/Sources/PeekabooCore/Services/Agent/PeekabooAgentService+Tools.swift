//
//  PeekabooAgentService+Tools.swift
//  PeekabooCore
//

import Foundation
import Tachikoma
import MCP

// MARK: - Tool Creation Extension

@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    // MARK: - Vision Tools
    
    func createSeeTool() -> AgentTool {
        let tool = SeeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    func createScreenshotTool() -> AgentTool {
        let tool = ImageTool()
        return AgentTool(
            name: "screenshot",
            description: "Take a screenshot of the screen or a specific window",
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    func createWindowCaptureTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "window_capture",
            description: "Capture or manipulate application windows",
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    // MARK: - UI Automation Tools
    
    func createClickTool() -> AgentTool {
        let tool = ClickTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    func createTypeTool() -> AgentTool {
        let tool = TypeTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    func createPressTool() -> AgentTool {
        let tool = HotkeyTool()
        return AgentTool(
            name: "press",
            description: "Press keyboard keys or key combinations",
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    func createScrollTool() -> AgentTool {
        let tool = ScrollTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    func createHotkeyTool() -> AgentTool {
        let tool = HotkeyTool()
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                try await tool.execute(arguments: ToolArguments(from: arguments))
                    .toAgentToolResult()
            }
        )
    }
    
    // MARK: - Window Management Tools
    
    func createListWindowsTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "list_windows",
            description: "List all open windows",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                let args = ToolArguments(from: ["action": "list"])
                return try await tool.execute(arguments: args).toAgentToolResult()
            }
        )
    }
    
    func createFocusWindowTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "focus_window",
            description: "Focus a specific window",
            parameters: AgentToolParameters(
                properties: [
                    "app": .string(description: "Application name"),
                    "index": .integer(description: "Window index")
                ],
                required: ["app"]
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "focus"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    func createResizeWindowTool() -> AgentTool {
        let tool = WindowTool()
        return AgentTool(
            name: "resize_window",
            description: "Resize a window",
            parameters: AgentToolParameters(
                properties: [
                    "app": .string(description: "Application name"),
                    "width": .number(description: "New width"),
                    "height": .number(description: "New height")
                ],
                required: ["app", "width", "height"]
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "resize"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    func createListScreensTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: "list_screens",
            description: "List all available screens/displays",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                let args = ToolArguments(from: ["item_type": "screens"])
                return try await tool.execute(arguments: args).toAgentToolResult()
            }
        )
    }
    
    // MARK: - Application Tools
    
    func createListAppsTool() -> AgentTool {
        let tool = ListTool()
        return AgentTool(
            name: "list_apps",
            description: "List running applications",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                let args = ToolArguments(from: ["item_type": "running_applications"])
                return try await tool.execute(arguments: args).toAgentToolResult()
            }
        )
    }
    
    func createLaunchAppTool() -> AgentTool {
        let tool = AppTool()
        return AgentTool(
            name: "launch_app",
            description: "Launch an application",
            parameters: AgentToolParameters(
                properties: [
                    "name": .string(description: "Application name to launch")
                ],
                required: ["name"]
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "launch"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    // MARK: - Element Tools
    
    func createFindElementTool() -> AgentTool {
        return AgentTool(
            name: "find_element",
            description: "Find a UI element by text or role",
            parameters: AgentToolParameters(
                properties: [
                    "text": .string(description: "Text to search for"),
                    "role": .string(description: "Element role/type")
                ],
                required: []
            ),
            handler: { arguments in
                // This would need to be implemented using ElementDetectionService
                .string("Element finding not yet implemented")
            }
        )
    }
    
    func createListElementsTool() -> AgentTool {
        return AgentTool(
            name: "list_elements",
            description: "List all UI elements in the current context",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            handler: { arguments in
                // This would need to be implemented using ElementDetectionService
                .string("Element listing not yet implemented")
            }
        )
    }
    
    func createFocusedTool() -> AgentTool {
        return AgentTool(
            name: "get_focused",
            description: "Get the currently focused UI element",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            handler: { arguments in
                // This would need to be implemented using FocusService
                .string("Focus detection not yet implemented")
            }
        )
    }
    
    // MARK: - Menu Tools
    
    func createMenuClickTool() -> AgentTool {
        let tool = MenuTool()
        return AgentTool(
            name: "menu_click",
            description: "Click on a menu item",
            parameters: convertMCPSchemaToAgentSchema(tool.inputSchema),
            handler: { arguments in
                var args = arguments
                args["action"] = "click"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    func createListMenusTool() -> AgentTool {
        let tool = MenuTool()
        return AgentTool(
            name: "list_menus",
            description: "List available menu items",
            parameters: AgentToolParameters(
                properties: [
                    "app": .string(description: "Application name")
                ],
                required: []
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "list"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    // MARK: - Dialog Tools
    
    func createDialogClickTool() -> AgentTool {
        let tool = DialogTool()
        return AgentTool(
            name: "dialog_click",
            description: "Click a button in a dialog",
            parameters: AgentToolParameters(
                properties: [
                    "button": .string(description: "Button text to click")
                ],
                required: ["button"]
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "click"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    func createDialogInputTool() -> AgentTool {
        let tool = DialogTool()
        return AgentTool(
            name: "dialog_input",
            description: "Enter text in a dialog field",
            parameters: AgentToolParameters(
                properties: [
                    "text": .string(description: "Text to enter"),
                    "field": .string(description: "Field identifier")
                ],
                required: ["text"]
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "input"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    // MARK: - Dock Tools
    
    func createDockLaunchTool() -> AgentTool {
        let tool = DockTool()
        return AgentTool(
            name: "dock_launch",
            description: "Launch an app from the dock",
            parameters: AgentToolParameters(
                properties: [
                    "app": .string(description: "Application name")
                ],
                required: ["app"]
            ),
            handler: { arguments in
                var args = arguments
                args["action"] = "launch"
                return try await tool.execute(arguments: ToolArguments(from: args))
                    .toAgentToolResult()
            }
        )
    }
    
    func createListDockTool() -> AgentTool {
        let tool = DockTool()
        return AgentTool(
            name: "list_dock",
            description: "List apps in the dock",
            parameters: AgentToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                let args = ToolArguments(from: ["action": "list"])
                return try await tool.execute(arguments: args).toAgentToolResult()
            }
        )
    }
    
    // MARK: - Shell Tool
    
    func createShellTool() -> AgentTool {
        return AgentTool(
            name: "shell",
            description: "Execute shell commands",
            parameters: AgentToolParameters(
                properties: [
                    "command": .string(description: "Shell command to execute")
                ],
                required: ["command"]
            ),
            handler: { arguments in
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
    
    func createDoneTool() -> AgentTool {
        return AgentTool(
            name: "done",
            description: "Indicate that the task is complete",
            parameters: AgentToolParameters(
                properties: [
                    "message": .string(description: "Completion message")
                ],
                required: []
            ),
            handler: { arguments in
                let message = arguments["message"] as? String ?? "Task completed successfully"
                return .string("✅ \(message)")
            }
        )
    }
    
    func createNeedInfoTool() -> AgentTool {
        return AgentTool(
            name: "need_info",
            description: "Request additional information from the user",
            parameters: AgentToolParameters(
                properties: [
                    "question": .string(description: "Question to ask the user")
                ],
                required: ["question"]
            ),
            handler: { arguments in
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
        
        var agentProperties: [String: AgentToolParameter] = [:]
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
                    switch typeStr {
                    case "string":
                        agentProperties[key] = .string(description: description)
                    case "number":
                        agentProperties[key] = .number(description: description)
                    case "integer":
                        agentProperties[key] = .integer(description: description)
                    case "boolean":
                        agentProperties[key] = .boolean(description: description)
                    case "array":
                        agentProperties[key] = .array(description: description)
                    case "object":
                        agentProperties[key] = .object(description: description)
                    default:
                        agentProperties[key] = .string(description: description)
                    }
                }
            }
        }
        
        return AgentToolParameters(properties: agentProperties, required: required)
    }
}

// MARK: - ToolArguments Extension

extension ToolArguments {
    init(from dict: [String: Any]) {
        self.init(Value.from(dict))
    }
}

// MARK: - Value Extension

extension Value {
    static func from(_ any: Any) -> Value {
        switch any {
        case let str as String:
            return .string(str)
        case let num as Int:
            return .double(Double(num))
        case let num as Double:
            return .double(num)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { Value.from($0) })
        case let dict as [String: Any]:
            var result: [String: Value] = [:]
            for (key, value) in dict {
                result[key] = Value.from(value)
            }
            return .object(result)
        default:
            return .null
        }
    }
}

// MARK: - ToolResponse Extension

extension ToolResponse {
    func toAgentToolResult() -> AgentToolResult {
        // Convert the first content item to a string result
        if let firstContent = content.first {
            switch firstContent {
            case .text(let text):
                return .string(text)
            case .image(let data, _, _):
                return .string("[Image data: \(data.prefix(100))...]")
            case .resource:
                return .string("[Resource content]")
            }
        }
        return .string("No content returned")
    }
}