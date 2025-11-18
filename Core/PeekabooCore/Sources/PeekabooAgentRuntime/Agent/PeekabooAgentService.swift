import CoreGraphics
import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooFoundation
import Tachikoma
import TachikomaMCP

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
    let services: any PeekabooServiceProviding
    let sessionManager: AgentSessionManager
    private let defaultLanguageModel: LanguageModel
    var currentModel: LanguageModel?
    let logger = os.Logger(subsystem: "boo.peekaboo", category: "agent")
    var isVerbose: Bool = false

    /// The default model used by this agent service
    public var defaultModel: String { self.defaultLanguageModel.description }

    /// Get the masked API key for the current model
    public var maskedApiKey: String? {
        get async {
            // Get the current model
            let model = self.currentModel ?? self.defaultLanguageModel

            // Get the configuration
            let config = TachikomaConfiguration.current

            // Determine the provider based on the model
            let apiKey: String? = switch model {
            case .openai:
                config.getAPIKey(for: .openai)
            case .anthropic:
                config.getAPIKey(for: .anthropic)
            case .google:
                config.getAPIKey(for: .google)
            case .mistral:
                config.getAPIKey(for: .mistral)
            case .groq:
                config.getAPIKey(for: .groq)
            case .grok:
                config.getAPIKey(for: .grok)
            case .ollama:
                config.getAPIKey(for: .ollama)
            case .lmstudio:
                config.getAPIKey(for: .lmstudio)
            case .azureOpenAI:
                config.getAPIKey(for: .azureOpenAI)
            case .openRouter:
                config.getAPIKey(for: .custom("openrouter"))
            case .together:
                config.getAPIKey(for: .custom("together"))
            case .replicate:
                config.getAPIKey(for: .custom("replicate"))
            case .openaiCompatible, .anthropicCompatible:
                nil // Custom endpoints may have keys embedded
            case .custom:
                nil // Custom providers handle their own keys
            }

            // Mask the API key
            guard let key = apiKey, !key.isEmpty else {
                return nil
            }

            // Show first 5 and last 5 characters
            if key.count > 15 {
                let prefix = String(key.prefix(5))
                let suffix = String(key.suffix(5))
                return "\(prefix)...\(suffix)"
            } else if key.count > 8 {
                // For shorter keys, show less
                let prefix = String(key.prefix(3))
                let suffix = String(key.suffix(3))
                return "\(prefix)...\(suffix)"
            } else {
                // Very short keys, just show asterisks
                return String(repeating: "*", count: key.count)
            }
        }
    }

    public init(
        services: any PeekabooServiceProviding,
        defaultModel: LanguageModel = .openai(.gpt51))
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
        eventDelegate: (any AgentEventDelegate)? = nil) async throws -> AgentExecutionResult
    {
        try await self.executeTask(
            task,
            maxSteps: maxSteps,
            sessionId: nil,
            model: nil,
            dryRun: dryRun,
            eventDelegate: eventDelegate,
            verbose: self.isVerbose)
    }

    /// Execute a task with audio content
    public func executeTaskWithAudio(
        audioContent: AudioContent,
        maxSteps: Int = 20,
        dryRun: Bool = false,
        eventDelegate: (any AgentEventDelegate)? = nil) async throws -> AgentExecutionResult
    {
        if dryRun {
            let transcript = audioContent.transcript
            let durationSeconds = Int(audioContent.duration ?? 0)
            let description = transcript ?? "[Audio message - duration: \(durationSeconds)s]"
            return self.makeAudioDryRunResult(description: description)
        }

        let input = audioContent.transcript ?? "[Audio message without transcript]"

        if let eventDelegate {
            return try await self.executeAudioStreamingTask(
                input: input,
                maxSteps: maxSteps,
                eventDelegate: eventDelegate)
        }

        let sessionContext = try await self.prepareSession(
            task: input,
            model: self.defaultLanguageModel,
            label: "audio",
            logBehavior: .verboseOnly)
        return try await self.executeWithoutStreaming(
            context: sessionContext,
            model: self.defaultLanguageModel,
            maxSteps: maxSteps)
    }

    /// Clean up any cached sessions or resources
    public func cleanup() async {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let sessions = self.sessionManager.listSessions()

        for session in sessions where session.lastAccessedAt < cutoff {
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
        dryRun: Bool = false,
        eventDelegate: (any AgentEventDelegate)? = nil,
        verbose: Bool = false) async throws -> AgentExecutionResult
    {
        // Store the verbose flag for this execution
        self.isVerbose = verbose
        if verbose {
            print("DEBUG: Verbose mode enabled in PeekabooAgentService")
        }

        // Set verbose mode in Tachikoma configuration
        TachikomaConfiguration.current.setVerbose(verbose)

        let selectedModel = self.resolveModel(model)

        if dryRun {
            return AgentExecutionResult(
                content: "Dry run completed. Task would be: \(task)",
                messages: [],
                sessionId: sessionId ?? UUID().uuidString,
                usage: nil,
                metadata: AgentMetadata(
                    executionTime: 0,
                    toolCallCount: 0,
                    modelName: selectedModel.description,
                    startTime: Date(),
                    endTime: Date()))
        }

        // If we have an event delegate, use streaming
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer<any AgentEventDelegate>(eventDelegate!)

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

            // Create event delegate wrapper for streaming
            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            let sessionContext = try await self.prepareSession(
                task: task,
                model: selectedModel,
                label: "streaming",
                logBehavior: .always)

            let result = try await self.executeWithStreaming(
                context: sessionContext,
                model: selectedModel,
                maxSteps: maxSteps,
                streamingDelegate: streamingDelegate,
                eventHandler: eventHandler)

            // Send completion event with usage information
            await eventHandler.send(.completed(summary: result.content, usage: result.usage))

            return result
        } else {
            // Non-streaming execution
            let sessionContext = try await self.prepareSession(
                task: task,
                model: selectedModel,
                label: "(non-streaming)",
                logBehavior: .verboseOnly)
            return try await self.executeWithoutStreaming(
                context: sessionContext,
                model: selectedModel,
                maxSteps: maxSteps)
        }
    }

    /// Execute a task with streaming output
    public func executeTaskStreaming(
        _ task: String,
        sessionId: String? = nil,
        model: LanguageModel? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void) async throws -> AgentExecutionResult
    {
        // Execute a task with streaming output
        let selectedModel = self.resolveModel(model)
        // For streaming without event handler, create a dummy delegate that discards chunks
        let dummyDelegate = StreamingEventDelegate { _ in /* discard */ }
        let sessionContext = try await self.prepareSession(
            task: task,
            model: selectedModel,
            label: "streaming-api",
            logBehavior: .always)
        return try await self.executeWithStreaming(
            context: sessionContext,
            model: selectedModel,
            maxSteps: 20,
            streamingDelegate: dummyDelegate,
            eventHandler: nil)
    }

    private func resolveModel(_ requestedModel: LanguageModel?) -> LanguageModel {
        let candidate = requestedModel ?? self.defaultLanguageModel

        switch candidate {
        case .openai:
            return .openai(.gpt51)
        case .anthropic:
            return .anthropic(.sonnet45)
        default:
            return .openai(.gpt51)
        }
    }

    // MARK: - Tool Creation
}

