import Foundation
import CoreGraphics

// MARK: - Peekaboo Agent Service

/// Service that integrates the new agent architecture with PeekabooCore services
@available(macOS 14.0, *)
public final class PeekabooAgentService: AgentServiceProtocol {
    private let services: PeekabooServices
    private let modelProvider: ModelProvider
    private let sessionManager: AgentSessionManager
    private let defaultModelName: String
    
    
    public init(
        services: PeekabooServices = .shared,
        defaultModelName: String = "gpt-4-turbo-preview"
    ) {
        self.services = services
        self.modelProvider = .shared
        self.sessionManager = AgentSessionManager()
        self.defaultModelName = defaultModelName
    }
    
    // MARK: - AgentServiceProtocol Conformance
    
    /// Execute a task using the AI agent (backward compatibility)
    public func executeTask(
        _ task: String,
        dryRun: Bool = false,
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentResult {
        // For dry run, just return a simulated result
        if dryRun {
            return AgentResult(
                steps: [
                    AgentStep(
                        action: "analyze",
                        description: "Would analyze the task: \(task)",
                        toolCalls: [],
                        reasoning: "Dry run mode - no actions performed",
                        observation: nil
                    )
                ],
                summary: "Dry run completed. Task would be: \(task)"
            )
        }
        
        // Use the new architecture internally
        let agent = createAutomationAgent(modelName: defaultModelName)
        
        // Create a new session for this task
        let sessionId = UUID().uuidString
        
        // Execute with streaming if we have an event delegate
        if let eventDelegate = eventDelegate {
            // Send initial event
            await eventDelegate.agentDidStart()
            
            var steps: [AgentStep] = []
            
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            ) { chunk in
                // Convert streaming chunks to events
                await eventDelegate.agentDidReceiveChunk(chunk)
            }
            
            // Convert tool calls to steps for backward compatibility
            if let messages = try? await sessionManager.loadSession(id: sessionId)?.messages {
                for message in messages {
                    if let assistantMessage = message.message as? AssistantMessageItem {
                        for content in assistantMessage.content {
                            if case .toolCall(let toolCall) = content {
                                let step = AgentStep(
                                    action: toolCall.function.name,
                                    description: "Executed \(toolCall.function.name)",
                                    toolCalls: [toolCall.id],
                                    reasoning: nil,
                                    observation: nil
                                )
                                steps.append(step)
                            }
                        }
                    }
                }
            }
            
            // Send completion event
            // Convert AgentExecutionResult to AgentResult for the delegate
            let agentResult = AgentResult(
                steps: steps,
                messages: result.session.messages.compactMap { msg in
                    if let assistantMsg = msg.message as? AssistantMessageItem {
                        return assistantMsg.content.compactMap { content -> String? in
                            if case .text(let text) = content {
                                return text.text
                            }
                            return nil
                        }.joined(separator: " ")
                    }
                    return nil
                }.joined(separator: "\n"),
                sessionId: result.session.id
            )
            await eventDelegate.agentDidComplete(agentResult)
            
            return AgentResult(
                steps: steps.isEmpty ? [
                    AgentStep(
                        action: "complete",
                        description: task,
                        toolCalls: [],
                        reasoning: nil,
                        observation: result.messages.last.map { "\($0)" }
                    )
                ] : steps,
                summary: result.messages.last.map { "\($0)" } ?? "Task completed"
            )
        } else {
            // Execute without streaming
            let result = try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            )
            
            // Convert to legacy AgentResult format
            var steps: [AgentStep] = []
            
            // Extract steps from the session messages
            if let messages = try? await sessionManager.loadSession(id: sessionId)?.messages {
                for message in messages {
                    if let assistantMessage = message.message as? AssistantMessageItem {
                        for content in assistantMessage.content {
                            if case .toolCall(let toolCall) = content {
                                let step = AgentStep(
                                    action: toolCall.function.name,
                                    description: "Executed \(toolCall.function.name)",
                                    toolCalls: [toolCall.id],
                                    reasoning: nil,
                                    observation: nil
                                )
                                steps.append(step)
                            }
                        }
                    }
                }
            }
            
            return AgentResult(
                steps: steps.isEmpty ? [
                    AgentStep(
                        action: "complete",
                        description: task,
                        toolCalls: [],
                        reasoning: nil,
                        observation: result.messages.last.map { "\($0)" }
                    )
                ] : steps,
                summary: result.messages.last.map { "\($0)" } ?? "Task completed"
            )
        }
    }
    
    /// Clean up any cached sessions or resources
    public func cleanup() async {
        // Clean up old sessions (older than 7 days)
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        try? await sessionManager.cleanupSessions(olderThan: oneWeekAgo)
    }
    
    // MARK: - Agent Creation
    
    /// Create a Peekaboo automation agent with all available tools
    public func createAutomationAgent(
        name: String = "Peekaboo Assistant",
        modelName: String = "gpt-4-turbo-preview"
    ) -> PeekabooAgent<PeekabooServices> {
        let agent = PeekabooAgent<PeekabooServices>(
            name: name,
            instructions: generateSystemPrompt(),
            tools: createPeekabooTools(),
            modelSettings: ModelSettings(modelName: modelName),
            description: "An AI assistant for macOS automation using Peekaboo"
        )
        
        return agent
    }
    
    // MARK: - Execution Methods
    
    /// Execute a task with the automation agent (new method with session support)
    public func executeTask(
        _ task: String,
        sessionId: String? = nil,
        modelName: String = "gpt-4-turbo-preview",
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentResult {
        let agent = createAutomationAgent(modelName: modelName)
        
        // If we have an event delegate, use streaming
        if let eventDelegate = eventDelegate {
            // Emit start event
            await eventDelegate.agentDidEmitEvent(.started(task: task))
            
            // Create a custom stream handler that converts to events
            let streamHandler: (String) async -> Void = { chunk in
                await eventDelegate.agentDidEmitEvent(.assistantMessage(content: chunk))
            }
            
            do {
                let result = try await AgentRunner.runStreaming(
                    agent: agent,
                    input: task,
                    context: services,
                    sessionId: sessionId,
                    streamHandler: streamHandler
                )
                
                // Emit tool call events from the result
                for toolCall in result.toolCalls {
                    await eventDelegate.agentDidEmitEvent(
                        .toolCallStarted(name: toolCall.function.name, arguments: toolCall.function.arguments)
                    )
                    // In a real implementation, we'd emit completion events too
                }
                
                // Convert to legacy format
                return convertToLegacyResult(result)
            } catch {
                await eventDelegate.agentDidEmitEvent(.error(message: error.localizedDescription))
                throw error
            }
        } else {
            // Non-streaming execution
            let result = try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            )
            
            return convertToLegacyResult(result)
        }
    }
    
    /// Convert new AgentExecutionResult to legacy format
    private func convertToLegacyResult(_ result: AgentExecutionResult) -> AgentResult {
        // Extract steps from the conversation
        var steps: [AgentStep] = []
        
        for (index, toolCall) in result.toolCalls.enumerated() {
            steps.append(AgentStep(
                action: toolCall.function.name,
                description: "Tool call #\(index + 1)",
                toolCalls: [toolCall.id],
                reasoning: nil,
                observation: nil
            ))
        }
        
        // If no tool calls, add a single completion step
        if steps.isEmpty {
            steps.append(AgentStep(
                action: "complete",
                description: "Task completed",
                toolCalls: [],
                reasoning: nil,
                observation: result.content
            ))
        }
        
        return AgentResult(
            steps: steps,
            summary: result.content
        )
    }
    
    /// Execute a task with streaming output
    public func executeTaskStreaming(
        _ task: String,
        sessionId: String? = nil,
        modelName: String = "gpt-4-turbo-preview",
        streamHandler: @escaping (String) async -> Void
    ) async throws -> AgentResult {
        let agent = createAutomationAgent(modelName: modelName)
        
        let executionResult = try await AgentRunner.runStreaming(
            agent: agent,
            input: task,
            context: services,
            sessionId: sessionId,
            streamHandler: streamHandler
        )
        
        // Convert AgentExecutionResult to AgentResult
        var steps: [AgentStep] = []
        
        // Extract steps from messages
        for message in executionResult.messages {
            if let assistantMessage = message as? AssistantMessageItem {
                for content in assistantMessage.content {
                    if case .toolCall(let toolCall) = content {
                        let step = AgentStep(
                            action: toolCall.function.name,
                            description: "Executed \(toolCall.function.name)",
                            toolCalls: [toolCall.id],
                            reasoning: nil,
                            observation: nil
                        )
                        steps.append(step)
                    }
                }
            }
        }
        
        let messages = executionResult.messages.compactMap { msg in
            if let assistantMsg = msg as? AssistantMessageItem {
                return assistantMsg.content.compactMap { content -> String? in
                    if case .text(let text) = content {
                        return text.text
                    }
                    return nil
                }.joined(separator: " ")
            }
            return nil
        }.joined(separator: "\n")
        
        return AgentResult(
            steps: steps,
            messages: messages,
            sessionId: executionResult.sessionId
        )
    }
    
    // MARK: - Tool Creation
    
    private func createPeekabooTools() -> [Tool<PeekabooServices>] {
        var tools: [Tool<PeekabooServices>] = []
        
        // Screen capture tools
        tools.append(createScreenshotTool())
        tools.append(createWindowCaptureTool())
        
        // UI automation tools
        tools.append(createClickTool())
        tools.append(createTypeTool())
        tools.append(createScrollTool())
        tools.append(createHotkeyTool())
        
        // Window management tools
        tools.append(createListWindowsTool())
        tools.append(createFocusWindowTool())
        tools.append(createResizeWindowTool())
        
        // Application tools
        tools.append(createListAppsTool())
        tools.append(createLaunchAppTool())
        
        // Element detection tools
        tools.append(createFindElementTool())
        tools.append(createListElementsTool())
        
        // Focus detection tool
        tools.append(createFocusedTool())
        
        return tools
    }
    
    // MARK: - Individual Tool Definitions
    
    private func createScreenshotTool() -> Tool<PeekabooServices> {
        Tool(
            name: "screenshot",
            description: "Capture a screenshot of the current screen or active window",
            parameters: .object(
                properties: [
                    "mode": .enumeration(
                        ["screen", "window", "area"],
                        description: "What to capture"
                    ),
                    "path": .string(
                        description: "Optional path to save the screenshot"
                    ),
                    "displayIndex": .integer(
                        description: "Display index for screen mode (0 for main)"
                    )
                ],
                required: ["mode"]
            ),
            execute: { input, services in
                let mode: String = input.value(for: "mode") ?? "screen"
                let path: String? = input.value(for: "path")
                let displayIndex: Int? = input.value(for: "displayIndex")
                
                let result: CaptureResult
                
                switch mode {
                case "screen":
                    result = try await services.screenCapture.captureScreen(displayIndex: displayIndex)
                case "window":
                    result = try await services.screenCapture.captureFrontmost()
                case "area":
                    // For now, capture the whole screen
                    result = try await services.screenCapture.captureScreen(displayIndex: displayIndex)
                default:
                    throw PeekabooError.invalidInput("Invalid capture mode: \(mode)")
                }
                
                // Save if path provided
                if let path = path {
                    try await services.files.saveImage(result.image, to: path)
                }
                
                return .dictionary([
                    "success": true,
                    "path": result.metadata.savePath ?? path ?? "captured in memory",
                    "width": result.metadata.width,
                    "height": result.metadata.height
                ])
            }
        )
    }
    
    private func createClickTool() -> Tool<PeekabooServices> {
        Tool(
            name: "click",
            description: "Click on a UI element by text, coordinates, or element type",
            parameters: .object(
                properties: [
                    "target": .string(description: "Text to find and click, or 'coordinates' to use x,y"),
                    "x": .number(description: "X coordinate (when target is 'coordinates')"),
                    "y": .number(description: "Y coordinate (when target is 'coordinates')"),
                    "clickType": .enumeration(
                        ["single", "double", "right"],
                        description: "Type of click"
                    ),
                    "sessionId": .string(description: "Optional session ID for element caching")
                ],
                required: ["target"]
            ),
            execute: { input, services in
                let target: String = input.value(for: "target") ?? ""
                let clickType: String = input.value(for: "clickType") ?? "single"
                let sessionId: String? = input.value(for: "sessionId")
                
                if target == "coordinates" {
                    guard let x: Double = input.value(for: "x"),
                          let y: Double = input.value(for: "y") else {
                        throw PeekabooError.invalidInput("Coordinates required when target is 'coordinates'")
                    }
                    
                    let clickTypeEnum: ClickType = clickType == "double" ? .double :
                                                   clickType == "right" ? .right : .single
                    
                    try await services.automation.click(
                        at: CGPoint(x: x, y: y),
                        clickType: clickTypeEnum
                    )
                } else {
                    // Click by text
                    try await services.automation.click(
                        target: .text(target),
                        sessionId: sessionId
                    )
                }
                
                // Get focus information after clicking
                let focusAfterClick = await services.automation.getFocusedElement()
                
                var response: [String: Any] = [
                    "success": true,
                    "action": "clicked",
                    "target": target
                ]
                
                if let focusInfo = focusAfterClick {
                    response["focusAfterClick"] = focusInfo.toDictionary()
                } else {
                    response["focusAfterClick"] = [
                        "found": false,
                        "message": "No focused element after clicking"
                    ]
                }
                
                return .dictionary(response)
            }
        )
    }
    
    private func createTypeTool() -> Tool<PeekabooServices> {
        Tool(
            name: "type",
            description: "Type text into the currently focused element",
            parameters: .object(
                properties: [
                    "text": .string(description: "Text to type"),
                    "delay": .number(
                        description: "Delay between keystrokes in milliseconds",
                        minimum: 0,
                        maximum: 1000
                    )
                ],
                required: ["text"]
            ),
            execute: { input, services in
                let text: String = input.value(for: "text") ?? ""
                let delay: Double? = input.value(for: "delay")
                
                try await services.automation.type(
                    text: text,
                    delay: delay.map { $0 / 1000 } // Convert ms to seconds
                )
                
                // Get focus information after typing
                let focusAfterTyping = await services.automation.getFocusedElement()
                
                var response: [String: Any] = [
                    "success": true,
                    "action": "typed",
                    "text": text
                ]
                
                if let focusInfo = focusAfterTyping {
                    response["focusAfterTyping"] = focusInfo.toDictionary()
                } else {
                    response["focusAfterTyping"] = [
                        "found": false,
                        "message": "No focused element after typing"
                    ]
                }
                
                return .dictionary(response)
            }
        )
    }
    
    private func createListWindowsTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_windows",
            description: "List all windows for an application",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application (optional, lists all if not provided)")
                ],
                required: []
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName")
                
                let windows: [WindowInfo]
                if let appName = appName {
                    windows = try await services.applications.listWindows(for: appName)
                } else {
                    // List all windows
                    let apps = try await services.applications.listRunningApplications()
                    var allWindows: [WindowInfo] = []
                    for app in apps {
                        if let appWindows = try? await services.applications.listWindows(for: app.name) {
                            allWindows.append(contentsOf: appWindows)
                        }
                    }
                    windows = allWindows
                }
                
                let windowData = windows.map { window in
                    [
                        "title": window.title,
                        "appName": window.appName,
                        "bounds": [
                            "x": window.bounds.origin.x,
                            "y": window.bounds.origin.y,
                            "width": window.bounds.width,
                            "height": window.bounds.height
                        ],
                        "isMinimized": window.isMinimized,
                        "isFullscreen": window.isFullscreen
                    ]
                }
                
                return .dictionary([
                    "success": true,
                    "windows": windowData,
                    "count": windows.count
                ])
            }
        )
    }
    
    private func createFindElementTool() -> Tool<PeekabooServices> {
        Tool(
            name: "find_element",
            description: "Find UI elements by text or type",
            parameters: .object(
                properties: [
                    "text": .string(description: "Text to search for"),
                    "elementType": .enumeration(
                        ["button", "textField", "staticText", "any"],
                        description: "Type of element to find"
                    ),
                    "sessionId": .string(description: "Session ID for caching")
                ],
                required: []
            ),
            execute: { input, services in
                let text: String? = input.value(for: "text")
                let elementType: String = input.value(for: "elementType") ?? "any"
                let sessionId: String? = input.value(for: "sessionId") ?? UUID().uuidString
                
                let target: ElementTarget
                if let text = text {
                    target = .text(text)
                } else {
                    target = .type(elementType)
                }
                
                let elements = try await services.sessions.findElements(
                    matching: target,
                    sessionId: sessionId
                )
                
                let elementData = elements.map { element in
                    [
                        "text": element.label ?? element.title ?? "",
                        "type": element.role,
                        "bounds": [
                            "x": element.frame.origin.x,
                            "y": element.frame.origin.y,
                            "width": element.frame.width,
                            "height": element.frame.height
                        ],
                        "isEnabled": element.isEnabled
                    ]
                }
                
                return .dictionary([
                    "success": true,
                    "elements": elementData,
                    "count": elements.count,
                    "sessionId": sessionId
                ])
            }
        )
    }
    
    // MARK: - System Prompt
    
    private func generateSystemPrompt() -> String {
        """
        You are Peekaboo Assistant, an AI agent specialized in macOS automation and UI interaction.
        
        You have access to powerful tools for:
        - Taking screenshots and capturing windows
        - Clicking on UI elements and typing text
        - Managing windows and applications
        - Finding and interacting with specific UI elements
        - Checking what UI element is currently focused
        
        When helping users:
        1. Be precise and efficient in your automation tasks
        2. Always verify actions were successful before proceeding
        3. Use element detection sessions to cache UI lookups when performing multiple operations
        4. Provide clear feedback about what you're doing
        5. Handle errors gracefully and suggest alternatives
        
        Focus Awareness:
        The type, click, and hotkey tools automatically return information about the focused UI element after the action.
        Use this information to verify your actions were successful:
        
        - focusAfterTyping: Shows which element received the typed text
        - focusAfterClick: Shows which element is focused after clicking  
        - focusAfterHotkey: Shows which element is focused after the keyboard shortcut
        
        Use the 'focused' tool to check what element is currently focused before taking actions.
        
        Focus information includes:
        - app: Which application contains the focused element
        - element.role: Type of element (AXTextField, AXButton, etc.)
        - element.title: Label or title of the element
        - element.value: Current content of the element
        - element.isTextInput: Whether the element accepts text input
        - element.canAcceptKeyboardInput: Whether the element can receive keyboard input
        
        Important guidelines:
        - When searching for UI elements, prefer text-based searches as they're more reliable
        - Use session IDs to improve performance when doing multiple operations
        - For window management, always check if the target window exists first
        - When typing sensitive information, warn the user first
        - Pay attention to focus information to detect when actions target the wrong element
        - If you type text and the focusAfterTyping shows an unexpected element (like Safari's address bar instead of an email field), acknowledge the error and take corrective action
        
        You are running on macOS with full automation permissions granted to Peekaboo.
        """
    }
}

