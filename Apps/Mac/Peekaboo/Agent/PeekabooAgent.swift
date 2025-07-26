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
    private var currentTask: Task<Void, Never>?
    
    /// Current session ID for continuity
    public private(set) var currentSessionId: String?
    
    /// Whether the agent is currently processing
    public private(set) var isProcessing = false
    
    /// Last error message if any
    public private(set) var lastError: String?
    
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
        
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }
        
        do {
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
            lastError = error.localizedDescription
            throw error
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
    
    // MARK: - Private Methods
    
    private func handleAgentEvent(_ event: AgentEvent) {
        switch event {
        case .error(let message):
            lastError = message
            
        case .assistantMessage(let content):
            // Could emit to UI if needed
            print("Assistant: \(content)")
            
        case .toolCallStarted(let name, let arguments):
            print("Tool started: \(name)")
            
        case .toolCallCompleted(let name, let result):
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