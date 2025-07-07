import Foundation
import Observation

@Observable
@MainActor
final class PeekabooAgent {
    var isExecuting = false
    var currentTask: String = ""

    private let settings: Settings
    private let sessionStore: SessionStore
    private let toolExecutor = PeekabooToolExecutor()

    init(settings: Settings, sessionStore: SessionStore) {
        self.settings = settings
        self.sessionStore = sessionStore
    }

    func executeTask(_ task: String, dryRun: Bool = false) async -> AgentResult {
        guard self.settings.hasValidAPIKey else {
            return AgentResult(
                success: false,
                output: "",
                error: "Please configure your OpenAI API key in settings.")
        }

        self.isExecuting = true
        self.currentTask = task
        defer {
            isExecuting = false
            currentTask = ""
        }

        // Create session
        let session = self.sessionStore.createSession(title: task)

        // Add user message
        self.sessionStore.addMessage(
            SessionMessage(role: .user, content: task),
            to: session)

        // Execute with OpenAI
        do {
            let agent = OpenAIAgent(
                apiKey: settings.openAIAPIKey,
                model: self.settings.selectedModel,
                toolExecutor: self.toolExecutor)

            let result = try await agent.executeTask(task, dryRun: dryRun)

            // Add assistant response
            self.sessionStore.addMessage(
                SessionMessage(
                    role: .assistant,
                    content: result.output,
                    toolCalls: [] // TODO: Extract tool calls from execution
                ),
                to: session)

            // Update summary
            if !result.output.isEmpty {
                let summary = String(result.output.prefix(100))
                self.sessionStore.updateSummary(summary, for: session)
            }

            return result
        } catch {
            let errorMessage = "Failed to execute task: \(error.localizedDescription)"

            self.sessionStore.addMessage(
                SessionMessage(role: .system, content: errorMessage),
                to: session)

            return AgentResult(
                success: false,
                output: "",
                error: errorMessage)
        }
    }
}

struct AgentResult {
    let success: Bool
    let output: String
    let error: String?
}
