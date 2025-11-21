//
//  PeekabooAgentService+Streaming.swift
//  PeekabooCore
//

import Foundation
import Tachikoma

@available(macOS 14.0, *)
extension PeekabooAgentService {
    struct StreamingLoopOutcome {
        let content: String
        let messages: [ModelMessage]
        let steps: [GenerationStep]
        let usage: Usage?
        let toolCallCount: Int
    }

    struct StreamingLoopConfiguration {
        let model: LanguageModel
        let tools: [AgentTool]
        let sessionId: String
        let eventHandler: EventHandler?
    }

    private struct ToolHandlingContext {
        let model: LanguageModel
        let tools: [AgentTool]
        let eventHandler: EventHandler?
        let sessionId: String

        func tool(named name: String) -> AgentTool? {
            self.tools.first { $0.name == name }
        }
    }

    private struct StreamingLoopState {
        var messages: [ModelMessage]
        var content: String = ""
        var steps: [GenerationStep] = []
        var usage: Usage?
        var toolCallCount: Int = 0
    }

    func runStreamingLoop(
        configuration: StreamingLoopConfiguration,
        maxSteps: Int,
        initialMessages: [ModelMessage],
        queueMode: QueueMode = .oneAtATime,
        pendingUserMessages: [ModelMessage] = []) async throws -> StreamingLoopOutcome
    {
        var state = StreamingLoopState(messages: initialMessages)
        let toolContext = ToolHandlingContext(
            model: configuration.model,
            tools: configuration.tools,
            eventHandler: configuration.eventHandler,
            sessionId: configuration.sessionId)

        // Queue of pending user messages (set by caller). For now, this is empty
        // and will be injected by higher-level chat loop when we add that support.
        var queuedMessages: [ModelMessage] = pendingUserMessages

        for stepIndex in 0..<maxSteps {
            self.logStreamingStepStart(stepIndex, tools: configuration.tools)

            // If queue mode is "all" and we have queued messages, inject them
            // before the next turn so the model sees them together.
            if queueMode == .all && !queuedMessages.isEmpty {
                state.messages.append(contentsOf: queuedMessages)
                queuedMessages.removeAll()
            }

            let streamResult = try await streamText(
                model: configuration.model,
                messages: state.messages,
                tools: configuration.tools.isEmpty ? nil : configuration.tools,
                settings: self.generationSettings(for: configuration.model))

            let output = try await self.collectStreamOutput(
                from: streamResult,
                eventHandler: configuration.eventHandler,
                stepIndex: stepIndex)

            state.content += output.text
            if let usage = output.usage {
                state.usage = usage
            }

            if output.toolCalls.isEmpty {
                self.appendFinalStep(
                    text: output.text,
                    to: &state.messages,
                    steps: &state.steps,
                    stepIndex: stepIndex)
                break
            }

            let step = try await self.handleToolCalls(
                stepText: output.text,
                toolCalls: output.toolCalls,
                context: toolContext,
                currentMessages: &state.messages,
                stepIndex: stepIndex)
            state.steps.append(step)
            state.toolCallCount += output.toolCalls.count

            // If queue mode is one-at-a-time, inject exactly one queued message (if any)
            if queueMode == .oneAtATime, let next = queuedMessages.first {
                state.messages.append(next)
                queuedMessages.removeFirst()
            }
        }

        let totalToolCalls = state.toolCallCount

        return StreamingLoopOutcome(
            content: state.content,
            messages: state.messages,
            steps: state.steps,
            usage: state.usage,
            toolCallCount: totalToolCalls)
    }

    private struct StreamProcessingOutput {
        let text: String
        let toolCalls: [AgentToolCall]
        let usage: Usage?
    }

    private func logStreamingStepStart(_ stepIndex: Int, tools: [AgentTool]) {
        guard self.isVerbose else { return }

        self.logger.debug("Step \(stepIndex): Passing \(tools.count) tools to streamText")
        if tools.isEmpty {
            self.logger.warning("No tools available!")
            return
        }

        let toolNames = tools.map(\.name).joined(separator: ", ")
        self.logger.debug("Available tools: \(toolNames)")
    }

    private func appendFinalStep(
        text: String,
        to messages: inout [ModelMessage],
        steps: inout [GenerationStep],
        stepIndex: Int)
    {
        if !text.isEmpty {
            messages.append(ModelMessage.assistant(text))
        }

        steps.append(GenerationStep(
            stepIndex: stepIndex,
            text: text,
            toolCalls: [],
            toolResults: []))
    }

    private struct ToolCallHandlingResult {
        let shouldContinue: Bool
        let step: GenerationStep
    }

