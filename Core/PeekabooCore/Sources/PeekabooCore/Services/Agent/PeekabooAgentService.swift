import CoreGraphics
import Foundation
import TachikomaCore

// Convenience extensions for cleaner return statements
extension ToolOutput {
    /// Create a successful string output
    static func success(_ message: String) -> ToolOutput {
        .string(message)
    }

    /// Create an error output from a PeekabooError
    static func failure(_ error: PeekabooError) -> ToolOutput {
        .string("Error: \(error.localizedDescription)")
    }

    /// Create an error output from any Error
    static func failure(_ error: Error) -> ToolOutput {
        .string("Error: \(error.localizedDescription)")
    }
}

// MARK: - Helper Types

/// Simple event delegate wrapper for streaming
@available(macOS 14.0, *)
@MainActor
final class StreamingEventDelegate: @unchecked Sendable, AgentEventDelegate {
    let onChunk: @MainActor @Sendable (String) async -> Void

    init(onChunk: @MainActor @escaping @Sendable (String) async -> Void) {
        self.onChunk = onChunk
    }

    func agentDidEmitEvent(_ event: AgentEvent) {
        // Extract content from different event types and schedule async work
        Task { @MainActor in
            switch event {
            case let .thinkingMessage(content):
                await self.onChunk(content)
            case let .assistantMessage(content):
                await self.onChunk(content)
            case let .completed(summary, _):
                await self.onChunk(summary)
            default:
                break
            }
        }
    }
}

// MARK: - Peekaboo Agent Service

/// Service that integrates the new agent architecture with PeekabooCore services
@available(macOS 14.0, *)
@MainActor
public final class PeekabooAgentService: AgentServiceProtocol {
    private let services: PeekabooServices
    private let sessionManager: AgentSessionManager
    private let defaultLanguageModel: LanguageModel
    private var currentModel: LanguageModel?

    /// The default model used by this agent service
    public var defaultModel: String { self.defaultLanguageModel.description }

    /// Get the masked API key for the current model
    public var maskedApiKey: String? {
        get async {
            // For the new API, we would need to implement API key masking in LanguageModel
            // For now, return a placeholder
            "***"
        }
    }

    public init(
        services: PeekabooServices,
        defaultModel: LanguageModel = .anthropic(.opus4))
        throws
    {
        self.services = services
        self.sessionManager = try AgentSessionManager()
        self.defaultLanguageModel = defaultModel
    }

    // MARK: - AgentServiceProtocol Conformance

