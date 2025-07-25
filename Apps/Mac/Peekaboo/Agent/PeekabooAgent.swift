import Foundation
import SwiftUI
import PeekabooCore
import Observation

/// Main agent class for the Peekaboo Mac app
@Observable
@MainActor
public final class PeekabooAgent {
    // MARK: - Properties
    
    private let services: PeekabooServices
    private let sessionStore: SessionStore
    private let settings: PeekabooSettings
    
    /// Current agent service if available
    private var agentService: AgentServiceProtocol? {
        services.agent
    }
    
    /// Track current processing state
    @ObservationIgnored
    private var processingTask: Task<Void, Error>?
    
    /// Current session ID for continuity
    public private(set) var currentSessionId: String?
    
    /// Whether the agent is currently processing
    public private(set) var isProcessing = false
    
    /// Last error message if any
    public private(set) var lastError: String?
    
    /// Current task description being processed
    public private(set) var currentTask: String = ""
    
    /// Current session
    public var currentSession: Session? {
        sessionStore.currentSession
    }
    
    /// Queue of messages to process after current task
    @ObservationIgnored
    private var messageQueue: [String] = []
    
    /// Flag to track if cancellation was requested
    @ObservationIgnored
    private var isCancellationRequested = false
    
    /// Last failed task for retry purposes
    @ObservationIgnored
    private var lastFailedTask: String?
    
    /// Maximum retry attempts
    private let maxRetryAttempts = 3
    
    /// Current retry attempt
    @ObservationIgnored
    private var currentRetryAttempt = 0
    
    // MARK: - Initialization
    
    init(settings: PeekabooSettings, sessionStore: SessionStore) {
        self.services = PeekabooServices.shared
        self.settings = settings
        self.sessionStore = sessionStore
    }
    
    // MARK: - Public Methods
    
