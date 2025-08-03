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
            return "***"
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

        // Use the new architecture internally
        let agent = try await self.createAutomationAgent(model: self.defaultLanguageModel)

        // Create a new session for this task
        let sessionId = UUID().uuidString

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

            let result = try await self.runStreamingStub(agent, task, selectedModel, streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Execute without streaming
            let selectedModel = self.defaultLanguageModel
            return try await self.runStub(agent, task, selectedModel)
        }
    }

    /// Execute a task with audio content
    public func executeTaskWithAudio(
        audioContent: AudioContent,
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

        // Use the new architecture internally
        let agent = try await self.createAutomationAgent(model: self.defaultLanguageModel)

        // Create a new session for this task
        let sessionId = UUID().uuidString

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

            let result = try await self.runStreamingStub(agent, input, selectedModel, streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // For now, convert audio to text if transcript is available
            // In the future, we'll pass audio directly to providers that support it
            let input = audioContent.transcript ?? "[Audio message without transcript]"

            // Execute without streaming
            let selectedModel = self.defaultLanguageModel
            return try await self.runStub(agent, input, selectedModel)
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
        sessionId: String? = nil,
        model: LanguageModel? = nil,
        eventDelegate: AgentEventDelegate? = nil) async throws -> AgentExecutionResult
    {
        let agent = try await self.createAutomationAgent(model: model)

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
            let selectedModel = self.defaultLanguageModel

            // Create event delegate wrapper for streaming
            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            let result = try await self.runStreamingStub(agent, task, selectedModel, streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Non-streaming execution
            let selectedModel = model ?? self.defaultLanguageModel
            return try await self.runStub(agent, task, selectedModel)
        }
    }

    /// Execute a task with streaming output
    public func executeTaskStreaming(
        _ task: String,
        sessionId: String? = nil,
        model: LanguageModel? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void) async throws -> AgentExecutionResult
    {
        let agent = try await self.createAutomationAgent(model: model)

        // AgentRunner.runStreaming doesn't have a streamHandler parameter
        // We need to use the agent directly with an event delegate
        let selectedModel = model ?? self.defaultLanguageModel
        return try await self.runStreamingStub(agent, task, selectedModel, Optional<Any>.none as Any)
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
        let agent = try await self.createAutomationAgent(model: model)

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
            let result = try await self.runStreamingStub(agent, continuationPrompt, selectedModel, streamingDelegate)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Execute without streaming
            let selectedModel = model ?? self.defaultLanguageModel
            return try await self.runStub(agent, continuationPrompt, selectedModel)
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
        return modelString
    }
    
    /// Compatibility stub for AgentRunner.runStreaming
    /// TODO: Replace with direct streamText calls
    private func runStreamingStub(_ params: Any...) async throws -> AgentExecutionResult {
        throw TachikomaError.unsupportedOperation("Legacy AgentRunner.runStreaming - use direct streamText calls")
    }
    
    /// Compatibility stub for AgentRunner.run  
    /// TODO: Replace with direct generateText calls
    private func runStub(_ params: Any...) async throws -> AgentExecutionResult {
        throw TachikomaError.unsupportedOperation("Legacy AgentRunner.run - use direct generateText calls")
    }
}
