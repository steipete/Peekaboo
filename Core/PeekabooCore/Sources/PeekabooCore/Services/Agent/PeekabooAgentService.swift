import CoreGraphics
import Foundation
import Tachikoma
import os.log


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
    internal let services: PeekabooServices
    private let sessionManager: AgentSessionManager
    private let defaultLanguageModel: LanguageModel
    private var currentModel: LanguageModel?
    private let logger = os.Logger(subsystem: "boo.peekaboo", category: "agent")

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
                streamingDelegate: streamingDelegate,
                eventHandler: eventHandler)

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
                streamingDelegate: streamingDelegate,
                eventHandler: eventHandler)

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
            streamingDelegate: dummyDelegate,
            eventHandler: nil)
    }

    // MARK: - Tool Creation


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
            logger.debug("PeekabooAgentService: Model '\(modelName)' -> API Type: \(apiTypeValue)")
        }

        return params.isEmpty ? nil : params
    }
}

// MARK: - Convenience Methods

extension PeekabooAgentService {

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
    /// Create AgentTool instances from native Peekaboo tools
    public func createAgentTools() -> [Tachikoma.AgentTool] {
        var agentTools: [Tachikoma.AgentTool] = []
        
        // Vision tools
        agentTools.append(createSeeTool())
        agentTools.append(createImageTool())
        agentTools.append(createAnalyzeTool())
        
        // UI automation tools
        agentTools.append(createClickTool())
        agentTools.append(createTypeTool())
        agentTools.append(createScrollTool())
        agentTools.append(createHotkeyTool())
        agentTools.append(createDragTool())
        agentTools.append(createMoveTool())
        agentTools.append(createSwipeTool())
        
        // Window management
        agentTools.append(createWindowTool())
        
        // Menu interaction
        agentTools.append(createMenuTool())
        
        // Dialog handling
        agentTools.append(createDialogTool())
        
        // Dock management
        agentTools.append(createDockTool())
        
        // List tool (full access)
        agentTools.append(createListTool())
        
        // Screen tools (legacy wrappers)
        agentTools.append(createListScreensTool())
        
        // Application tools (legacy wrappers + full)
        agentTools.append(createListAppsTool())
        agentTools.append(createLaunchAppTool())
        agentTools.append(createAppTool())  // Full app management
        
        // Space management
        agentTools.append(createSpaceTool())
        
        // System tools
        agentTools.append(createPermissionsTool())
        agentTools.append(createSleepTool())
        
        // Shell tool
        agentTools.append(createShellTool())
        
        // Completion tools
        agentTools.append(createDoneTool())
        agentTools.append(createNeedInfoTool())
        
        return agentTools
    }

    // MARK: - Helper Functions

    /// Parse a model string and return a mock model object for compatibility
    private func parseModelString(_ modelString: String) async throws -> Any {
        // This is a compatibility stub - in the new API we use LanguageModel enum directly
        return modelString
    }

