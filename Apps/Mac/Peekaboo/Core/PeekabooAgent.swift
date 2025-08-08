import Foundation
import PeekabooCore
import SwiftUI
import Tachikoma
import TachikomaAudio

/// Tool execution record for tracking agent actions
struct ToolExecution: Identifiable {
    let toolName: String
    let arguments: String?
    let timestamp: Date
    var status: ToolExecutionStatus
    var result: String?
    var duration: TimeInterval?

    var id: String {
        "tool-\(self.toolName)-\(self.timestamp.timeIntervalSince1970)"
    }
}

/// Tool execution status
enum ToolExecutionStatus {
    case running
    case completed
    case failed
    case cancelled
}

/// Simplified agent interface for the Peekaboo Mac app.
///
/// This class provides a clean interface to the PeekabooCore agent service,
/// handling task execution and real-time event updates.
@Observable
@MainActor
final class PeekabooAgent {
    // MARK: - Properties

    private let services: PeekabooServices
    private let sessionStore: SessionStore
    private let settings: PeekabooSettings

    /// Track current processing state
    @ObservationIgnored
    private var processingTask: Task<Void, Error>?

    /// Current session ID for continuity
    private(set) var currentSessionId: String?

    /// Whether the agent is currently processing
    private(set) var isProcessing = false

    /// Last error message if any
    private(set) var lastError: String?

    /// Current task description being processed
    private(set) var currentTask: String = ""

    /// Current tool being executed
    private(set) var currentTool: String?

    /// Current tool arguments for display
    private(set) var currentToolArgs: String?

    /// Whether agent is thinking (not executing tools)
    private(set) var isThinking = false

    /// Current thinking content
    private(set) var currentThinkingContent: String?

    /// Tool execution history for current task
    private(set) var toolExecutionHistory: [ToolExecution] = []

    /// Task execution start time
    @ObservationIgnored
    private var taskStartTime: Date?

    /// Token usage from last execution
    @ObservationIgnored
    private var lastTokenUsage: Usage?

    /// Get current token usage
    var tokenUsage: Usage? {
        self.lastTokenUsage
    }

    /// Current session
    var currentSession: ConversationSession? {
        self.sessionStore.currentSession
    }

    /// Store the last failed task for retry functionality
    @ObservationIgnored
    private var lastFailedTask: String?

    /// Get the last failed task (for retry button)
    var lastTask: String? {
        self.lastFailedTask
    }

    // MARK: - Initialization

    init(settings: PeekabooSettings, sessionStore: SessionStore) {
        self.services = PeekabooServices.shared
        self.settings = settings
        self.sessionStore = sessionStore
    }

    // MARK: - Public Methods
    
    /// Get the underlying agent service for advanced use cases
    func getAgentService() async throws -> PeekabooAgentService? {
        guard let agentService = self.services.agent else {
            throw AgentError.serviceUnavailable
        }
        return agentService as? PeekabooAgentService
    }

    /// Execute a task with the agent
    func executeTask(_ task: String) async throws {
        guard self.services.agent != nil else {
            throw AgentError.serviceUnavailable
        }

        // Call the common implementation with text content
        try await self.executeTaskWithContent(.text(task))
    }

