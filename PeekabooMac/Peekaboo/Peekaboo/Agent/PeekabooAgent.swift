import Foundation
import Observation

@Observable
@MainActor
final class PeekabooAgent: AgentEventDelegate {
    var isExecuting = false
    var currentTask: String = ""
    var currentSession: Session?

    private let settings: PeekabooSettings
    private let sessionStore: SessionStore
    private let toolExecutor = PeekabooToolExecutor()

    init(settings: PeekabooSettings, sessionStore: SessionStore) {
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
        self.currentSession = session

        // Add user message
        self.sessionStore.addMessage(
            SessionMessage(role: .user, content: task),
            to: session)

        // Execute with OpenAI
        defer {
            self.currentSession = nil
        }
        
        do {
            let agent = OpenAIAgent(
                apiKey: settings.openAIAPIKey,
                model: self.settings.selectedModel,
                toolExecutor: self.toolExecutor,
                eventDelegate: self)

            let result = try await agent.executeTask(task, dryRun: dryRun)

            // Final message and summary will be handled by event delegate
            // Update summary from result
            if !result.output.isEmpty {
                let shortSummary = String(result.output.prefix(100))
                self.sessionStore.updateSummary(shortSummary, for: session)
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
    
    // MARK: - AgentEventDelegate
    
    nonisolated func agentDidEmitEvent(_ event: AgentEvent) {
        Task { @MainActor in
            guard let session = self.currentSession else { return }
            
            switch event {
            case .started:
                // Already handled when creating session
                break
                
            case .thinking(let message):
                self.sessionStore.addMessage(
                    SessionMessage(role: .system, content: "🤔 \(message)"),
                    to: session)
                
            case .toolCallStarted(let name, let arguments):
                // Create a temporary message showing tool is running
                let toolMessage = SessionMessage(
                    role: .assistant,
                    content: "Running tool: \(name)",
                    toolCalls: [ToolCall(name: name, arguments: arguments, result: "Running...")])
                self.sessionStore.addMessage(toolMessage, to: session)
                
            case .toolCallCompleted(let name, let result):
                // Update the last message with the tool result
                if let lastMessage = session.messages.last,
                   lastMessage.role == .assistant,
                   let toolCallIndex = lastMessage.toolCalls.firstIndex(where: { $0.name == name }) {
                    var updatedMessage = lastMessage
                    updatedMessage.toolCalls[toolCallIndex].result = result
                    self.sessionStore.updateLastMessage(updatedMessage, in: session)
                }
                
            case .assistantMessage(let content):
                self.sessionStore.addMessage(
                    SessionMessage(role: .assistant, content: content),
                    to: session)
                
            case .error(let message):
                self.sessionStore.addMessage(
                    SessionMessage(role: .system, content: "❌ Error: \(message)"),
                    to: session)
                
            case .completed:
                // Final summary already handled in executeTask
                break
            }
        }
    }
}

struct AgentResult {
    let success: Bool
    let output: String
    let error: String?
}
