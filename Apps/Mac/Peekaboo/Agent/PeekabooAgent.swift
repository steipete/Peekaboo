import Foundation
import Observation
import PeekabooCore

/// An AI-powered automation agent that orchestrates task execution using OpenAI's function calling.
///
/// `PeekabooAgent` serves as the brain of Peekaboo's automation capabilities, interpreting natural language
/// commands and executing them through a collection of specialized tools. It manages sessions, tracks
/// execution state, and provides real-time event updates through the ``AgentEventDelegate`` protocol.
///
/// ## Overview
///
/// The agent uses OpenAI's GPT models with function calling to:
/// - Interpret user intentions from natural language prompts
/// - Select appropriate tools for task execution
/// - Chain multiple operations to complete complex workflows
/// - Provide real-time feedback on execution progress
///
/// ## Topics
///
/// ### Creating an Agent
///
/// - ``init(settings:sessionStore:)``
///
/// ### Executing Tasks
///
/// - ``executeTask(_:dryRun:)``
/// - ``isExecuting``
/// - ``currentTask``
/// - ``currentSession``
///
/// ### Event Handling
///
/// The agent conforms to ``AgentEventDelegate`` to receive streaming updates during execution.
@Observable
@MainActor
final class PeekabooAgent: AgentEventDelegate {
    var isExecuting = false
    var currentTask: String = ""
    var currentSession: Session?

    private let settings: PeekabooSettings
    private let sessionStore: SessionStore
    private let toolExecutor = PeekabooToolExecutor()
    private var currentExecutionTask: Task<AgentResult, Never>?
    
    // Message queue for follow-up messages
    private var messageQueue: [String] = []
    private var isProcessingQueue = false

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
            currentExecutionTask = nil
            
            // Process any queued messages after this task completes
            if !messageQueue.isEmpty && !isProcessingQueue {
                Task {
                    await processMessageQueue()
                }
            }
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
            // Log API key info for debugging (first 7 chars only for security)
            let keyPreview = settings.openAIAPIKey.prefix(7) + "..." + settings.openAIAPIKey.suffix(4)
            print("[PeekabooAgent] Using API key: \(keyPreview) with model: \(settings.selectedModel)")
            
            let agent = OpenAIAgent(
                apiKey: settings.openAIAPIKey,
                model: self.settings.selectedModel,
                toolExecutor: self.toolExecutor,
                eventDelegate: self)

            let coreResult = try await agent.executeTask(task, dryRun: dryRun)
            
            // Convert from PeekabooCore.AgentResult to local AgentResult
            let result = AgentResult(from: coreResult)

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
    
    func cancelCurrentTask() {
        guard isExecuting else { return }
        
        // Cancel the current execution task
        currentExecutionTask?.cancel()
        
        // Add cancellation message to session
        if let session = currentSession {
            sessionStore.addMessage(
                SessionMessage(role: .system, content: "⚠️ Task cancelled by user"),
                to: session)
        }
        
        // Reset state
        isExecuting = false
        currentTask = ""
        currentSession = nil
        currentExecutionTask = nil
        
        // Clear the queue as well
        messageQueue.removeAll()
        isProcessingQueue = false
    }
    
    /// Queue a message to be executed after the current task completes
    func queueMessage(_ message: String) {
        messageQueue.append(message)
        
        // If we're not currently executing, process the queue immediately
        if !isExecuting && !isProcessingQueue {
            Task {
                await processMessageQueue()
            }
        }
    }
    
    /// Process queued messages one by one
    private func processMessageQueue() async {
        guard !isProcessingQueue, !messageQueue.isEmpty else { return }
        
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        while !messageQueue.isEmpty && !Task.isCancelled {
            let message = messageQueue.removeFirst()
            _ = await executeTask(message)
            
            // Small delay between messages to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    // MARK: - AgentEventDelegate
    
    nonisolated func agentDidEmitEvent(_ event: AgentEvent) {
        Task { @MainActor in
            guard let session = self.currentSession else { return }
            
            switch event {
            case .started(_):
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
                
            case .completed(_):
                // Final summary already handled in executeTask
                break
            }
        }
    }
}

// Adapter for PeekabooCore.AgentResult to match Mac app expectations
struct AgentResult {
    let success: Bool
    let output: String
    let error: String?
    
    init(success: Bool, output: String, error: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
    }
    
    // Convert from PeekabooCore.AgentResult
    init(from coreResult: PeekabooCore.AgentResult) {
        self.success = coreResult.success
        self.output = coreResult.summary ?? coreResult.steps.map { $0.description }.joined(separator: "\n")
        self.error = coreResult.success ? nil : "Task failed"
    }
}