    /// Execute a task with audio content using Tachikoma Audio API
    func executeTaskWithAudio(
        audioData: Data,
        duration: TimeInterval,
        mimeType: String = "audio/wav",
        transcript: String? = nil) async throws
    {
        // If transcript is already available, use it directly for faster execution
        if let transcript {
            try await self.executeTask(transcript)
            return
        }
        
        // Otherwise, transcribe the audio using Tachikoma and then execute
        do {
            // Create AudioData from the raw data
            let audioFormat: AudioFormat = {
                switch mimeType {
                case "audio/wav": return .wav
                case "audio/mp3": return .mp3
                case "audio/flac": return .flac
                case "audio/opus": return .opus
                case "audio/m4a": return .m4a
                case "audio/aac": return .aac
                case "audio/ogg": return .ogg
                default: return .wav // Default fallback
                }
            }()
            
            let audioDataStruct = AudioData(
                data: audioData,
                format: audioFormat,
                duration: duration
            )
            
            // Transcribe using Tachikoma's OpenAI Whisper integration
            let transcriptionResult = try await transcribe(
                audioDataStruct,
                using: .openai(.whisper1),
                language: "en"
            )
            
            // Execute the task with the transcribed text
            try await self.executeTask(transcriptionResult.text)
            
        } catch {
            throw AgentError.executionFailed("Failed to transcribe audio: \(error.localizedDescription)")
        }
    }

    /// Common implementation for executing tasks with different content types
    private func executeTaskWithContent(_ content: ModelMessage.ContentPart) async throws {
        guard let agentService = services.agent else {
            throw AgentError.serviceUnavailable
        }

        // Create a cancellable task
        let task = Task<Void, Error> {
            try await self.executeTaskInternal(content: content, agentService: agentService)
        }

        // Assign the task and wait for it to complete
        self.processingTask = task
        try await task.value
    }

    /// Internal task execution helper
    @MainActor
    private func executeTaskInternal(
        content: ModelMessage.ContentPart,
        agentService: AgentServiceProtocol) async throws
    {
        self.isProcessing = true

        // Extract task description from content
        let taskDescription: String = switch content {
        case let .text(text):
            text
        case .image:
            "[Image message]"
        case let .toolCall(toolCall):
            "[Tool call: \(toolCall.name)]"
        case let .toolResult(toolResult):
            "[Tool result: \(toolResult.toolCallId)]"
        }

        self.currentTask = taskDescription
        self.lastError = nil
        self.lastFailedTask = nil // Clear on new task execution
        self.isThinking = true
        self.currentTool = nil
        self.currentToolArgs = nil
        self.toolExecutionHistory = [] // Clear history for new task
        self.taskStartTime = Date() // Track start time
        self.lastTokenUsage = nil // Clear previous token usage
        defer {
            self.isProcessing = false
            self.currentTask = ""
            self.processingTask = nil
        }

        do {
            // Check for cancellation
            try Task.checkCancellation()

            // Use PeekabooAgentService for enhanced functionality
            guard let peekabooAgent = agentService as? PeekabooAgentService else {
                throw AgentError.invalidConfiguration("Agent service not properly initialized")
            }

            // Create or get session BEFORE task execution
            if self.sessionStore.currentSession == nil {
                let newSession = self.sessionStore.createSession(title: "", modelName: self.settings.selectedModel)
                self.currentSessionId = newSession.id
            } else {
                // Ensure currentSessionId matches the current session
                self.currentSessionId = self.sessionStore.currentSession?.id
            }

            // Add user message at the very beginning
            if let currentSession = sessionStore.currentSession {
                // Create user message with appropriate content
                let userMessage = switch content {
                case let .text(text):
                    PeekabooCore.ConversationMessage(role: .user, content: text)
                case .image:
                    PeekabooCore.ConversationMessage(role: .user, content: "[Image message]")
                case let .toolCall(toolCall):
                    PeekabooCore.ConversationMessage(role: .user, content: "[Tool call: \(toolCall.name)]")
                case let .toolResult(toolResult):
                    PeekabooCore.ConversationMessage(role: .user, content: "[Tool result: \(toolResult.toolCallId)]")
                }

                self.sessionStore.addMessage(userMessage, to: currentSession)

                // Generate title for new sessions
                if currentSession.title == "New Session" || currentSession.title.isEmpty {
                    self.sessionStore.generateTitleForSession(currentSession)
                }
            }

            // Create event delegate for real-time updates
            let eventDelegate = AgentEventDelegateWrapper { [weak self] event in
                guard let self else { return }

                Task { @MainActor in
                    self.handleAgentEvent(event)
                }
            }

            // Call the appropriate method based on content type
            let result: AgentExecutionResult = switch content {
            case let .text(text):
                try await peekabooAgent.executeTask(
                    text,
                    sessionId: self.currentSessionId,
                    model: nil,
                    eventDelegate: eventDelegate)
            case .image, .toolCall, .toolResult:
                // For now, use text representation
                try await peekabooAgent.executeTask(
                    taskDescription,
                    sessionId: self.currentSessionId,
                    model: nil,
                    eventDelegate: eventDelegate)
            }

            // Check for cancellation after execution
            try Task.checkCancellation()

            // Update session ID for continuity
            self.currentSessionId = result.sessionId

            // Update model name if not set
            if self.sessionStore.currentSession?.modelName.isEmpty == true {
                if let currentSession = sessionStore.currentSession,
                   let index = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id })
                {
                    self.sessionStore.sessions[index].modelName = self.settings.selectedModel
                    Task { @MainActor in
                        self.sessionStore.saveSessions()
                    }
                }
            }