    /// Execute task using direct streamText calls with event streaming
    private func executeWithStreaming(
        _ task: String,
        model: LanguageModel,
        maxSteps: Int = 20,
        streamingDelegate: StreamingEventDelegate,
        eventHandler: EventHandler? = nil) async throws -> AgentExecutionResult
    {
        let startTime = Date()
        let sessionId = UUID().uuidString

        // Create conversation with the task
        let messages = [
            ModelMessage.system(AgentSystemPrompt.generate()),
            ModelMessage.user(task)
        ]

        // Create and save initial session
        let session = AgentSession(
            id: sessionId,
            modelName: model.description,
            messages: messages,
            metadata: SessionMetadata(),
            createdAt: startTime,
            updatedAt: startTime
        )
        
        // Debug logging for session creation - ALWAYS print for debugging
        logger.debug("Creating session with ID: \(sessionId), messages count: \(messages.count)")
        
        do {
            try await self.sessionManager.saveSession(session)
            logger.debug("Successfully saved initial session with ID: \(sessionId)")
        } catch {
            print("ERROR (streaming): Failed to save initial session: \(error)")
            throw error
        }

        // Create tools for the model
        let tools = self.createAgentTools()

        // Only log tool debug info in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            logger.debug("Passing \(tools.count) tools to generateText")
            for tool in tools {
                logger.debug("Tool '\(tool.name)' has \(tool.parameters.properties.count) properties, \(tool.parameters.required.count) required")
                if tool.name == "see" {
                    logger.debug("'see' tool required array: \(tool.parameters.required)")
                }
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

        // Process and emit tool call events from the response
        if let eventHandler = eventHandler {
            for step in response.steps {
                for toolCall in step.toolCalls {
                    // Emit tool call started event
                    // Convert arguments to JSON string
                    let argumentsData = try JSONEncoder().encode(toolCall.arguments)
                    let argumentsJSON = String(data: argumentsData, encoding: .utf8) ?? "{}"
                    
                    let toolCallEvent = AgentEvent.toolCallStarted(
                        name: toolCall.name,
                        arguments: argumentsJSON
                    )
                    await eventHandler.send(toolCallEvent)
                    
                    // Small delay to ensure events are processed in order
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    
                    // Emit tool call completed event with result
                    if let toolResult = step.toolResults.first(where: { $0.toolCallId == toolCall.id }) {
                        // Convert tool result to string representation
                        let resultString: String
                        switch toolResult.result {
                        case .string(let str):
                            resultString = str
                        case .int(let int):
                            resultString = String(int)
                        case .double(let double):
                            resultString = String(double)
                        case .bool(let bool):
                            resultString = String(bool)
                        case .array(let array):
                            resultString = String(describing: array)
                        case .object(let obj):
                            resultString = String(describing: obj)
                        case .null:
                            resultString = "null"
                        }
                        
                        let completedEvent = AgentEvent.toolCallCompleted(
                            name: toolCall.name,
                            result: resultString
                        )
                        await eventHandler.send(completedEvent)
                        
                        // Small delay between tool calls
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }
                }
            }
        }

        let fullContent = response.text

        // Send the complete response to streaming delegate
        await streamingDelegate.onChunk(fullContent)

        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)

        // Update session with final results
        let updatedSession = AgentSession(
            id: sessionId,
            modelName: model.description,
            messages: response.messages,
            metadata: SessionMetadata(
                toolCallCount: response.steps.reduce(0) { $0 + $1.toolCalls.count },
                totalExecutionTime: executionTime,
                customData: ["status": "completed"]
            ),
            createdAt: startTime,
            updatedAt: endTime
        )
        try await self.sessionManager.saveSession(updatedSession)

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

        // Create and save initial session
        let session = AgentSession(
            id: sessionId,
            modelName: model.description,
            messages: messages,
            metadata: SessionMetadata(),
            createdAt: startTime,
            updatedAt: startTime
        )
        
        // Debug logging for session creation
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
           ProcessInfo.processInfo.arguments.contains("-v") {
            print("DEBUG (non-streaming): Creating session with ID: \(sessionId)")
            print("DEBUG (non-streaming): Session messages count: \(messages.count)")
        }
        
        do {
            try await self.sessionManager.saveSession(session)
            if ProcessInfo.processInfo.arguments.contains("--verbose") ||
               ProcessInfo.processInfo.arguments.contains("-v") {
                print("DEBUG (non-streaming): Successfully saved initial session")
            }
        } catch {
            print("ERROR (non-streaming): Failed to save initial session: \(error)")
            throw error
        }

        // Create tools for the model
        let tools = self.createAgentTools()

        // Only log tool debug info in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") ||
            ProcessInfo.processInfo.arguments.contains("-v")
        {
            print("DEBUG: Passing \(tools.count) tools to generateText (non-streaming)")
            for tool in tools {
                print("DEBUG: Tool '\(tool.name)' has \(tool.parameters.properties.count) properties, \(tool.parameters.required.count) required")
                if tool.name == "see" {
                    print("DEBUG: 'see' tool required array: \(tool.parameters.required)")
                }
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

        // Update session with final results
        let finalMessages = messages + [ModelMessage.assistant(response.text)]
        let updatedSession = AgentSession(
            id: sessionId,
            modelName: model.description,
            messages: finalMessages,
            metadata: SessionMetadata(
                toolCallCount: 0,
                totalExecutionTime: executionTime,
                customData: ["status": "completed"]
            ),
            createdAt: startTime,
            updatedAt: endTime
        )
        try await self.sessionManager.saveSession(updatedSession)

        // Create result
        return AgentExecutionResult(
            content: response.text,
            messages: finalMessages,
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
