//
//  PeekabooAgentService+StreamProcessing.swift
//  PeekabooCore
//

import Foundation
import Tachikoma

@available(macOS 14.0, *)
extension PeekabooAgentService {
    struct StreamProcessingOutput {
        let text: String
        let toolCalls: [AgentToolCall]
        let usage: Usage?
        let reasoningBlocks: [ReasoningBlock]
    }

    struct ReasoningBlock {
        var text: String
        let signature: String
        let type: String
    }

    func collectStreamOutput(
        from streamResult: StreamTextResult,
        eventHandler: EventHandler?,
        stepIndex: Int) async throws -> StreamProcessingOutput
    {
        var stepText = ""
        var reasoningBlocks: [ReasoningBlock] = []
        var activeReasoningIndex: Int?
        var pendingReasoningText = ""
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
                if let signature = delta.reasoningSignature {
                    reasoningBlocks.append(ReasoningBlock(
                        text: pendingReasoningText,
                        signature: signature,
                        type: delta.reasoningType ?? "thinking"))
                    activeReasoningIndex = reasoningBlocks.count - 1
                    pendingReasoningText = ""
                }

                if let content = delta.content {
                    if let activeReasoningIndex {
                        reasoningBlocks[activeReasoningIndex].text += content
                    } else {
                        pendingReasoningText += content
                    }
                }

                let displayContent = delta.content.flatMap { $0.isEmpty ? nil : $0 }
                await self.handleReasoningDelta(displayContent, eventHandler: eventHandler)

            case .done:
                usage = delta.usage

            default:
                break
            }
        }

        return StreamProcessingOutput(
            text: stepText,
            toolCalls: stepToolCalls,
            usage: usage,
            reasoningBlocks: reasoningBlocks)
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

        // Keep the latest version of this tool call so downstream handlers see current args.
        if let existingIndex = stepToolCalls.firstIndex(where: { $0.id == toolCall.id }) {
            stepToolCalls[existingIndex] = toolCall
        } else {
            stepToolCalls.append(toolCall)
        }

        guard let eventHandler else { return }

        let argumentsData = try JSONEncoder().encode(toolCall.arguments)
        let argumentsJSON = AgentToolCallArgumentPreview.redacted(from: argumentsData)

        if isFirstOccurrence {
            await eventHandler.send(.toolCallStarted(name: toolCall.name, arguments: argumentsJSON))
        } else {
            await eventHandler.send(.toolCallUpdated(name: toolCall.name, arguments: argumentsJSON))
        }
    }

    private func handleReasoningDelta(_ content: String?, eventHandler: EventHandler?) async {
        guard let content, let eventHandler else { return }
        await eventHandler.send(.thinkingMessage(content: content))
    }
}