// MARK: - Convenience Methods

extension PeekabooAgentService {
    /// List available agent sessions
    public func listSessions() async throws -> [SessionSummary] {
        return try await sessionManager.listSessions()
    }
    
    /// Delete an agent session
    public func deleteSession(id: String) async throws {
        try await sessionManager.deleteSession(id: id)
    }
    
    /// Clean up old sessions
    public func cleanupSessions(olderThan date: Date) async throws {
        try await sessionManager.cleanupSessions(olderThan: date)
    }
}

// MARK: - Additional Tool Implementations

extension PeekabooAgentService {
    private func createWindowCaptureTool() -> Tool<PeekabooServices> {
        Tool(
            name: "window_capture",
            description: "Capture a screenshot of a specific application window",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application"),
                    "windowIndex": .integer(description: "Window index (0 for first window)")
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName") ?? ""
                let windowIndex = input.value(for: "windowIndex") as? Int
                
                let result = try await services.screenCapture.captureWindow(
                    appIdentifier: appName,
                    windowIndex: windowIndex
                )
                
                return .dictionary([
                    "success": true,
                    "path": result.metadata.savePath ?? "captured in memory",
                    "width": result.metadata.width,
                    "height": result.metadata.height,
                    "appName": result.metadata.appName ?? appName
                ])
            }
        )
    }
    
    private func createScrollTool() -> Tool<PeekabooServices> {
        Tool(
            name: "scroll",
            description: "Scroll in a window or element",
            parameters: .object(
                properties: [
                    "direction": .enumeration(
                        ["up", "down", "left", "right"],
                        description: "Direction to scroll"
                    ),
                    "amount": .integer(
                        description: "Amount to scroll (in pixels)",
                        minimum: 1,
                        maximum: 10000
                    ),
                    "target": .string(description: "Optional target element text"),
                    "sessionId": .string(description: "Optional session ID for element caching")
                ],
                required: ["direction", "amount"]
            ),
            execute: { input, services in
                let direction = input.value(for: "direction") as? String ?? "down"
                let amount = input.value(for: "amount") as? Int ?? 100
                let target = input.value(for: "target") as? String
                let sessionId: String? = input.value(for: "sessionId")
                
                let scrollDirection: ScrollDirection = {
                    switch direction {
                    case "up": return .up
                    case "down": return .down
                    case "left": return .left
                    case "right": return .right
                    default: return .down
                    }
                }()
                
                try await services.automation.scroll(
                    direction: scrollDirection,
                    amount: amount,
                    target: target,
                    sessionId: sessionId
                )
                
                return .dictionary([
                    "success": true,
                    "action": "scrolled",
                    "direction": direction,
                    "amount": amount
                ])
            }
        )
    }
    
    private func createHotkeyTool() -> Tool<PeekabooServices> {
        Tool(
            name: "hotkey",
            description: "Send keyboard shortcuts (hotkeys) to the system",
            parameters: .object(
                properties: [
                    "keys": .string(
                        description: "Comma-separated key combination (e.g., 'cmd,c' for Cmd+C, 'cmd,shift,4' for Cmd+Shift+4)"
                    ),
                    "holdDuration": .integer(
                        description: "Duration to hold the keys in milliseconds",
                        minimum: 0,
                        maximum: 5000
                    )
                ],
                required: ["keys"]
            ),
            execute: { input, services in
                let keys = input.value(for: "keys") as? String ?? ""
                let holdDuration = input.value(for: "holdDuration") as? Int ?? 100
                
                try await services.automation.hotkey(
                    keys: keys,
                    holdDuration: holdDuration
                )
                
                // Get focus information after hotkey
                let focusAfterHotkey = await services.automation.getFocusedElement()
                
                var response: [String: Any] = [
                    "success": true,
                    "action": "hotkey",
                    "keys": keys
                ]
                
                if let focusInfo = focusAfterHotkey {
                    response["focusAfterHotkey"] = focusInfo.toDictionary()
                } else {
                    response["focusAfterHotkey"] = [
                        "found": false,
                        "message": "No focused element after hotkey"
                    ]
                }
                
                return .dictionary(response)
            }
        )
    }
    
    private func createFocusWindowTool() -> Tool<PeekabooServices> {
        Tool(
            name: "focus_window",
            description: "Focus (bring to front) a specific window",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application"),
                    "windowTitle": .string(description: "Optional window title to match")
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName") ?? ""
                let windowTitle = input.value(for: "windowTitle") as? String
                
                try await services.windows.focusWindow(
                    appIdentifier: appName,
                    windowTitle: windowTitle
                )
                
                return .dictionary([
                    "success": true,
                    "action": "focused",
                    "appName": appName
                ])
            }
        )
    }
    
    private func createResizeWindowTool() -> Tool<PeekabooServices> {
        Tool(
            name: "resize_window",
            description: "Resize a window to specific dimensions",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application"),
                    "width": .number(description: "New width in pixels"),
                    "height": .number(description: "New height in pixels"),
                    "windowTitle": .string(description: "Optional window title to match")
                ],
                required: ["appName", "width", "height"]
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName") ?? ""
                let width = input.value(for: "width") as? Double ?? 800
                let height = input.value(for: "height") as? Double ?? 600
                let windowTitle = input.value(for: "windowTitle") as? String
                
                try await services.windows.resizeWindow(
                    appIdentifier: appName,
                    size: CGSize(width: width, height: height),
                    windowTitle: windowTitle
                )
                
                return .dictionary([
                    "success": true,
                    "action": "resized",
                    "appName": appName,
                    "newSize": ["width": width, "height": height]
                ])
            }
        )
    }
    
    private func createListAppsTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_apps",
            description: "List all running applications",
            parameters: .object(properties: [:], required: []),
            execute: { _, services in
                let apps = try await services.applications.listRunningApplications()
                
                let appData = apps.map { app in
                    [
                        "name": app.name,
                        "bundleId": app.bundleIdentifier ?? "",
                        "processId": app.processIdentifier,
                        "isActive": app.isActive
                    ]
                }
                
                return .dictionary([
                    "success": true,
                    "apps": appData,
                    "count": apps.count
                ])
            }
        )
    }
    
    private func createLaunchAppTool() -> Tool<PeekabooServices> {
        Tool(
            name: "launch_app",
            description: "Launch an application",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application to launch")
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName") ?? ""
                
                try await services.applications.launchApplication(appName)
                
                return .dictionary([
                    "success": true,
                    "action": "launched",
                    "appName": appName
                ])
            }
        )
    }
    
    private func createListElementsTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_elements",
            description: "List all UI elements in the current context",
            parameters: .object(
                properties: [
                    "sessionId": .string(description: "Session ID for element detection"),
                    "elementType": .enumeration(
                        ["all", "buttons", "textFields", "labels", "links"],
                        description: "Type of elements to list"
                    )
                ],
                required: ["sessionId"]
            ),
            execute: { input, services in
                let sessionId: String? = input.value(for: "sessionId") ?? UUID().uuidString
                let elementType = input.value(for: "elementType") as? String ?? "all"
                
                // Get the latest detection result from the session
                guard let detectionResult = try await services.sessions.getLatestDetectionResult(sessionId: sessionId) else {
                    // Need to capture and detect first
                    let captureResult = try await services.screenCapture.captureFrontmost()
                    let detection = try await services.automation.detectElements(
                        in: captureResult.imageData,
                        sessionId: sessionId
                    )
                    try await services.sessions.storeDetectionResult(sessionId: sessionId, result: detection)
                    
                    return formatElementList(detection.elements, filterType: elementType)
                }
                
                return formatElementList(detectionResult.elements, filterType: elementType)
            }
        )
    }
    
    private func createFocusedTool() -> Tool<PeekabooServices> {
        Tool(
            name: "focused",
            description: "Get information about the currently focused UI element that would receive keyboard input",
            parameters: .object(properties: [:], required: []),
            execute: { _, services in
                guard let focusInfo = await services.automation.getFocusedElement() else {
                    return .dictionary([
                        "success": true,
                        "focused": false,
                        "message": "No UI element is currently focused"
                    ])
                }
                
                return .dictionary([
                    "success": true,
                    "focused": true,
                    "focusInfo": focusInfo.toDictionary()
                ])
            }
        )
    }
}

// MARK: - Helper Functions

private func formatElementList(_ elements: DetectedElements, filterType: String) -> ToolOutput {
    let filteredElements: [DetectedElement]
    
    switch filterType {
    case "buttons":
        filteredElements = elements.buttons
    case "textFields":
        filteredElements = elements.textFields
    case "labels":
        filteredElements = elements.staticTexts
    case "links":
        filteredElements = elements.links
    default:
        filteredElements = elements.all
    }
    
    let elementData = filteredElements.map { element in
        [
            "text": element.label ?? element.title ?? "",
            "type": element.role,
            "bounds": [
                "x": element.frame.origin.x,
                "y": element.frame.origin.y,
                "width": element.frame.width,
                "height": element.frame.height
            ],
            "confidence": element.confidence ?? 1.0
        ]
    }
    
    return .dictionary([
        "success": true,
        "elements": elementData,
        "count": filteredElements.count,
        "type": filterType
    ])
}