    /// Execute a task using the AI agent
    public func executeTask(
        _ task: String,
        maxSteps: Int = 20,
        dryRun: Bool = false,
        eventDelegate: AgentEventDelegate? = nil) async throws -> AgentExecutionResult
    {
        // For dry run, just return a simulated result
        if dryRun {
            return AgentExecutionResult(
                content: "Dry run completed. Task would be: \(task)",
                messages: [],
                sessionId: UUID().uuidString,
                usage: nil,
                metadata: AgentMetadata(
                    executionTime: 0,
                    toolCallCount: 0,
                    modelName: self.defaultLanguageModel.description,
                    startTime: Date(),
                    endTime: Date()))
        }

        // Note: In the new API, we don't need to create agents - we use direct functions

        // Execute with streaming if we have an event delegate
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer<AgentEventDelegate>(eventDelegate!)

            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()

            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }

            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }

            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }

            // Run the agent with streaming
            let selectedModel = self.defaultLanguageModel

            // Create event delegate wrapper for streaming
            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            let result = try await self.executeWithStreaming(
                task,
                model: selectedModel,
                maxSteps: maxSteps,
                streamingDelegate: streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Execute without streaming
            let selectedModel = self.defaultLanguageModel
            return try await self.executeWithoutStreaming(task, model: selectedModel, maxSteps: maxSteps)
        }
    }

    /// Execute a task with audio content
    public func executeTaskWithAudio(
        audioContent: AudioContent,
        maxSteps: Int = 20,
        dryRun: Bool = false,
        eventDelegate: AgentEventDelegate? = nil) async throws -> AgentExecutionResult
    {
        // For dry run, just return a simulated result
        if dryRun {
            let description = audioContent.transcript ?? "[Audio message - duration: \(Int(audioContent.duration ?? 0))s]"
            return AgentExecutionResult(
                content: "Dry run completed. Audio task: \(description)",
                messages: [],
                sessionId: UUID().uuidString,
                usage: nil,
                metadata: AgentMetadata(
                    executionTime: 0,
                    toolCallCount: 0,
                    modelName: self.defaultLanguageModel.description,
                    startTime: Date(),
                    endTime: Date()))
        }

        // Note: In the new API, we don't need to create agents - we use direct functions

        // Execute with streaming if we have an event delegate
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer<AgentEventDelegate>(eventDelegate!)

            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()

            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }

            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }

            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }

            // For now, convert audio to text if transcript is available
            // In the future, we'll pass audio directly to providers that support it
            let input = audioContent.transcript ?? "[Audio message without transcript]"

            // Run the agent with streaming
            let selectedModel = self.defaultLanguageModel

            // Create event delegate wrapper for streaming
            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            let result = try await self.executeWithStreaming(
                input,
                model: selectedModel,
                maxSteps: maxSteps,
                streamingDelegate: streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // For now, convert audio to text if transcript is available
            // In the future, we'll pass audio directly to providers that support it
            let input = audioContent.transcript ?? "[Audio message without transcript]"

            // Execute without streaming
            let selectedModel = self.defaultLanguageModel
            return try await self.executeWithoutStreaming(input, model: selectedModel, maxSteps: maxSteps)
        }
    }

    /// Clean up any cached sessions or resources
    public func cleanup() async {
        // Clean up old sessions (older than 7 days)
        // Clean old sessions manually
        let oldSessionDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let sessions = self.sessionManager.listSessions()
        for session in sessions where session.lastAccessedAt < oldSessionDate {
            try? await self.sessionManager.deleteSession(id: session.id)
        }
    }

    // MARK: - Agent Creation

    /// Create a Peekaboo automation agent with all available tools
    public func createAutomationAgent(
        name: String = "Peekaboo Assistant",
        model: LanguageModel? = nil) async throws -> PeekabooAgent<PeekabooServices>
    {
        let selectedModel = model ?? self.defaultLanguageModel

        let agent = PeekabooAgent<PeekabooServices>(
            model: selectedModel,
            sessionId: UUID().uuidString,
            name: name,
            instructions: AgentSystemPrompt.generate(),
            tools: self.createPeekabooTools(),
            context: self.services)

        return agent
    }

    // MARK: - Execution Methods

    /// Execute a task with the automation agent (with session support)
    public func executeTask(
        _ task: String,
        maxSteps: Int = 20,
        sessionId: String? = nil,
        model: LanguageModel? = nil,
        eventDelegate: AgentEventDelegate? = nil) async throws -> AgentExecutionResult
    {
        // Note: In the new API, we don't need to create agents - we use direct functions

        // If we have an event delegate, use streaming
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer<AgentEventDelegate>(eventDelegate!)

            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()

            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue

                // Send start event
                delegate.agentDidEmitEvent(.started(task: task))

                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }

            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }

            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }

            // Run the agent with streaming
            let selectedModel = model ?? self.defaultLanguageModel

            // Create event delegate wrapper for streaming
            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            let result = try await self.executeWithStreaming(
                task,
                model: selectedModel,
                maxSteps: maxSteps,
                streamingDelegate: streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Non-streaming execution
            let selectedModel = model ?? self.defaultLanguageModel
            return try await self.executeWithoutStreaming(task, model: selectedModel, maxSteps: maxSteps)
        }
    }

    /// Execute a task with streaming output
    public func executeTaskStreaming(
        _ task: String,
        sessionId: String? = nil,
        model: LanguageModel? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void) async throws -> AgentExecutionResult
    {
        // Note: In the new API, we don't need to create agents - we use direct functions

        // AgentRunner.runStreaming doesn't have a streamHandler parameter
        // We need to use the agent directly with an event delegate
        let selectedModel = model ?? self.defaultLanguageModel
        // For streaming without event handler, create a dummy delegate that discards chunks
        let dummyDelegate = StreamingEventDelegate { _ in /* discard */ }
        return try await self.executeWithStreaming(
            task,
            model: selectedModel,
            maxSteps: 20,
            streamingDelegate: dummyDelegate)
    }

    // MARK: - Tool Creation

    private func createPeekabooTools() -> [Tool<PeekabooServices>] {
        var tools: [Tool<PeekabooServices>] = []

        // Vision tools
        tools.append(createSeeTool())
        tools.append(createScreenshotTool())
        tools.append(createWindowCaptureTool())

        // UI automation tools
        tools.append(createClickTool())
        tools.append(createTypeTool())
        tools.append(createPressTool())
        tools.append(createScrollTool())
        tools.append(createHotkeyTool())

        // Window management tools
        tools.append(createListWindowsTool())
        tools.append(createFocusWindowTool())
        tools.append(createResizeWindowTool())
        tools.append(createListScreensTool())

        // Space management tools (temporarily disabled due to missing SpaceManagementService)
        // tools.append(createListSpacesTool())
        // tools.append(createSwitchSpaceTool())
        // tools.append(createMoveWindowToSpaceTool())

        // Application tools
        tools.append(createListAppsTool())
        tools.append(createLaunchAppTool())

        // Element tools
        tools.append(createFindElementTool())
        tools.append(createListElementsTool())
        tools.append(createFocusedTool())

        // Menu tools
        tools.append(createMenuClickTool())
        tools.append(createListMenusTool())

        // Dialog tools
        tools.append(createDialogClickTool())
        tools.append(createDialogInputTool())

        // Dock tools
        tools.append(createDockLaunchTool())
        tools.append(createListDockTool())

        // Shell tool
        tools.append(createShellTool())

        // Completion tools
        tools.append(CompletionTools.createDoneTool())
        tools.append(CompletionTools.createNeedInfoTool())

        return tools
    }

    /// Create SimpleTool versions of essential Peekaboo tools for TachikomaCore integration
    private func createSimpleTools() -> [SimpleTool] {
        let services = self.services
        var tools: [SimpleTool] = []

        // Simple test tool with no parameters
        do {
            let simpleTool = try tool(name: "get_time", description: "Get the current time") { builder in
                builder.execute { _ in
                    let formatter = DateFormatter()
                    formatter.timeStyle = .medium
                    return .string("Current time: \(formatter.string(from: Date()))")
                }
            }
            tools.append(simpleTool)
        } catch {
            print("Failed to create time tool: \(error)")
        }

        // Simple calculator tool
        do {
            let calcTool = try tool(
                name: "calculate",
                description: "Perform simple math calculations like 1+1, 2*3, etc.")
            { builder in
                builder
                    .stringParameter(
                        "expression",
                        description: "Math expression like '1+1' or '2*3'",
                        required: true)
                    .execute { args in
                        // Debug: Print all arguments received
                        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
                            ProcessInfo.processInfo.arguments.contains("-v")
                        {
                            print("DEBUG Calculator tool received arguments:")
                            // This is a hack to see what we received - args doesn't have a way to iterate
                            for testKey in ["expression", "expr", "math", "calculation", "equation", "problem"] {
                                if let value = args.getStringOptional(testKey) {
                                    print("DEBUG   \(testKey): '\(value)'")
                                }
                            }
                        }

                        guard let expression = args.getStringOptional("expression"),
                              !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else {
                            return .string("Error: Empty expression")
                        }

                        let cleanExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)

                        // Handle common simple cases first
                        let simpleCases = [
                            "1+1": "2",
                            "2+2": "4",
                            "2*3": "6",
                            "3*4": "12",
                            "10/2": "5",
                            "5-3": "2",
                        ]

                        if let result = simpleCases[cleanExpression] {
                            return .string(result)
                        }

                        // Validate the expression contains only safe characters
                        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/().")
                        if !cleanExpression.unicodeScalars.allSatisfy(allowedCharacters.contains) {
                            return .string(
                                "Error: Expression contains invalid characters. Only numbers, +, -, *, /, (, ), and . are allowed.")
                        }

                        // Additional safety: Check for malformed expressions
                        if cleanExpression.contains("==") || cleanExpression.hasPrefix("=") || cleanExpression
                            .hasSuffix("=")
                        {
                            return .string(
                                "Error: Invalid expression format. Use arithmetic expressions like '1+1', not equations.")
                        }

                        // Try to evaluate using NSExpression with error handling
                        do {
                            let nsExpression = NSExpression(format: cleanExpression)
                            if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
                                return .string("\(result)")
                            } else {
                                return .string("Error: Could not evaluate expression '\(cleanExpression)'")
                            }
                        } catch {
                            return .string(
                                "Error: Invalid expression '\(cleanExpression)': \(error.localizedDescription)")
                        }
                    }
            }
            tools.append(calcTool)
        } catch {
            print("Failed to create calculator tool: \(error)")
        }

        // List apps tool
        do {
            let listAppsTool = try tool(name: "list_apps", description: "List all running applications") { builder in
                builder.execute { _ in
                    let result = try await services.applications.listApplications()
                    let runningApps = result.data.applications
                    let appNames = runningApps.map(\.name).sorted()
                    return .string("Running applications: " + appNames.joined(separator: ", "))
                }
            }
            tools.append(listAppsTool)
        } catch {
            // Skip if tool creation fails
        }

        // See (screenshot) tool
        do {
            let seeTool = try tool(
                name: "see",
                description: "Capture and analyze the current screen or application")
            { builder in
                builder
                    .stringParameter("app", description: "Application name to capture (optional)", required: false)
                    .execute { args in
                        let appName = args.getStringOptional("app")

                        // Capture screen
                        let captureResult = try await services.screenCapture.captureScreen(
                            displayIndex: nil)

                        // Return basic screen capture information
                        // TODO: Implement AI analysis using Tachikoma vision models
                        let windowInfo = captureResult.metadata.windowInfo?.title ?? "Unknown"
                        return .string(
                            "Screen captured successfully. Window: \(windowInfo). Path: \(captureResult.savedPath ?? "N/A")")
                    }
            }
            tools.append(seeTool)
        } catch {
            // Skip if tool creation fails
        }

        // Click tool
        do {
            let clickTool = try tool(name: "click", description: "Click on UI elements") { builder in
                builder
                    .stringParameter("element", description: "Description of the element to click", required: true)
                    .boolParameter("double", description: "Whether to double-click", required: false)
                    .execute { args in
                        let elementDescription = try args.getString("element")
                        let isDouble = args.getBoolOptional("double") ?? false

                        // For now, return a message indicating what would be clicked
                        // TODO: Implement actual element detection and clicking
                        let clickType = isDouble ? "Double-click" : "Click"
                        return .string("\(clickType) on '\(elementDescription)' - Feature not yet implemented")
                    }
            }
            tools.append(clickTool)
        } catch {
            // Skip if tool creation fails
        }

        // Shell/bash tool
        do {
            let shellTool = try tool(name: "run_bash", description: "Execute shell commands") { builder in
                builder
                    .stringParameter("command", description: "Shell command to execute", required: true)
                    .execute { args in
                        let command = try args.getString("command")

                        // Shell execution is not available in ProcessService - it's for Peekaboo scripts
                        // For now, return a placeholder
                        return .string("Shell command execution not yet implemented: \(command)")
                    }
            }
            tools.append(shellTool)
        } catch {
            // Skip if tool creation fails
        }

        return tools
    }

    // MARK: - Helper Methods

    private func buildAdditionalParameters(modelName: String, apiType: String?) -> ModelParameters? {
        var params = ModelParameters(modelName: modelName)

        // Check if API type is explicitly specified
        if let specifiedApiType = apiType {
            params = params.with("apiType", value: specifiedApiType)
        } else if !modelName.hasPrefix("grok") && !modelName.hasPrefix("claude") {
            // Default to Responses API for OpenAI models only (better streaming support)
            // Grok and Anthropic models don't need this parameter
            params = params.with("apiType", value: "responses")
        }

        // Add reasoning parameters for o3/o4 models
        if modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
            params = params
                .with("reasoning_effort", value: "medium")
                .with("max_completion_tokens", value: 4096)
                .with("reasoning", value: "summary:detailed")
        }

        // Only log API type debug info in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            let apiTypeValue = params.stringValue("apiType") ?? "nil"
            let debugMsg = "DEBUG PeekabooAgentService: Model '\(modelName)' -> API Type: \(apiTypeValue)"
            FileHandle.standardError.write((debugMsg + "\n").data(using: .utf8)!)
        }

        return params.isEmpty ? nil : params
    }
}

