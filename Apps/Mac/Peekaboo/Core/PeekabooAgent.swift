import Foundation
import SwiftUI
import PeekabooCore

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
    public private(set) var currentSessionId: String?
    
    /// Whether the agent is currently processing
    public private(set) var isProcessing = false
    
    /// Last error message if any
    public private(set) var lastError: String?
    
    /// Current task description being processed
    public private(set) var currentTask: String = ""
    
    /// Current tool being executed
    public private(set) var currentTool: String?
    
    /// Current tool arguments for display
    public private(set) var currentToolArgs: String?
    
    /// Whether agent is thinking (not executing tools)
    public private(set) var isThinking = false
    
    /// Tool execution history for current task
    public private(set) var toolExecutionHistory: [ToolExecution] = []
    
    /// Task execution start time
    @ObservationIgnored
    private var taskStartTime: Date?
    
    /// Token usage from last execution
    @ObservationIgnored
    private var lastTokenUsage: Usage?
    
    /// Get current token usage
    public var tokenUsage: Usage? {
        lastTokenUsage
    }
    
    /// Current session
    public var currentSession: ConversationSession? {
        sessionStore.currentSession
    }
    
    /// Store the last failed task for retry functionality
    @ObservationIgnored
    private var lastFailedTask: String?
    
    /// Get the last failed task (for retry button)
    public var lastTask: String? {
        lastFailedTask
    }
    
    
    // MARK: - Initialization
    
    init(settings: PeekabooSettings, sessionStore: SessionStore) {
        self.services = PeekabooServices.shared
        self.settings = settings
        self.sessionStore = sessionStore
    }
    
    // MARK: - Public Methods
    
    /// Execute a task with the agent
    public func executeTask(_ task: String) async throws {
        guard let agentService = services.agent else {
            throw AgentError.serviceUnavailable
        }
        
        // Create a cancellable task
        processingTask = Task { @MainActor in
            isProcessing = true
            currentTask = task
            lastError = nil
            lastFailedTask = nil  // Clear on new task execution
            isThinking = true
            currentTool = nil
            currentToolArgs = nil
            toolExecutionHistory = [] // Clear history for new task
            taskStartTime = Date() // Track start time
            lastTokenUsage = nil // Clear previous token usage
            defer { 
                isProcessing = false
                currentTask = ""
                processingTask = nil
            }
            
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                // Use PeekabooAgentService for enhanced functionality
                guard let peekabooAgent = agentService as? PeekabooAgentService else {
                    throw AgentError.invalidConfiguration("Agent service not properly initialized")
                }
                
                // Create or get session BEFORE task execution
                if sessionStore.currentSession == nil {
                    _ = sessionStore.createSession(title: "", modelName: settings.selectedModel)
                }
                
                // Add user message at the very beginning
                if let currentSession = sessionStore.currentSession {
                    let userMessage = ConversationMessage(role: .user, content: task)
                    sessionStore.addMessage(userMessage, to: currentSession)
                    
                    // Generate title for new sessions
                    if currentSession.title == "New Session" && currentSession.messages.count == 1 {
                        sessionStore.generateTitleForSession(currentSession)
                    }
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
                
                // Update model name if not set
                if sessionStore.currentSession?.modelName.isEmpty == true {
                    if let currentSession = sessionStore.currentSession,
                       let index = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id }) {
                        sessionStore.sessions[index].modelName = settings.selectedModel
                        Task {
                            sessionStore.saveSessions()
                        }
                    }
                }
                
                // Add assistant response to current session (if not already added during streaming)
                if let currentSession = sessionStore.currentSession {
                    // Check if we already have this assistant message from streaming
                    let hasAssistantMessage = sessionStore.sessions
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
                            toolCalls: []  // Tool calls are now separate system messages
                        )
                        sessionStore.addMessage(assistantMessage, to: currentSession)
                    }
                    
                    // Add execution summary with timing and token usage
                    if let startTime = taskStartTime {
                        let totalDuration = Date().timeIntervalSince(startTime)
                        let durationText = formatDuration(totalDuration)
                        
                        // Count total tool calls
                        let toolCount = toolExecutionHistory.count
                        
                        var summaryContent = "Task completed in \(durationText)"
                        if toolCount > 0 {
                            summaryContent += " with \(toolCount) tool call\(toolCount == 1 ? "" : "s")"
                        }
                        
                        // Add token usage if available
                        if let usage = lastTokenUsage {
                            summaryContent += " • 🤖 \(usage.totalTokens) tokens"
                            if usage.promptTokens > 0 && usage.completionTokens > 0 {
                                summaryContent += " (\(usage.promptTokens) in, \(usage.completionTokens) out)"
                            }
                        }
                        
                        let summaryMessage = ConversationMessage(
                            role: .system,
                            content: summaryContent
                        )
                        sessionStore.addMessage(summaryMessage, to: currentSession)
                    }
                    
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
                        let cancelMessage = ConversationMessage(
                            role: .system,
                            content: "⚠️ Task was cancelled by user"
                        )
                        sessionStore.addMessage(cancelMessage, to: currentSession)
                    }
                } else {
                    lastError = error.localizedDescription
                    lastFailedTask = task  // Store the failed task for retry
                    
                    // Add error message to session
                    if let currentSession = sessionStore.currentSession {
                        let errorMessage = ConversationMessage(
                            role: .system,
                            content: "❌ Error: \(error.localizedDescription)"
                        )
                        sessionStore.addMessage(errorMessage, to: currentSession)
                    }
                }
                throw error
            }
        }
        
        // Wait for the task to complete
        try await processingTask?.value
    }
    
    /// Resume a previous session
    public func resumeSession(_ sessionId: String, withTask task: String) async throws {
        currentSessionId = sessionId
        try await executeTask(task)
    }
    
    /// List available sessions
    public func listSessions() async throws -> [ConversationSessionSummary] {
        // Return summaries from the session store
        return sessionStore.sessions.map { ConversationSessionSummary(from: $0) }
    }
    
    /// Clear current session
    public func clearSession() {
        currentSessionId = nil
        lastError = nil
    }
    
    /// Check if agent is available
    public var isAvailable: Bool {
        services.agent != nil
    }
    
    /// Cancel the current task
    public func cancelCurrentTask() {
        processingTask?.cancel()
        // Don't add a message here - it will be added when the cancellation is actually handled
    }
    
    
    // MARK: - Private Methods
    
    private func handleAgentEvent(_ event: AgentEvent) {
        switch event {
        case .error(let message):
            lastError = message
            
            // Mark any running tools as failed
            if let currentTool = currentTool,
               let index = toolExecutionHistory.lastIndex(where: { $0.toolName == currentTool && $0.status == .running }) {
                toolExecutionHistory[index].status = .failed
                toolExecutionHistory[index].result = message
            }
            
        case .assistantMessage(let delta):
            // Add assistant's message to session as it streams
            // Note: 'delta' contains only the incremental text chunk, not the full content
            isThinking = false
            currentTool = nil
            currentToolArgs = nil
            
            // Add or update the assistant message in the session
            if let currentSession = sessionStore.currentSession {
                // Check if we have a recent assistant message we're building
                if let sessionIndex = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id }),
                   sessionIndex < sessionStore.sessions.count,
                   let lastMessage = sessionStore.sessions[sessionIndex].messages.last,
                   lastMessage.role == .assistant,
                   lastMessage.timestamp.timeIntervalSinceNow > -5.0 { // Within last 5 seconds
                    // Append delta to existing message content
                    let accumulatedContent = lastMessage.content + delta
                    sessionStore.sessions[sessionIndex].messages[sessionStore.sessions[sessionIndex].messages.count - 1] = ConversationMessage(
                        id: lastMessage.id,
                        role: .assistant,
                        content: accumulatedContent,
                        timestamp: lastMessage.timestamp,
                        toolCalls: lastMessage.toolCalls
                    )
                } else if !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Create new assistant message with the first delta
                    let assistantMessage = ConversationMessage(
                        role: .assistant,
                        content: delta
                    )
                    sessionStore.addMessage(assistantMessage, to: currentSession)
                }
            }
            
        case .thinkingMessage(let content):
            // Add thinking/planning message to session
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isThinking = true
                currentTool = nil
                currentToolArgs = nil
                
                if let currentSession = sessionStore.currentSession {
                    let thinkingMessage = ConversationMessage(
                        role: .system,
                        content: "🤔 \(content)"
                    )
                    sessionStore.addMessage(thinkingMessage, to: currentSession)
                }
            }
            
        case .toolCallStarted(let name, let arguments):
            isThinking = false
            currentTool = name
            currentToolArgs = arguments
            
            // Create compact summary for display
            if let data = arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                currentToolArgs = compactToolSummary(name, args)
            }
            
            // Add tool execution message to session
            if let currentSession = sessionStore.currentSession {
                let toolMessage = ConversationMessage(
                    role: .system,
                    content: "🔧 \(name): \(currentToolArgs ?? arguments)",
                    toolCalls: [ConversationToolCall(name: name, arguments: arguments, result: "Running...")]
                )
                sessionStore.addMessage(toolMessage, to: currentSession)
            }
            
            // Add to tool execution history
            let execution = ToolExecution(
                toolName: name,
                arguments: currentToolArgs ?? arguments,
                timestamp: Date(),
                status: .running
            )
            toolExecutionHistory.append(execution)
        case .toolCallCompleted(let name, let result):
            // Find and update the tool execution message
            if let currentSession = sessionStore.currentSession,
               let sessionIndex = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id }) {
                // Find the most recent tool message for this tool
                if let toolMessageIndex = sessionStore.sessions[sessionIndex].messages.lastIndex(where: { message in
                    message.role == .system && 
                    message.toolCalls.contains { $0.name == name && $0.result == "Running..." }
                }) {
                    // Update the tool call result
                    if let toolCallIndex = sessionStore.sessions[sessionIndex].messages[toolMessageIndex].toolCalls.firstIndex(where: { $0.name == name }) {
                        sessionStore.sessions[sessionIndex].messages[toolMessageIndex].toolCalls[toolCallIndex].result = result
                        Task {
                            sessionStore.saveSessions()
                        }
                    }
                }
                
            }
            
            // Update tool execution history with duration
            if let index = toolExecutionHistory.lastIndex(where: { $0.toolName == name && $0.status == .running }) {
                let startTime = toolExecutionHistory[index].timestamp
                let duration = Date().timeIntervalSince(startTime)
                toolExecutionHistory[index].status = .completed
                toolExecutionHistory[index].result = result
                toolExecutionHistory[index].duration = duration
                
                // Add timing info as a separate update
                if let currentSession = sessionStore.currentSession {
                    let durationText = String(format: "%.2fs", duration)
                    
                    // Find the tool message and create an updated version
                    if let sessionIndex = sessionStore.sessions.firstIndex(where: { $0.id == currentSession.id }),
                       let toolMessageIndex = sessionStore.sessions[sessionIndex].messages.lastIndex(where: { message in
                        message.role == .system && 
                        message.content.contains("🔧 \(name):")
                    }) {
                        let originalMessage = sessionStore.sessions[sessionIndex].messages[toolMessageIndex]
                        let updatedContent = originalMessage.content + " ⏱ \(durationText)"
                        
                        // Create a new message with updated content
                        let updatedMessage = ConversationMessage(
                            role: originalMessage.role,
                            content: updatedContent,
                            toolCalls: originalMessage.toolCalls
                        )
                        
                        // Replace the message
                        sessionStore.sessions[sessionIndex].messages[toolMessageIndex] = updatedMessage
                    }
                }
            }
            
            currentTool = nil
            currentToolArgs = nil
            isThinking = true
            
        case .completed(_, let usage):
            // Store token usage for the final summary
            lastTokenUsage = usage
            
        default:
            break
        }
    }
    
    // MARK: - Tool Display Helpers
    
    /// Get icon for tool name
    public static func iconForTool(_ toolName: String) -> String {
        switch toolName {
        case "see", "screenshot", "window_capture": return "👁"
        case "click", "dialog_click": return "🖱"
        case "type", "dialog_input": return "⌨️"
        case "list_apps", "launch_app", "dock_launch": return "📱"
        case "list_windows", "focus_window", "resize_window": return "🪟"
        case "hotkey": return "⌨️"
        case "wait": return "⏱"
        case "scroll": return "📜"
        case "find_element", "list_elements", "focused": return "🔍"
        case "shell": return "💻"
        case "menu", "menu_click", "list_menus": return "📋"
        case "dialog": return "💬"
        case "analyze_screenshot": return "🤖"
        case "list", "list_dock": return "📋"
        case "task_completed": return "✅"
        case "need_more_information": return "❓"
        default: return "⚙️"
        }
    }
    
    /// Create compact summary of tool arguments
    private func compactToolSummary(_ toolName: String, _ args: [String: Any]) -> String {
        switch toolName {
        case "see":
            var parts: [String] = []
            if let mode = args["mode"] as? String {
                switch mode {
                case "window":
                    parts.append("Taking screenshot of active window")
                case "screen":
                    parts.append("Taking screenshot of entire screen")
                case "app":
                    if let app = args["app"] as? String {
                        parts.append("Taking screenshot of \(app) application")
                    }
                default:
                    parts.append("Taking screenshot in \(mode) mode")
                }
            } else if let app = args["app"] as? String {
                parts.append("Taking screenshot of \(app)")
            } else {
                parts.append("Taking screenshot of screen")
            }
            
            if let analyze = args["analyze"] as? String {
                parts.append("and analyzing: \(analyze)")
            } else if args["analyze"] != nil {
                parts.append("and analyzing the content")
            }
            
            return parts.joined(separator: " ")
            
        case "click":
            if let x = args["x"], let y = args["y"] {
                if let text = args["text"] as? String {
                    return "Clicking on \"\(text)\" at coordinates (\(x), \(y))"
                } else {
                    return "Clicking at coordinates (\(x), \(y))"
                }
            } else if let text = args["text"] as? String {
                return "Clicking on element with text \"\(text)\""
            }
            return "Performing click action"
            
        case "type":
            if let text = args["text"] as? String {
                let preview = text.count > 50 ? String(text.prefix(50)) + "..." : text
                return "Typing text: \"\(preview)\""
            }
            return "Typing text"
            
        case "focus_window":
            if let title = args["window_title"] as? String {
                return "Focusing window titled \"\(title)\""
            } else if let app = args["app_name"] as? String {
                return "Focusing \(app) application window"
            }
            return "Focusing window"
            
        case "menu_click":
            if let menuPath = args["menuPath"] as? [String] {
                return "Clicking menu: \(menuPath.joined(separator: " → "))"
            }
            return "Clicking menu item"
            
        case "shell":
            if let command = args["command"] as? String {
                let preview = command.count > 60 ? String(command.prefix(60)) + "..." : command
                return "Running shell command: \(preview)"
            }
            return "Running shell command"
            
        case "list_apps":
            return "Listing all running applications"
            
        case "list_windows":
            if let app = args["app_name"] as? String {
                return "Listing windows for \(app)"
            }
            return "Listing all windows"
            
        case "launch_app":
            if let app = args["app_name"] as? String {
                return "Launching \(app) application"
            }
            return "Launching application"
            
        case "wait":
            if let seconds = args["seconds"] as? Double {
                return "Waiting for \(seconds) seconds"
            }
            return "Waiting"
            
        case "scroll":
            var desc = "Scrolling"
            if let direction = args["direction"] as? String {
                desc += " \(direction)"
            }
            if let amount = args["amount"] as? Int {
                desc += " by \(amount) units"
            }
            return desc
            
        case "find_element":
            if let text = args["text"] as? String {
                return "Finding element with text \"\(text)\""
            }
            return "Finding element"
            
        case "dialog_input":
            if let label = args["label"] as? String, let text = args["text"] as? String {
                let preview = text.count > 30 ? String(text.prefix(30)) + "..." : text
                return "Entering \"\(preview)\" in field labeled \"\(label)\""
            }
            return "Entering text in dialog"
            
        case "dialog_click":
            if let button = args["button"] as? String {
                return "Clicking \"\(button)\" button in dialog"
            }
            return "Clicking dialog button"
            
        case "hotkey":
            if let modifiers = args["modifiers"] as? [String], let key = args["key"] as? String {
                let combo = (modifiers + [key]).joined(separator: "+")
                return "Pressing hotkey: \(combo)"
            }
            return "Pressing hotkey"
            
        case "analyze_screenshot":
            if let prompt = args["prompt"] as? String {
                let preview = prompt.count > 50 ? String(prompt.prefix(50)) + "..." : prompt
                return "Analyzing screenshot: \"\(preview)\""
            }
            return "Analyzing screenshot"
            
        default:
            // For unknown tools, try to extract some meaningful info
            var details: [String] = []
            for (key, value) in args {
                if let str = value as? String, !str.isEmpty {
                    let preview = str.count > 30 ? String(str.prefix(30)) + "..." : str
                    details.append("\(key): \(preview)")
                } else if let num = value as? NSNumber {
                    details.append("\(key): \(num)")
                }
                if details.count >= 2 { break } // Limit to 2 parameters
            }
            
            if !details.isEmpty {
                return details.joined(separator: ", ")
            }
            return "Executing \(toolName)"
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