// MARK: - Convenience Methods

extension PeekabooAgentService {
    func generationSettings(for model: LanguageModel) -> GenerationSettings {
        switch model {
        case .openai(.gpt51), .openai(.gpt5):
            GenerationSettings(
                maxTokens: 4096,
                providerOptions: .init(openai: .init(verbosity: .medium)))
        default:
            GenerationSettings(maxTokens: 4096)
        }
    }

    func makeAudioDryRunResult(description: String) -> AgentExecutionResult {
        let now = Date()
        return AgentExecutionResult(
            content: "Dry run completed. Audio task: \(description)",
            messages: [],
            sessionId: UUID().uuidString,
            usage: nil,
            metadata: AgentMetadata(
                executionTime: 0,
                toolCallCount: 0,
                modelName: self.defaultLanguageModel.description,
                startTime: now,
                endTime: now))
    }

    private func executeAudioStreamingTask(
        input: String,
        maxSteps: Int,
        eventDelegate: any AgentEventDelegate) async throws -> AgentExecutionResult
    {
        let unsafeDelegate = UnsafeTransfer<any AgentEventDelegate>(eventDelegate)
        let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()

        let eventTask = Task { @MainActor in
            let delegate = unsafeDelegate.wrappedValue
            for await event in eventStream {
                delegate.agentDidEmitEvent(event)
            }
        }

        let eventHandler = EventHandler { event in
            eventContinuation.yield(event)
        }

        defer {
            eventContinuation.finish()
            eventTask.cancel()
        }

        let streamingDelegate = await MainActor.run {
            StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }
        }

