//
//  PeekabooAgentService+Execution.swift
//  PeekabooCore
//

import Foundation
import Tachikoma

@available(macOS 14.0, *)
extension PeekabooAgentService {
    func generationSettings(for model: LanguageModel) -> GenerationSettings {
        switch model {
        case .openai(.gpt51), .openai(.gpt5):
            GenerationSettings(
                maxTokens: 4096,
                providerOptions: .init(openai: .init(verbosity: .medium)))
        case .anthropic:
            GenerationSettings(
                maxTokens: 4096,
                providerOptions: .init(anthropic: .init(thinking: .enabled(budgetTokens: 12000))))
        case .google:
            GenerationSettings(maxTokens: 4096)
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

    func executeAudioStreamingTask(
        input: String,
        maxSteps: Int,
        queueMode: QueueMode,
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
            queueMode: queueMode,
            eventHandler: eventHandler)

        await eventHandler.send(.completed(summary: result.content, usage: result.usage))
        return result
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
struct UnsafeTransfer<T>: @unchecked Sendable {
    let wrappedValue: T

    init(_ value: T) {
        self.wrappedValue = value
    }
}

@available(macOS 14.0, *)
extension PeekabooAgentService {
    // MARK: - Helper Functions

    /// Parse a model string and return a mock model object for compatibility
    func parseModelString(_ modelString: String) async throws -> Any {
        // This is a compatibility stub - in the new API we use LanguageModel enum directly
        modelString
    }

    /// Execute task using direct streamText calls with event streaming
    func executeWithStreaming(
        context: SessionContext,
        model: LanguageModel,
        maxSteps: Int = 20,
        streamingDelegate: StreamingEventDelegate,
        queueMode: QueueMode = .oneAtATime,
        eventHandler: EventHandler? = nil,
        enhancementOptions: AgentEnhancementOptions? = nil) async throws -> AgentExecutionResult
    {
        _ = streamingDelegate
        let tools = await self.buildToolset(for: model)
        self.logModelUsage(model, prefix: "Streaming ")

        let configuration = StreamingLoopConfiguration(
            model: model,
            tools: tools,
            sessionId: context.id,
            eventHandler: eventHandler,
            enhancementOptions: enhancementOptions)

        let outcome = try await self.runStreamingLoop(
            configuration: configuration,
            maxSteps: maxSteps,
            initialMessages: context.messages,
            queueMode: queueMode)

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
    func executeWithoutStreaming(
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