            // Add assistant response to current session (if not already added during streaming)
            if let currentSession = sessionStore.currentSession {
                // Check if we already have this assistant message from streaming
                let hasAssistantMessage = self.sessionStore.sessions
                    .first(where: { $0.id == currentSession.id })?
                    .messages
                    .contains(where: {
                        $0.role == .assistant &&
                            $0.content == result.content
                    }) ?? false

                if !hasAssistantMessage {
                    // Add assistant message WITHOUT tool calls (they're tracked separately)
                    let assistantMessage = ConversationMessage(
                        role: .assistant,
                        content: result.content,
                        toolCalls: [] // Tool calls are now separate system messages
                    )
                    self.sessionStore.addMessage(assistantMessage, to: currentSession)
                }

                // Add execution summary with timing and token usage
                if let startTime = taskStartTime {
                    let totalDuration = Date().timeIntervalSince(startTime)
                    let durationText = formatDuration(totalDuration)

                    // Count total tool calls
                    let toolCount = self.toolExecutionHistory.count

                    var summaryContent = "Task completed in \(durationText)"
                    if toolCount > 0 {
                        summaryContent += " with \(toolCount) tool call\(toolCount == 1 ? "" : "s")"
                    }

                    // Add token usage if available
                    if let usage = lastTokenUsage {
                        summaryContent += " • 🤖 \(usage.totalTokens) tokens"
                        if usage.inputTokens > 0, usage.outputTokens > 0 {
                            summaryContent += " (\(usage.inputTokens) in, \(usage.outputTokens) out)"
                        }
                    }

                    let summaryMessage = PeekabooCore.ConversationMessage(
                        role: .system,
                        content: summaryContent)
                    self.sessionStore.addMessage(summaryMessage, to: currentSession)
                }

                // Update summary if needed
                if !result.content.isEmpty {
                    self.sessionStore.updateSummary(result.content, for: currentSession)
                }
            }

        } catch {
            if error is CancellationError {
                // Handle cancellation
                self.lastError = "Task was cancelled"

                // Add cancellation message to session
                if let currentSession = sessionStore.currentSession {
                    let cancelMessage = PeekabooCore.ConversationMessage(
                        role: .system,
                        content: "⚠️ Task was cancelled by user")
                    self.sessionStore.addMessage(cancelMessage, to: currentSession)
                }
            } else {
                self.lastError = error.localizedDescription
                self.lastFailedTask = taskDescription // Store the failed task for retry

                // Add error message to session
                if let currentSession = sessionStore.currentSession {
                    let errorMessage = PeekabooCore.ConversationMessage(
                        role: .system,
                        content: "❌ Error: \(error.localizedDescription)")
                    self.sessionStore.addMessage(errorMessage, to: currentSession)
                }
            }
            throw error
        }
    }

    /// Resume a previous session
    func resumeSession(_ sessionId: String, withTask task: String) async throws {
        self.currentSessionId = sessionId
        try await self.executeTask(task)
    }

    /// List available sessions
    func listSessions() async throws -> [ConversationSessionSummary] {
        // Return summaries from the session store
        self.sessionStore.sessions.map { ConversationSessionSummary(from: $0) }
    }

    /// Clear current session
    func clearSession() {
        self.currentSessionId = nil
        self.lastError = nil
    }

    /// Check if agent is available
    var isAvailable: Bool {
        self.services.agent != nil
    }

    /// Cancel the current task
    func cancelCurrentTask() {
        self.processingTask?.cancel()
        // Don't add a message here - it will be added when the cancellation is actually handled
    }

    // MARK: - Private Methods

    private func handleAgentEvent(_ event: PeekabooCore.AgentEvent) {
        switch event {
        case let .error(message):
            self.lastError = message

            // Mark any running tools as failed
            if let currentTool,
               let index = toolExecutionHistory
                   .lastIndex(where: { $0.toolName == currentTool && $0.status == .running })
            {
                self.toolExecutionHistory[index].status = .failed
                self.toolExecutionHistory[index].result = message
            }

        case let .assistantMessage(delta):
            // Add assistant's message to session as it streams
            // Note: 'delta' contains only the incremental text chunk, not the full content
            self.isThinking = false
            self.currentTool = nil
            self.currentToolArgs = nil

            // Add or update the assistant message in the session
            if let currentSession = sessionStore.currentSession {
                // Check if we have a recent assistant message we're building
                if let sessionIndex = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id }),
                   sessionIndex < sessionStore.sessions.count,
                   let lastMessage = sessionStore.sessions[sessionIndex].messages.last,
                   lastMessage.role == .assistant,
                   lastMessage.timestamp.timeIntervalSinceNow > -5.0
                { // Within last 5 seconds
                    // Append delta to existing message content
                    let accumulatedContent = lastMessage.content + delta
                    self.sessionStore.sessions[sessionIndex]
                        .messages[self.sessionStore.sessions[sessionIndex].messages.count - 1] = ConversationMessage(
                            id: lastMessage.id,
                            role: .assistant,
                            content: accumulatedContent,
                            timestamp: lastMessage.timestamp,
                            toolCalls: lastMessage.toolCalls)
                } else if !delta.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    // Create new assistant message with the first delta
                    let assistantMessage = PeekabooCore.ConversationMessage(
                        role: .assistant,
                        content: delta)
                    self.sessionStore.addMessage(assistantMessage, to: currentSession)
                }
            }

        case let .thinkingMessage(content):
            // Add thinking/planning message to session
            if !content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                self.isThinking = true
                self.currentThinkingContent = content
                self.currentTool = nil
                self.currentToolArgs = nil

                if let currentSession = sessionStore.currentSession {
                    let thinkingMessage = PeekabooCore.ConversationMessage(
                        role: .system,
                        content: "🤔 \(content)")
                    self.sessionStore.addMessage(thinkingMessage, to: currentSession)
                }
            }

        case let .toolCallStarted(name, arguments):
            self.isThinking = false
            self.currentThinkingContent = nil
            self.currentTool = name
            self.currentToolArgs = arguments

            // Use formatter bridge to create formatted message
            let formattedMessage = ToolFormatterBridge.shared.formatToolCall(
                name: name,
                arguments: arguments,
                result: nil
            )
            
            // Store formatted args for display
            self.currentToolArgs = ToolFormatterBridge.shared.formatArguments(
                name: name,
                arguments: arguments
            )

            // Add tool execution message to session
            if let currentSession = sessionStore.currentSession {
                let toolMessage = ConversationMessage(
                    role: .system,
                    content: formattedMessage,
                    toolCalls: [ConversationToolCall(name: name, arguments: arguments, result: "Running...")])
                self.sessionStore.addMessage(toolMessage, to: currentSession)
            }

            // Add to tool execution history
            let execution = ToolExecution(
                toolName: name,
                arguments: currentToolArgs ?? arguments,
                timestamp: Date(),
                status: .running)
            self.toolExecutionHistory.append(execution)

        case let .toolCallCompleted(name, result):
            // Find and update the tool execution message
            if let currentSession = sessionStore.currentSession,
               let sessionIndex = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id })
            {
                // Find the most recent tool message for this tool
                if let toolMessageIndex = sessionStore.sessions[sessionIndex].messages.lastIndex(where: { message in
                    message.role == .system &&
                        message.toolCalls.contains { $0.name == name && $0.result == "Running..." }
                }) {
                    // Update the tool call result
                    if let toolCallIndex = sessionStore.sessions[sessionIndex].messages[toolMessageIndex].toolCalls
                        .firstIndex(where: { $0.name == name })
                    {
                        self.sessionStore.sessions[sessionIndex].messages[toolMessageIndex].toolCalls[toolCallIndex]
                            .result = result
                        Task { @MainActor in
                            self.sessionStore.saveSessions()
                        }
                    }
                }
            }

            // Update tool execution history with duration
            if let index = toolExecutionHistory.lastIndex(where: { $0.toolName == name && $0.status == .running }) {
                let startTime = self.toolExecutionHistory[index].timestamp
                let duration = Date().timeIntervalSince(startTime)
                self.toolExecutionHistory[index].status = .completed
                self.toolExecutionHistory[index].result = result
                self.toolExecutionHistory[index].duration = duration

                // Add timing info as a separate update
                if let currentSession = sessionStore.currentSession {
                    let durationText = String(format: "%.2fs", duration)

                    // Find the tool message and create an updated version
                    if let sessionIndex = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id }),
                       let toolMessageIndex = sessionStore.sessions[sessionIndex].messages.lastIndex(where: { message in
                           message.role == .system &&
                               message.content.contains("🔧 \(name):")
                       })
                    {
                        let originalMessage = self.sessionStore.sessions[sessionIndex].messages[toolMessageIndex]
                        let updatedContent = originalMessage.content + " ⏱ \(durationText)"

                        // Create a new message with updated content
                        let updatedMessage = ConversationMessage(
                            role: originalMessage.role,
                            content: updatedContent,
                            toolCalls: originalMessage.toolCalls)

                        // Replace the message
                        self.sessionStore.sessions[sessionIndex].messages[toolMessageIndex] = updatedMessage
                    }
                }
            }

            self.currentTool = nil
            self.currentToolArgs = nil
            self.isThinking = true

        case let .completed(_, usage):
            // Store token usage for the final summary
            self.lastTokenUsage = usage

        default:
            break
        }
    }

    // MARK: - Tool Display Helpers

    /// Get icon for tool name (delegates to formatter bridge)
    static func iconForTool(_ toolName: String) -> String {
        ToolFormatterBridge.shared.toolIcon(for: toolName)
    }

    // compactToolSummary method removed - now using ToolFormatterBridge
}

// MARK: - Agent Errors

public enum AgentError: LocalizedError {
    case serviceUnavailable
    case invalidConfiguration(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "Agent service is not available. Please check your OpenAI API key."
        case let .invalidConfiguration(message):
            "Invalid configuration: \(message)"
        case let .executionFailed(message):
            "Execution failed: \(message)"
        }
    }
}

// MARK: - Agent Event Delegate Wrapper

private final class AgentEventDelegateWrapper: PeekabooCore.AgentEventDelegate {
    private let handler: (PeekabooCore.AgentEvent) -> Void

    init(handler: @escaping (PeekabooCore.AgentEvent) -> Void) {
        self.handler = handler
    }

    func agentDidEmitEvent(_ event: PeekabooCore.AgentEvent) {
        self.handler(event)
    }
}