    /// Execute a task with the agent
    public func executeTask(_ task: String) async throws {
        guard let agentService = agentService else {
            throw AgentError.serviceUnavailable
        }
        
        // Reset cancellation flag
        isCancellationRequested = false
        
        // Create a cancellable task
        processingTask = Task { @MainActor in
            isProcessing = true
            currentTask = task
            lastError = nil
            defer { 
                isProcessing = false
                currentTask = ""
                processingTask = nil
                
                // Process any queued messages after completion
                Task { @MainActor in
                    await processQueuedMessages()
                }
            }
            
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                // Use PeekabooAgentService for enhanced functionality
                guard let peekabooAgent = agentService as? PeekabooAgentService else {
                    throw AgentError.invalidConfiguration("Agent service not properly initialized")
                }
                
                // Create event delegate for real-time updates
                let eventDelegate = AgentEventDelegateWrapper { [weak self] event in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        self.handleAgentEvent(event)
                    }
                }
                
                let result = try await peekabooAgent.executeTask(
                    task,
                    sessionId: currentSessionId,
                    modelName: settings.selectedModel,
                    eventDelegate: eventDelegate
                )
                
                // Check for cancellation after execution
                try Task.checkCancellation()
                
                // Update session ID for continuity
                currentSessionId = result.sessionId
                
                // Create or update session in store
                if sessionStore.currentSession == nil {
                    _ = sessionStore.createSession(title: task)
                }
                
                // Add messages to current session
                if let currentSession = sessionStore.currentSession {
                    // Add user message
                    let userMessage = SessionMessage(role: .user, content: task)
                    sessionStore.addMessage(userMessage, to: currentSession)
                    
                    // Add assistant message with tool calls
                    let toolCalls = result.toolCalls.map { call in
                        ToolCall(
                            name: call.function.name,
                            arguments: call.function.arguments
                        )
                    }
                    
                    let assistantMessage = SessionMessage(
                        role: .assistant, 
                        content: result.content,
                        toolCalls: toolCalls
                    )
                    sessionStore.addMessage(assistantMessage, to: currentSession)
                    
                    // Update summary if needed
                    if !result.content.isEmpty {
                        sessionStore.updateSummary(result.content, for: currentSession)
                    }
                }
                
            } catch {
                if error is CancellationError {
                    // Handle cancellation
                    lastError = "Task was cancelled"
                    
                    // Add cancellation message to session
                    if let currentSession = sessionStore.currentSession {
                        let cancelMessage = SessionMessage(
                            role: .system,
                            content: "⚠️ Task was cancelled by user"
                        )
                        sessionStore.addMessage(cancelMessage, to: currentSession)
                    }
                } else {
                    lastError = error.localizedDescription
                    lastFailedTask = task
                    
                    // Check if we should retry
                    let shouldRetry = shouldRetryError(error) && currentRetryAttempt < maxRetryAttempts
                    
                    // Add error message to session
                    if let currentSession = sessionStore.currentSession {
                        var errorContent = "❌ Error: \(error.localizedDescription)"
                        if shouldRetry {
                            errorContent += "\n🔄 Retrying... (Attempt \(currentRetryAttempt + 1)/\(maxRetryAttempts))"
                        }
                        
                        let errorMessage = SessionMessage(
                            role: .system,
                            content: errorContent
                        )
                        sessionStore.addMessage(errorMessage, to: currentSession)
                    }
                    
                    // If we should retry, don't throw the error yet
                    if shouldRetry {
                        // Store the error for potential retry
                        return
                    }
                }
                throw error
            }
        }
        
        // Wait for the task to complete
        do {
            try await processingTask?.value
            
            // Reset retry count on success
            currentRetryAttempt = 0
            lastFailedTask = nil
        } catch {
            // Check if we should retry
            if shouldRetryError(error) && currentRetryAttempt < maxRetryAttempts {
                currentRetryAttempt += 1
                
                // Wait a bit before retrying
                try await Task.sleep(nanoseconds: UInt64(currentRetryAttempt) * 1_000_000_000) // Exponential backoff
                
                // Retry the task
                try await executeTask(task)
            } else {
                // Reset retry count and rethrow
                currentRetryAttempt = 0
                throw error
            }
        }
    }
    
    /// Resume a previous session
    public func resumeSession(_ sessionId: String, withTask task: String) async throws {
        currentSessionId = sessionId
        try await executeTask(task)
    }
    
    /// List available sessions
    public func listSessions() async throws -> [SessionSummary] {
        guard let agentService = agentService else {
            throw AgentError.serviceUnavailable
        }
        
        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw AgentError.invalidConfiguration("Agent service not properly initialized")
        }
        
        return try await peekabooAgent.listSessions()
    }
    
    /// Clear current session
    public func clearSession() {
        currentSessionId = nil
        lastError = nil
    }
    
    /// Check if agent is available
    public var isAvailable: Bool {
        agentService != nil
    }
    
    /// Cancel the current task
    public func cancelCurrentTask() {
        isCancellationRequested = true
        processingTask?.cancel()
        
        // Add cancellation notification to UI
        if let currentSession = sessionStore.currentSession {
            let cancelMessage = SessionMessage(
                role: .system,
                content: "⚠️ Cancelling current task..."
            )
            sessionStore.addMessage(cancelMessage, to: currentSession)
        }
    }
    
    /// Queue a message for processing after current task completes
    public func queueMessage(_ message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        messageQueue.append(message)
        
        // Add queue notification to session
        if let currentSession = sessionStore.currentSession {
            let queuedMessage = SessionMessage(
                role: .system,
                content: "📋 Message queued. It will be processed after the current task completes."
            )
            sessionStore.addMessage(queuedMessage, to: currentSession)
        }
    }
    
    /// Retry the last failed task
    public func retryLastFailedTask() async throws {
        guard let task = lastFailedTask else {
            throw AgentError.executionFailed("No failed task to retry")
        }
        
        // Reset retry count for manual retry
        currentRetryAttempt = 0
        
        // Add retry message to session
        if let currentSession = sessionStore.currentSession {
            let retryMessage = SessionMessage(
                role: .system,
                content: "🔄 Retrying last failed task..."
            )
            sessionStore.addMessage(retryMessage, to: currentSession)
        }
        
        try await executeTask(task)
    }
    
    /// Check if the last task can be retried
    public var canRetryLastTask: Bool {
        lastFailedTask != nil && !isProcessing
    }
    
    // MARK: - Private Methods
    
    /// Determine if an error should be retried
    private func shouldRetryError(_ error: Error) -> Bool {
        // Don't retry cancellations
        if error is CancellationError {
            return false
        }
        
        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            default:
                return false
            }
        }
        
        // Check for specific error messages
        let errorMessage = error.localizedDescription.lowercased()
        if errorMessage.contains("network") || 
           errorMessage.contains("timeout") ||
           errorMessage.contains("connection") {
            return true
        }
        
        // Don't retry other errors by default
        return false
    }
    
    /// Process any queued messages
    private func processQueuedMessages() async {
        // Only process if not currently processing and there are messages
        guard !isProcessing, !messageQueue.isEmpty else { return }
        
        // Get and clear the first message from the queue
        let nextMessage = messageQueue.removeFirst()
        
        // Execute the queued message
        Task { @MainActor in
            do {
                try await executeTask(nextMessage)
            } catch {
                print("Failed to process queued message: \(error)")
            }
        }
    }
    
    private func handleAgentEvent(_ event: AgentEvent) {
        switch event {
        case .error(let message):
            lastError = message
            
        case .assistantMessage(let content):
            // Could emit to UI if needed
            print("Assistant: \(content)")
            
        case .toolCallStarted(let name, _):
            print("Tool started: \(name)")
            
        case .toolCallCompleted(let name, _):
            print("Tool completed: \(name)")
            
        default:
            break
        }
    }
}

// MARK: - Agent Errors

public enum AgentError: LocalizedError {
    case serviceUnavailable
    case invalidConfiguration(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Agent service is not available. Please check your OpenAI API key."
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}

// MARK: - Agent Event Delegate Wrapper

private final class AgentEventDelegateWrapper: PeekabooCore.AgentEventDelegate {
    private let handler: (AgentEvent) -> Void
    
    init(handler: @escaping (AgentEvent) -> Void) {
        self.handler = handler
    }
    
    func agentDidEmitEvent(_ event: AgentEvent) {
        handler(event)
    }
}