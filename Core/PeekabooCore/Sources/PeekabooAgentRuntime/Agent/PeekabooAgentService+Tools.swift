//
//  PeekabooAgentService+Tools.swift
//  PeekabooCore
//

import Foundation
import MCP
import PeekabooAutomation
import Tachikoma
import TachikomaMCP

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

    public func createWatchTool() -> AgentTool {
        // Back-compat alias to capture tool
        let tool = CaptureTool(context: self.makeToolContext())
        return AgentTool(
            name: "watch", // preserve legacy tool name for agents
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    public func createCaptureTool() -> AgentTool {
        let tool = CaptureTool(context: self.makeToolContext())
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

    // MARK: - Clipboard

    public func createClipboardTool() -> AgentTool {
        let tool = ClipboardTool(context: self.makeToolContext())
        return AgentTool(
            name: tool.name,
            description: tool.description,
            parameters: self.convertMCPSchemaToAgentSchema(tool.inputSchema),
            execute: { arguments in
                let response = try await tool.execute(arguments: makeToolArguments(from: arguments))
                return await convertToolResponseToAgentToolResultAsync(response)
            })
    }

    // MARK: - Paste

    public func createPasteTool() -> AgentTool {
        let tool = PasteTool(context: self.makeToolContext())
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
}