        let sessionContext = try await self.prepareSession(
            task: input,
            model: self.defaultLanguageModel,
            label: "audio-stream",
            logBehavior: .always)

        let result = try await self.executeWithStreaming(
            context: sessionContext,
            model: self.defaultLanguageModel,
            maxSteps: maxSteps,
            streamingDelegate: streamingDelegate,
            eventHandler: eventHandler)

        await eventHandler.send(.completed(summary: result.content, usage: result.usage))
        return result
    }
}

extension PeekabooAgentService {
    public func continueSession(
        sessionId: String,
        userMessage: String,
        model: LanguageModel? = nil,
        maxSteps: Int = 20,
        dryRun: Bool = false,
        eventDelegate: (any AgentEventDelegate)? = nil,
        verbose: Bool = false) async throws -> AgentExecutionResult
    {
        self.isVerbose = verbose
        TachikomaConfiguration.current.setVerbose(verbose)

        guard let existingSession = try await self.sessionManager.loadSession(id: sessionId) else {
            throw PeekabooError.sessionNotFound(sessionId)
        }

        if dryRun {
            let now = Date()
            return AgentExecutionResult(
                content: "Dry run completed. Session \(sessionId) would receive: \(userMessage)",
                messages: existingSession.messages,
                sessionId: sessionId,
                usage: nil,
                metadata: AgentMetadata(
                    executionTime: 0,
                    toolCallCount: 0,
                    modelName: existingSession.modelName,
                    startTime: now,
                    endTime: now))
        }

        let selectedModel = self.resolveModel(model)
        let sessionContext = self.makeContinuationContext(from: existingSession, userMessage: userMessage)

        if let eventDelegate {
            let unsafeDelegate = UnsafeTransfer<any AgentEventDelegate>(eventDelegate)
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()

            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                delegate.agentDidEmitEvent(.started(task: userMessage))
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }

            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }

            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }

            let streamingDelegate = StreamingEventDelegate { chunk in
                await eventHandler.send(.assistantMessage(content: chunk))
            }

            let result = try await self.executeWithStreaming(
                context: sessionContext,
                model: selectedModel,
                maxSteps: maxSteps,
                streamingDelegate: streamingDelegate,
                eventHandler: eventHandler)

            await eventHandler.send(.completed(summary: result.content, usage: result.usage))
            return result
        } else {
            return try await self.executeWithoutStreaming(
                context: sessionContext,
                model: selectedModel,
                maxSteps: maxSteps)
        }
    }

    /// Resume a previous session
    public func resumeSession(
        sessionId: String,
        model: LanguageModel? = nil,
        eventDelegate: (any AgentEventDelegate)? = nil) async throws -> AgentExecutionResult
    {
        let continuationPrompt = "Continue from where we left off."
        return try await self.continueSession(
            sessionId: sessionId,
            userMessage: continuationPrompt,
            model: model,
            maxSteps: 20,
            dryRun: false,
            eventDelegate: eventDelegate,
            verbose: self.isVerbose)
    }

    // MARK: - Session Management

    /// List available sessions
    public func listSessions() async throws -> [SessionSummary] {
        // List available sessions
        let sessions = self.sessionManager.listSessions()
        // SessionSummary is already returned from listSessions()
        return sessions
    }

    /// Get detailed session information
    public func getSessionInfo(sessionId: String) async throws -> AgentSession? {
        // Get detailed session information
        try await self.sessionManager.loadSession(id: sessionId)
    }

    /// Delete a specific session
    public func deleteSession(id: String) async throws {
        // Delete a specific session
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

actor EventHandler {
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

extension AgentToolParameters {
    static let empty = AgentToolParameters(properties: [:], required: [])
}

extension PeekabooAgentService {
    /// Convert MCP Value schema to AgentToolParameters
    private func convertMCPValueToAgentParameters(_ value: MCP.Value) -> AgentToolParameters {
        guard case let .object(schemaDict) = value else {
            return .empty
        }

        let required = self.parseRequiredFields(in: schemaDict)

        guard let propertiesValue = schemaDict["properties"],
              case let .object(properties) = propertiesValue
        else {
            return AgentToolParameters(properties: [:], required: required)
        }

        let agentProperties = self.convertPropertyMap(properties)
        return AgentToolParameters(properties: agentProperties, required: required)
    }

    private func parseRequiredFields(in schemaDict: [String: MCP.Value]) -> [String] {
        guard let requiredValue = schemaDict["required"],
              case let .array(requiredArray) = requiredValue
        else {
            return []
        }

        return requiredArray.compactMap { value in
            if case let .string(stringValue) = value {
                return stringValue
            }
            return nil
        }
    }

    private func convertPropertyMap(
        _ properties: [String: MCP.Value]) -> [String: AgentToolParameterProperty]
    {
        var agentProperties: [String: AgentToolParameterProperty] = [:]

        for (name, value) in properties {
            guard let property = self.convertProperty(name: name, value: value) else { continue }
            agentProperties[name] = property
        }

        return agentProperties
    }

    private func convertProperty(
        name: String,
        value: MCP.Value) -> AgentToolParameterProperty?
    {
        guard case let .object(propertyDict) = value else { return nil }

        return AgentToolParameterProperty(
            name: name,
            type: self.parameterType(from: propertyDict["type"]),
            description: self.propertyDescription(from: propertyDict["description"], defaultName: name))
    }

    private func parameterType(
        from value: MCP.Value?) -> AgentToolParameterProperty.ParameterType
    {
        guard case let .string(typeString) = value else { return .string }

        switch typeString {
        case "string":
            return .string
        case "number":
            return .number
        case "integer":
            return .integer
        case "boolean":
            return .boolean
        case "array":
            return .array
        case "object":
            return .object
        default:
            return .string
        }
    }

    private func propertyDescription(from value: MCP.Value?, defaultName: String) -> String {
        if case let .string(description) = value {
            return description
        }
        return "Parameter \(defaultName)"
    }

    private func buildToolset(for model: LanguageModel) async -> [AgentTool] {
        var tools = self.createAgentTools()
        let mcpToolsByServer = await TachikomaMCPClientManager.shared.getExternalToolsByServer()

        for (serverName, serverTools) in mcpToolsByServer {
            for tool in serverTools {
                let parameters = self.convertMCPValueToAgentParameters(tool.inputSchema)
                let prefixedTool = AgentTool(
                    name: "\(serverName)_\(tool.name)",
                    description: tool.description ?? "",
                    parameters: parameters,
                    execute: { args in
                        var argDict: [String: Any] = [:]
                        for key in args.keys {
                            if let value = args[key] {
                                argDict[key] = try value.toJSON()
                            }
                        }

                        let result = try await TachikomaMCPClientManager.shared.executeTool(
                            serverName: serverName,
                            toolName: tool.name,
                            arguments: argDict)

                        for contentItem in result.content {
                            if case let .text(text) = contentItem {
                                return AnyAgentToolValue(string: text)
                            }
                        }
                        return AnyAgentToolValue(string: "Tool executed successfully")
                    })
                tools.append(prefixedTool)
            }
        }

        self.logToolsetDetails(tools, model: model)
        return tools
    }

    private func logToolsetDetails(_ tools: [AgentTool], model: LanguageModel) {
        guard self.isVerbose else { return }
        self.logger.debug("Using model: \(model)")
        self.logger.debug("Model description: \(model.description)")
        self.logger.debug("Passing \(tools.count) tools to generateText")
        for tool in tools {
            let propertyCount = tool.parameters.properties.count
            let requiredCount = tool.parameters.required.count
            self.logger.debug(
                "Tool '\(tool.name)' has \(propertyCount) properties, \(requiredCount) required")
            if tool.name == "see" {
                self.logger.debug("'see' tool required array: \(tool.parameters.required)")
            }
        }
    }

    /// Create AgentTool instances from native Peekaboo tools
    public func createAgentTools() -> [Tachikoma.AgentTool] {
        // Create AgentTool instances from native Peekaboo tools
        var agentTools: [Tachikoma.AgentTool] = []

        // Vision tools
        agentTools.append(createSeeTool())
        agentTools.append(createImageTool())
        agentTools.append(createCaptureTool())
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

        // Application tools
        agentTools.append(createListAppsTool())
        agentTools.append(createLaunchAppTool())
        agentTools.append(createAppTool()) // Full app management (launch, quit, focus, etc.)

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
        modelString
    }

    /// Execute task using direct streamText calls with event streaming
    private func executeWithStreaming(
        context: SessionContext,
        model: LanguageModel,
        maxSteps: Int = 20,
        streamingDelegate: StreamingEventDelegate,
        eventHandler: EventHandler? = nil) async throws -> AgentExecutionResult
    {
        _ = streamingDelegate
        let tools = await self.buildToolset(for: model)
        self.logModelUsage(model, prefix: "Streaming ")

        let configuration = StreamingLoopConfiguration(
            model: model,
            tools: tools,
            sessionId: context.id,
            eventHandler: eventHandler)

        let outcome = try await self.runStreamingLoop(
            configuration: configuration,
            maxSteps: maxSteps,
            initialMessages: context.messages)

        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(context.executionStart)
        let toolCallCount = outcome.toolCallCount

        try self.saveCompletedSession(
            context: context,
            model: model,
            finalMessages: outcome.messages,
            endTime: endTime,
            toolCallCount: toolCallCount,
            usage: outcome.usage)

        return AgentExecutionResult(
            content: outcome.content,
            messages: outcome.messages,
            sessionId: context.id,
            usage: outcome.usage,
            metadata: self.makeExecutionMetadata(
                model: model,
                executionTime: executionTime,
                toolCallCount: toolCallCount,
                startTime: context.executionStart,
                endTime: endTime))
    }

    /// Execute task using direct generateText calls without streaming
    private func executeWithoutStreaming(
        context: SessionContext,
        model: LanguageModel,
        maxSteps: Int = 20) async throws -> AgentExecutionResult
    {
        let tools = await self.buildToolset(for: model)
        self.logModelUsage(model, prefix: "")

        let response = try await generateText(
            model: model,
            messages: context.messages,
            tools: tools.isEmpty ? nil : tools,
            maxSteps: maxSteps)

        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(context.executionStart)
        let finalMessages = context.messages + [ModelMessage.assistant(response.text)]

        try self.saveCompletedSession(
            context: context,
            model: model,
            finalMessages: finalMessages,
            endTime: endTime,
            toolCallCount: 0,
            usage: nil)

        return AgentExecutionResult(
            content: response.text,
            messages: finalMessages,
            sessionId: context.id,
            usage: nil,
            metadata: self.makeExecutionMetadata(
                model: model,
                executionTime: executionTime,
                toolCallCount: 0,
                startTime: context.executionStart,
                endTime: endTime))
    }
}