// MARK: - Convenience Methods

extension PeekabooAgentService {
    /// Create a simple agent for basic tasks
    public func createSimpleAgent(
        model: LanguageModel? = nil) async throws -> PeekabooAgent<PeekabooServices>
    {
        try await self.createAutomationAgent(
            name: "Simple Assistant",
            model: model)
    }

    /// Resume a previous session
    public func resumeSession(
        sessionId: String,
        model: LanguageModel? = nil,
        eventDelegate: AgentEventDelegate? = nil) async throws -> AgentExecutionResult
    {
        // Load the session
        guard try await self.sessionManager.loadSession(id: sessionId) != nil else {
            throw PeekabooError.sessionNotFound(sessionId)
        }

        // Use AgentRunner to resume the session with existing messages
        // Note: In the new API, we don't need to create agents - we use direct functions

        // Create a continuation prompt if needed
        let continuationPrompt = "Continue from where we left off."

        // Execute with the loaded session
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            let unsafeDelegate = UnsafeTransfer<AgentEventDelegate>(eventDelegate!)

            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()

            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue

                // Send start event
                delegate.agentDidEmitEvent(.started(task: continuationPrompt))

                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }

            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }

            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }

            // Create event delegate wrapper for streaming
            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            // Run the agent with streaming
            let selectedModel = model ?? self.defaultLanguageModel
            let result = try await self.executeWithStreaming(
                continuationPrompt,
                model: selectedModel,
                maxSteps: 20,
                streamingDelegate: streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Execute without streaming
            let selectedModel = model ?? self.defaultLanguageModel
            return try await self.executeWithoutStreaming(continuationPrompt, model: selectedModel, maxSteps: 20)
        }
    }

    // MARK: - Session Management

    /// List available sessions
    public func listSessions() async throws -> [SessionSummary] {
        let sessions = self.sessionManager.listSessions()
        // SessionSummary is already returned from listSessions()
        return sessions
    }

    /// Get detailed session information
    public func getSessionInfo(sessionId: String) async throws -> AgentSession? {
        try await self.sessionManager.loadSession(id: sessionId)
    }

    /// Delete a specific session
    public func deleteSession(id: String) async throws {
        try await self.sessionManager.deleteSession(id: id)
    }

    /// Clear all sessions
    public func clearAllSessions() async throws {
        // Not available in current AgentSessionManager implementation
        // Would need to iterate and delete individual sessions
        let sessions = self.sessionManager.listSessions()
        for session in sessions {
            try await self.sessionManager.deleteSession(id: session.id)
        }
    }
}

