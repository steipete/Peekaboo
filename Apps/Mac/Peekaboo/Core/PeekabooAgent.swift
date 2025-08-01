import Foundation
import PeekabooCore
import SwiftUI

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

    /// Execute a task with the agent
    func executeTask(_ task: String) async throws {
        guard services.agent != nil else {
            throw AgentError.serviceUnavailable
        }
        
        // Call the common implementation with text content
        try await executeTaskWithContent(.text(task))
    }
    
    /// Execute a task with audio content
    func executeTaskWithAudio(audioData: Data, duration: TimeInterval, mimeType: String = "audio/wav", transcript: String? = nil) async throws {
        guard let agentService = services.agent else {
            throw AgentError.serviceUnavailable
        }
        
        // Create audio content
        let audioContent = AudioContent(
            base64: audioData.base64EncodedString(),
            transcript: transcript,
            duration: duration,
            mimeType: mimeType
        )
        
        // Track the task
        let taskDescription = transcript ?? "[Audio message - duration: \(Int(duration))s]"
        
        // Create a cancellable task
        self.processingTask = Task { @MainActor in
            self.isProcessing = true
            self.currentTask = taskDescription
            self.lastError = nil
            self.lastFailedTask = nil
            self.isThinking = true
            self.currentThinkingContent = nil
            self.currentTool = nil
            self.currentToolArgs = nil
            self.toolExecutionHistory = []
            self.taskStartTime = Date()
            self.lastTokenUsage = nil
            defer {
                isProcessing = false
                currentTask = ""
                processingTask = nil
            }

            do {
                // Check for cancellation
                try Task.checkCancellation()

                // Create or get session BEFORE task execution
                if self.sessionStore.currentSession == nil {
                    _ = self.sessionStore.createSession(title: "", modelName: self.settings.selectedModel)
                }

                // Add user message at the very beginning
                if let currentSession = sessionStore.currentSession {
                    // Create user message with audio content
                    let displayText = transcript ?? "[Audio message - duration: \(Int(duration))s]"
                    let userMessage = ConversationMessage(
                        role: .user, 
                        content: displayText,
                        audioContent: audioContent
                    )
                    self.sessionStore.addMessage(userMessage, to: currentSession)

                    // Generate title for new sessions
                    if currentSession.title == "New Session", currentSession.messages.count == 1 {
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

                let result = try await agentService.executeTaskWithAudio(
                    audioContent: audioContent,
                    dryRun: false,
                    eventDelegate: eventDelegate)

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
                        Task {
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
                            if usage.promptTokens > 0, usage.completionTokens > 0 {
                                summaryContent += " (\(usage.promptTokens) in, \(usage.completionTokens) out)"
                            }
                        }

                        let summaryMessage = ConversationMessage(
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
                        let cancelMessage = ConversationMessage(
                            role: .system,
                            content: "⚠️ Task was cancelled by user")
                        self.sessionStore.addMessage(cancelMessage, to: currentSession)
                    }
                } else {
                    self.lastError = error.localizedDescription
                    self.lastFailedTask = taskDescription // Store the failed task for retry

                    // Add error message to session
                    if let currentSession = sessionStore.currentSession {
                        let errorMessage = ConversationMessage(
                            role: .system,
                            content: "❌ Error: \(error.localizedDescription)")
                        self.sessionStore.addMessage(errorMessage, to: currentSession)
                    }
                }
                throw error
            }
        }

        // Wait for the task to complete
        try await self.processingTask?.value
    }
    
    /// Common implementation for executing tasks with different content types
    private func executeTaskWithContent(_ content: MessageContent) async throws {
        guard let agentService = services.agent else {
            throw AgentError.serviceUnavailable
        }

        // Create a cancellable task
        self.processingTask = Task { @MainActor in
            self.isProcessing = true
            
            // Extract task description from content
            let taskDescription: String
            switch content {
            case .text(let text):
                taskDescription = text
            case .audio(let audioContent):
                taskDescription = audioContent.transcript ?? "[Audio message - duration: \(Int(audioContent.duration ?? 0))s]"
            case .image:
                taskDescription = "[Image message]"
            case .file:
                taskDescription = "[File message]"
            case .multimodal:
                taskDescription = "[Multimodal message]"
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
                if self.sessionStore.currentSession == nil {
                    _ = self.sessionStore.createSession(title: "", modelName: self.settings.selectedModel)
                }

                // Add user message at the very beginning
                if let currentSession = sessionStore.currentSession {
                    // Create user message with appropriate content
                    let userMessage: ConversationMessage
                    switch content {
                    case .text(let text):
                        userMessage = ConversationMessage(role: .user, content: text)
                    case .audio(let audioContent):
                        // For audio, show transcript if available, otherwise show placeholder
                        let displayText = audioContent.transcript ?? "[Audio message - duration: \(Int(audioContent.duration ?? 0))s]"
                        userMessage = ConversationMessage(
                            role: .user, 
                            content: displayText,
                            audioContent: audioContent
                        )
                    case .image:
                        userMessage = ConversationMessage(role: .user, content: "[Image message]")
                    case .file:
                        userMessage = ConversationMessage(role: .user, content: "[File message]")
                    case .multimodal:
                        userMessage = ConversationMessage(role: .user, content: "[Multimodal message]")
                    }
                    
                    self.sessionStore.addMessage(userMessage, to: currentSession)

                    // Generate title for new sessions
                    if currentSession.title == "New Session", currentSession.messages.count == 1 {
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
                let result: AgentExecutionResult
                switch content {
                case .text(let text):
                    result = try await peekabooAgent.executeTask(
                        text,
                        sessionId: self.currentSessionId,
                        modelName: self.settings.selectedModel,
                        eventDelegate: eventDelegate)
                case .audio(let audioContent):
                    // For now, use executeTaskWithAudio if available
                    // TODO: Update when PeekabooAgentService supports audio directly
                    if let transcript = audioContent.transcript {
                        result = try await peekabooAgent.executeTask(
                            transcript,
                            sessionId: self.currentSessionId,
                            modelName: self.settings.selectedModel,
                            eventDelegate: eventDelegate)
                    } else {
                        // Fallback for audio without transcript
                        result = try await peekabooAgent.executeTask(
                            "[Audio message without transcript]",
                            sessionId: self.currentSessionId,
                            modelName: self.settings.selectedModel,
                            eventDelegate: eventDelegate)
                    }
                case .image, .file, .multimodal:
                    // For now, use text representation
                    result = try await peekabooAgent.executeTask(
                        taskDescription,
                        sessionId: self.currentSessionId,
                        modelName: self.settings.selectedModel,
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
                        Task {
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
                            if usage.promptTokens > 0, usage.completionTokens > 0 {
                                summaryContent += " (\(usage.promptTokens) in, \(usage.completionTokens) out)"
                            }
                        }

                        let summaryMessage = ConversationMessage(
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
                        let cancelMessage = ConversationMessage(
                            role: .system,
                            content: "⚠️ Task was cancelled by user")
                        self.sessionStore.addMessage(cancelMessage, to: currentSession)
                    }
                } else {
                    self.lastError = error.localizedDescription
                    self.lastFailedTask = taskDescription // Store the failed task for retry

                    // Add error message to session
                    if let currentSession = sessionStore.currentSession {
                        let errorMessage = ConversationMessage(
                            role: .system,
                            content: "❌ Error: \(error.localizedDescription)")
                        self.sessionStore.addMessage(errorMessage, to: currentSession)
                    }
                }
                throw error
            }
        }

        // Wait for the task to complete
        try await self.processingTask?.value
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

    private func handleAgentEvent(_ event: AgentEvent) {
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
                } else if !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Create new assistant message with the first delta
                    let assistantMessage = ConversationMessage(
                        role: .assistant,
                        content: delta)
                    self.sessionStore.addMessage(assistantMessage, to: currentSession)
                }
            }

        case let .thinkingMessage(content):
            // Add thinking/planning message to session
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.isThinking = true
                self.currentThinkingContent = content
                self.currentTool = nil
                self.currentToolArgs = nil

                if let currentSession = sessionStore.currentSession {
                    let thinkingMessage = ConversationMessage(
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

            // Create compact summary for display
            if let data = arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                self.currentToolArgs = self.compactToolSummary(name, args)
            }

            // Add tool execution message to session
            if let currentSession = sessionStore.currentSession {
                let toolMessage = ConversationMessage(
                    role: .system,
                    content: "🔧 \(name): \(currentToolArgs ?? arguments)",
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
                        Task {
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

    /// Get icon for tool name
    static func iconForTool(_ toolName: String) -> String {
        switch toolName {
        case "see", "screenshot", "window_capture": "👁"
        case "click", "dialog_click": "🖱"
        case "type", "dialog_input": "⌨️"
        case "list_apps", "launch_app", "dock_launch": "📱"
        case "list_windows", "focus_window", "resize_window": "🪟"
        case "hotkey": "⌨️"
        case "wait": "⏱"
        case "scroll": "📜"
        case "find_element", "list_elements", "focused": "🔍"
        case "shell": "💻"
        case "menu", "menu_click", "list_menus": "📋"
        case "dialog": "💬"
        case "analyze_screenshot": "🤖"
        case "list", "list_dock": "📋"
        case "task_completed": "✅"
        case "need_more_information": "❓"
        default: "⚙️"
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
    private let handler: (AgentEvent) -> Void

    init(handler: @escaping (AgentEvent) -> Void) {
        self.handler = handler
    }

    func agentDidEmitEvent(_ event: AgentEvent) {
        self.handler(event)
    }
}
