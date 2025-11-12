//
//  PeekabooAgentService+Sessions.swift
//  PeekabooCore
//

import Foundation
import Tachikoma

@available(macOS 14.0, *)
extension PeekabooAgentService {
    struct SessionContext {
        let id: String
        let messages: [ModelMessage]
        let startTime: Date
    }

    enum SessionLogBehavior {
        case always
        case verboseOnly
    }

    func prepareSession(
        task: String,
        model: LanguageModel,
        label: String,
        logBehavior: SessionLogBehavior) async throws -> SessionContext
    {
        self.currentModel = model
        let startTime = Date()
        let sessionId = UUID().uuidString
        let messages = [
            ModelMessage.system(AgentSystemPrompt.generate(for: model)),
            ModelMessage.user(task),
        ]

        let session = AgentSession(
            id: sessionId,
            modelName: model.description,
            messages: messages,
            metadata: SessionMetadata(),
            createdAt: startTime,
            updatedAt: startTime)

        let forceLogging = logBehavior == .always
        self.logSession("\(label): Creating session with ID: \(sessionId)", force: forceLogging)
        self.logSession("\(label): Session messages count: \(messages.count)", force: forceLogging)

        do {
            try self.sessionManager.saveSession(session)
            self.logSession("\(label): Successfully saved initial session", force: forceLogging)
        } catch {
            print("ERROR (\(label)): Failed to save initial session: \(error)")
            throw error
        }

        return SessionContext(id: sessionId, messages: messages, startTime: startTime)
    }

    func saveCompletedSession(
        context: SessionContext,
        model: LanguageModel,
        finalMessages: [ModelMessage],
        endTime: Date,
        toolCallCount: Int) throws
    {
        let executionTime = endTime.timeIntervalSince(context.startTime)
        let updatedSession = AgentSession(
            id: context.id,
            modelName: model.description,
            messages: finalMessages,
            metadata: SessionMetadata(
                toolCallCount: toolCallCount,
                totalExecutionTime: executionTime,
                customData: ["status": "completed"]),
            createdAt: context.startTime,
            updatedAt: endTime)
        try self.sessionManager.saveSession(updatedSession)
    }

    func makeExecutionMetadata(
        model: LanguageModel,
        executionTime: TimeInterval,
        toolCallCount: Int,
        startTime: Date,
        endTime: Date) -> AgentMetadata
    {
        AgentMetadata(
            executionTime: executionTime,
            toolCallCount: toolCallCount,
            modelName: model.description,
            startTime: startTime,
            endTime: endTime)
    }

    func logModelUsage(_ model: LanguageModel, prefix: String) {
        guard self.isVerbose else { return }
        self.logger.debug("\(prefix)Using model: \(model)")
        self.logger.debug("\(prefix)Model description: \(model.description)")
    }

    private func logSession(_ message: String, force: Bool) {
        if force || self.isVerbose {
            self.logger.debug("\(message, privacy: .public)")
        }
    }
}