// MARK: - Event Handler

private actor EventHandler {
    private let handler: @Sendable (AgentEvent) async -> Void

    init(handler: @escaping @Sendable (AgentEvent) async -> Void) {
        self.handler = handler
    }

    func send(_ event: AgentEvent) async {
        await self.handler(event)
    }
}

// MARK: - Unsafe Transfer

/// Safely transfer non-Sendable values across isolation boundaries
private struct UnsafeTransfer<T>: @unchecked Sendable {
    let wrappedValue: T

    init(_ value: T) {
        self.wrappedValue = value
    }
}

// MARK: - Tool Creation Helpers

extension PeekabooAgentService {
    /// Create a Tachikoma tool with full parameter support
    func createTool(
        name: String,
        description: String,
        parameters: ToolParameters,
        execute: @escaping @Sendable (ToolInput, PeekabooServices) async throws -> ToolOutput) -> Tool<PeekabooServices>
    {
        Tool(
            name: name,
            description: description,
            execute: execute)
    }

    /// Create a simple Tachikoma tool without parameters
    func createSimpleTool(
        name: String,
        description: String,
        execute: @escaping @Sendable (ToolInput, PeekabooServices) async throws -> ToolOutput) -> Tool<PeekabooServices>
    {
        Tool(
            name: name,
            description: description,
            execute: execute)
    }