    private func collectStreamOutput(
        from streamResult: StreamTextResult,
        eventHandler: EventHandler?,
        stepIndex: Int) async throws -> StreamProcessingOutput
    {
        var stepText = ""
        var stepToolCalls: [AgentToolCall] = []
        var seenToolCallIds = Set<String>()
        var isThinking = false
        var usage: Usage?

        if self.isVerbose {
            self.logger.debug("Starting to process stream for step \(stepIndex)")
        }

        for try await delta in streamResult.stream {
            if self.isVerbose {
                self.logger.debug("Received delta type: \(String(describing: delta.type))")
            }

            switch delta.type {
            case .textDelta:
                guard let content = delta.content else { continue }
                await self.handleTextDelta(
                    content,
                    stepText: &stepText,
                    isThinking: &isThinking,
                    eventHandler: eventHandler)

            case .toolCall:
                if let toolCall = delta.toolCall {
                    try await self.handleToolCallDelta(
                        toolCall,
                        stepToolCalls: &stepToolCalls,
                        seenToolCallIds: &seenToolCallIds,
                        eventHandler: eventHandler)
                }

            case .reasoning:
                await self.handleReasoningDelta(delta.content, eventHandler: eventHandler)

            case .done:
                usage = delta.usage

            default:
                break
            }
        }

        return StreamProcessingOutput(text: stepText, toolCalls: stepToolCalls, usage: usage)
    }

    private func handleTextDelta(
        _ content: String,
        stepText: inout String,
        isThinking: inout Bool,
        eventHandler: EventHandler?) async
    {
        if self.isVerbose {
            self.logger.debug("Text delta content: \(content)")
        }

        stepText += content
        if content.contains("<thinking>") || content.contains("Let me") ||
            content.contains("I need to") || content.contains("I'll")
        {
            isThinking = true
        }

        let trimmed = content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty, let eventHandler else { return }

        if isThinking {
            await eventHandler.send(.thinkingMessage(content: content))
        } else {
            await eventHandler.send(.assistantMessage(content: content))
        }
    }

    private func handleToolCallDelta(
        _ toolCall: AgentToolCall,
        stepToolCalls: inout [AgentToolCall],
        seenToolCallIds: inout Set<String>,
        eventHandler: EventHandler?) async throws
    {
        if self.isVerbose {
            self.logger.debug("Received tool call: \(toolCall.name) with ID: \(toolCall.id)")
        }
        let isFirstOccurrence = seenToolCallIds.insert(toolCall.id).inserted

        // Keep the latest version of this tool call so downstream handlers see current args
        if let existingIndex = stepToolCalls.firstIndex(where: { $0.id == toolCall.id }) {
            stepToolCalls[existingIndex] = toolCall
        } else {
            stepToolCalls.append(toolCall)
        }

        guard let eventHandler else { return }

        let argumentsData = try JSONEncoder().encode(toolCall.arguments)
        var argumentsJSON = self.redactedPreview(from: argumentsData)

        // Avoid flooding the UI/logs with huge payloads; cap at 320 chars
        let maxPreviewLength = 320
        if argumentsJSON.count > maxPreviewLength {
            let endIndex = argumentsJSON.index(argumentsJSON.startIndex, offsetBy: maxPreviewLength)
            argumentsJSON = String(argumentsJSON[..<endIndex]) + "…"
        }

        if isFirstOccurrence {
            await eventHandler.send(.toolCallStarted(name: toolCall.name, arguments: argumentsJSON))
        } else {
            await eventHandler.send(.toolCallUpdated(name: toolCall.name, arguments: argumentsJSON))
        }
    }

    /// Redact obviously sensitive fields before previewing tool-call arguments.
    /// - Masks values for keys containing token/secret/key/password/auth.
    /// - Also masks inline patterns like sk-XXXX and Bearer headers.
    private func redactedPreview(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let redacted = self.redactSensitiveValues(object),
            let cleaned = try? JSONSerialization.data(withJSONObject: redacted),
            var text = String(data: cleaned, encoding: .utf8)
        else {
            return self.regexRedact(String(data: data, encoding: .utf8) ?? "{}")
        }

        text = self.regexRedact(text)
        return text
    }

    private func redactSensitiveValues(_ value: Any) -> Any? {
        switch value {
        case let dict as [String: Any]:
            var copy: [String: Any] = [:]
            for (key, v) in dict {
                let lowerKey = key.lowercased()
                let isSensitive = lowerKey.contains("token") ||
                    lowerKey.contains("secret") ||
                    lowerKey.contains("password") ||
                    lowerKey.contains("key") ||
                    lowerKey.contains("auth") ||
                    lowerKey.contains("cookie") ||
                    lowerKey.contains("authorization")
                if isSensitive {
                    copy[key] = "***"
                } else if let redacted = self.redactSensitiveValues(v) {
                    copy[key] = redacted
                }
            }
            return copy
        case let array as [Any]:
            return array.compactMap { self.redactSensitiveValues($0) }
        case let str as String:
            if str.lowercased().contains("bearer ") { return "Bearer ***" }
            if str.lowercased().contains("api_key") { return "***" }
            return str
        default:
            return value
        }
    }

    private func regexRedact(_ text: String) -> String {
        let patterns = [
            "(?i)sk-[a-z0-9_-]{10,}",
            "(?i)bearer\\s+[a-z0-9._-]{8,}",
            "(?i)api[_-]?key\\s*[:=]\\s*[a-z0-9._-]{6,}",
            "(?i)sess[a-z0-9]{12,}",
            "(?i)token\\s*[:=]\\s*[a-z0-9._-]{12,}"
        ]

        var output = text
        for pattern in patterns {
            output = output.replacingOccurrences(of: pattern, with: "***", options: .regularExpression)
        }
        return output
    }