    // MARK: - Helper Functions

    /// Parse a model string and return a mock model object for compatibility
    /// TODO: Replace with direct LanguageModel enum usage
    private func parseModelString(_ modelString: String) async throws -> Any {
        // This is a compatibility stub - in the new API we don't need to "get" models
        // We just use LanguageModel enum directly with generateText/streamText
        modelString
    }

    /// Execute task using direct streamText calls with event streaming
    private func executeWithStreaming(
        _ task: String,
        model: LanguageModel,
        maxSteps: Int = 20,
        streamingDelegate: StreamingEventDelegate) async throws -> AgentExecutionResult
    {
        let startTime = Date()
        let sessionId = UUID().uuidString

        // Create conversation with the task
        let messages = [
            ModelMessage.system(AgentSystemPrompt.generate()),
            ModelMessage.user(task)
        ]

        // Create tools for the model (convert to SimpleTool format)
        let tools = self.createSimpleTools()

        // Only log tool debug info in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Passing \(tools.count) tools to generateText")
            for tool in tools {
                print("DEBUG: Tool '\(tool.name)' has \(tool.parameters.properties.count) parameters")
            }
        }

        // Debug: Log which model is being used (streaming)
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG PeekabooAgentService (streaming): Using model: \(model)")
            print("DEBUG PeekabooAgentService (streaming): Model description: \(model.description)")
        }

        // IMPORTANT: TachikomaCore streamText doesn't handle tool execution
        // Use generateText instead when tools are present
        let response = try await generateText(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            maxSteps: maxSteps)

        let fullContent = response.text

        // Send the complete response to streaming delegate
        await streamingDelegate.onChunk(fullContent)

        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)

        // Create result
        return AgentExecutionResult(
            content: fullContent,
            messages: response.messages,
            sessionId: sessionId,
            usage: response.usage,
            metadata: AgentMetadata(
                executionTime: executionTime,
                toolCallCount: response.steps.reduce(0) { $0 + $1.toolCalls.count },
                modelName: model.description,
                startTime: startTime,
                endTime: endTime))
    }

    /// Execute task using direct generateText calls without streaming
    private func executeWithoutStreaming(
        _ task: String,
        model: LanguageModel,
        maxSteps: Int = 20) async throws -> AgentExecutionResult
    {
        let startTime = Date()
        let sessionId = UUID().uuidString

        // Create conversation with the task
        let messages = [
            ModelMessage.system(AgentSystemPrompt.generate()),
            ModelMessage.user(task)
        ]

        // Create tools for the model (convert to SimpleTool format)
        let tools = self.createSimpleTools()

        // Only log tool debug info in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Passing \(tools.count) tools to generateText (non-streaming)")
            for tool in tools {
                print("DEBUG: Tool '\(tool.name)' has \(tool.parameters.properties.count) parameters")
            }
        }

        // Debug: Log which model is being used
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG PeekabooAgentService: Using model: \(model)")
            print("DEBUG PeekabooAgentService: Model description: \(model.description)")
        }

        // Generate the response
        let response = try await generateText(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            maxSteps: maxSteps)

        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)

        // Create result
        return AgentExecutionResult(
            content: response.text,
            messages: messages + [ModelMessage.assistant(response.text)],
            sessionId: sessionId,
            usage: nil, // Usage info not available from generateText yet
            metadata: AgentMetadata(
                executionTime: executionTime,
                toolCallCount: 0,
                modelName: model.description,
                startTime: startTime,
                endTime: endTime))
    }
}