    private func handleReasoningDelta(_ content: String?, eventHandler: EventHandler?) async {
        guard let content, let eventHandler else { return }
        await eventHandler.send(.thinkingMessage(content: content))
    }

    private func handleToolCalls(
        stepText: String,
        toolCalls: [AgentToolCall],
        context: ToolHandlingContext,
        currentMessages: inout [ModelMessage],
        stepIndex: Int) async throws -> GenerationStep
    {
        self.appendAssistantMessage(
            stepText: stepText,
            toolCalls: toolCalls,
            to: &currentMessages)

        var toolResults: [AgentToolResult] = []

        for toolCall in toolCalls {
            guard let tool = context.tool(named: toolCall.name) else { continue }
            let result = await self.executeToolCall(
                toolCall,
                tool: tool,
                context: context,
                currentMessages: &currentMessages,
                stepIndex: stepIndex)
            toolResults.append(result)
        }

        self.logStepCompletion(stepIndex: stepIndex, stepText: stepText, toolCalls: toolCalls)

        return GenerationStep(
            stepIndex: stepIndex,
            text: stepText,
            toolCalls: toolCalls,
            toolResults: toolResults)
    }

    private func appendAssistantMessage(
        stepText: String,
        toolCalls: [AgentToolCall],
        to messages: inout [ModelMessage])
    {
        var content: [ModelMessage.ContentPart] = []
        if !stepText.isEmpty {
            content.append(.text(stepText))
        }
        content.append(contentsOf: toolCalls.map { .toolCall($0) })
        messages.append(ModelMessage(role: .assistant, content: content))
    }

    private func executeToolCall(
        _ toolCall: AgentToolCall,
        tool: AgentTool,
        context: ToolHandlingContext,
        currentMessages: inout [ModelMessage],
        stepIndex: Int) async -> AgentToolResult
    {
        do {
            let executionContext = ToolExecutionContext(
                messages: currentMessages,
                model: context.model,
                settings: self.generationSettings(for: context.model),
                sessionId: context.sessionId,
                stepIndex: stepIndex)
            let toolArguments = AgentToolArguments(toolCall.arguments)
            let result = try await tool.execute(toolArguments, context: executionContext)
            let toolResult = AgentToolResult.success(toolCallId: toolCall.id, result: result)
            await self.sendToolCompletionEvent(
                name: toolCall.name,
                payload: self.toolResultPayload(from: result, toolName: toolCall.name),
                eventHandler: context.eventHandler)
            currentMessages.append(ModelMessage(role: .tool, content: [.toolResult(toolResult)]))
            return toolResult
        } catch {
            let errorResult = AgentToolResult.error(
                toolCallId: toolCall.id,
                error: error.localizedDescription)
            await self.sendToolCompletionEvent(
                name: toolCall.name,
                payload: self.toolErrorPayload(from: error),
                eventHandler: context.eventHandler)
            currentMessages.append(ModelMessage(role: .tool, content: [.toolResult(errorResult)]))
            return errorResult
        }
    }

    private func logStepCompletion(
        stepIndex: Int,
        stepText: String,
        toolCalls: [AgentToolCall])
    {
        guard self.isVerbose else { return }
        self.logger.debug(
            "Step \(stepIndex) completed: collected \(toolCalls.count) tool calls, text length: \(stepText.count)")
    }

    private func sendToolCompletionEvent(
        name: String,
        payload: String,
        eventHandler: EventHandler?) async
    {
        guard let eventHandler else { return }
        await eventHandler.send(.toolCallCompleted(name: name, result: payload))
    }

    private func toolResultPayload(from result: AnyAgentToolValue, toolName: String) -> String {
        do {
            let jsonObject = try result.toJSON()
            var wrapped: [String: Any] = if let dict = jsonObject as? [String: Any] {
                dict
            } else {
                ["result": jsonObject]
            }

            if let summaryText = self.summaryText(from: wrapped, toolName: toolName) {
                wrapped["summary_text"] = summaryText
            }

            let data = try JSONSerialization.data(withJSONObject: wrapped, options: [])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            let fallback = result.stringValue ?? String(describing: result)
            let escapedFallback = fallback.replacingOccurrences(of: "\"", with: "\\\"")
            return "{\"result\": \"\(escapedFallback)\"}"
        }
    }

    private func summaryText(from payload: [String: Any], toolName: String) -> String? {
        guard
            let meta = payload["meta"] as? [String: Any],
            let summaryJSON = meta["summary"] as? [String: Any],
            let summary = ToolEventSummary(json: summaryJSON)
        else {
            return nil
        }
        return summary.shortDescription(toolName: toolName)
    }

    private func toolErrorPayload(from error: any Error) -> String {
        let errorDict = ["error": error.localizedDescription]
        guard let data = try? JSONSerialization.data(withJSONObject: errorDict, options: []),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{\"error\": \"Unknown error\"}"
        }
        return json
    }
}
