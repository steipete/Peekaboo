import ArgumentParser
import Foundation
import PeekabooCore

// Simple debug logging check
fileprivate var isDebugLoggingEnabled: Bool {
    // Check if verbose mode is enabled via log level
    if let logLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
        return logLevel == "debug" || logLevel == "trace"
    }
    // Check if agent is in verbose mode
    if ProcessInfo.processInfo.arguments.contains("-v") || 
       ProcessInfo.processInfo.arguments.contains("--verbose") {
        return true
    }
    return false
}

fileprivate func aiDebugPrint(_ message: String) {
    if isDebugLoggingEnabled {
        print(message)
    }
}

/// Output modes for agent execution
enum OutputMode {
    case quiet      // Only final result
    case compact    // Clean, colorized output with tool calls (default)
    case verbose    // Full JSON debug information
}

/// ANSI color codes for terminal output
enum TerminalColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    
    // Colors
    static let blue = "\u{001B}[34m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let red = "\u{001B}[31m"
    static let cyan = "\u{001B}[36m"
    static let magenta = "\u{001B}[35m"
    static let gray = "\u{001B}[90m"
    static let italic = "\u{001B}[3m"
    
    // Background colors
    static let bgBlue = "\u{001B}[44m"
    static let bgGreen = "\u{001B}[42m"
    static let bgYellow = "\u{001B}[43m"
    
    // Cursor control
    static let clearLine = "\u{001B}[2K"
    static let moveToStart = "\r"
    static let bgRed = "\u{001B}[41m"
}

/// Ghost animator for showing thinking/syncing state
@available(macOS 14.0, *)
@MainActor
final class GhostAnimator {
    private var animationTask: Task<Void, Never>?
    private let emojis: [String]
    private let message: String
    
    init() {
        // Rotating emojis with some rare ones that appear occasionally
        self.emojis = [
            "👻", "👻", "👻", "👻",  // Ghost appears most often
            "💭", "💭", "💭",         // Thought bubble
            "🤔", "🤔",              // Thinking face
            "🌀", "🌀",              // Swirl
            "✨", "✨",              // Sparkles
            "🔮",                    // Crystal ball (rare)
            "🧠",                    // Brain (rare)
            "⚡",                    // Lightning (rare)
            "🎭",                    // Theater masks (rare)
            "🌟"                     // Glowing star (rare)
        ]
        self.message = "Thinking"
    }
    
    func start() {
        stop() // Ensure no previous animation is running
        
        animationTask = Task { [weak self] in
            guard let self = self else { return }
            var frameIndex = 0
            
            while !Task.isCancelled {
                // Pick a random emoji from the weighted list
                let emoji = self.emojis[frameIndex % self.emojis.count]
                
                // Clear line and print with new emoji
                let output = "\(TerminalColor.moveToStart)\(TerminalColor.clearLine)\(TerminalColor.cyan)\(emoji) \(self.message)\(TerminalColor.reset)"
                print(output, terminator: "")
                fflush(stdout)
                
                frameIndex = (frameIndex + 1) % self.emojis.count
                
                do {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms per frame for smoother rotation
                } catch {
                    break
                }
            }
        }
    }
    
    func stop() {
        animationTask?.cancel()
        animationTask = nil
        // Move to next line, keeping the thinking text visible
        print()  // New line
        fflush(stdout)
    }
}

/// Get icon for tool name in compact mode
func iconForTool(_ toolName: String) -> String {
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
    default: return "⚙️"
    }
}

/// AI Agent command that uses new Chat Completions API architecture
@available(macOS 14.0, *)
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent",
        discussion: """
        Uses OpenAI Chat Completions API to break down and execute complex automation tasks.
        The agent can see the screen, interact with UI elements, and verify results.

        EXAMPLES:
          peekaboo agent "Open TextEdit and write 'Hello World'"
          peekaboo agent "Take a screenshot of Safari and save it to Desktop"
          peekaboo agent "Click on the login button and fill the form"
          peekaboo "Find the Terminal app and run 'ls -la'" # Direct invocation
          
          # Resume sessions:
          peekaboo agent --resume "continue with the task"  # Resume most recent
          peekaboo agent --resume-session abc123 "do this next"  # Resume specific
          peekaboo agent --list-sessions  # Show available sessions

        The agent will:
        1. Analyze your request
        2. Break it down into steps
        3. Execute each step using Peekaboo commands
        4. Verify results with screenshots
        5. Retry if needed
        """)

    @Argument(help: "Natural language description of the task to perform (optional when using --resume)")
    var task: String?

    @Flag(name: .shortAndLong, help: "Enable verbose output with full JSON debug information")
    var verbose = false
    
    @Flag(name: [.short, .long], help: "Quiet mode - only show final result")
    var quiet = false

    @Flag(name: .long, help: "Dry run - show planned steps without executing")
    var dryRun = false

    @Option(name: .long, help: "Maximum number of steps the agent can take")
    var maxSteps: Int?

    @Option(name: .long, help: "AI model to use (e.g., o3, claude-3-opus-latest)")
    var model: String?

    @Flag(name: .long, help: "Output in JSON format")
    var jsonOutput = false
    
    @Flag(name: .long, help: "Resume the most recent session (use with task argument)")
    var resume = false
    
    @Option(name: .long, help: "Resume a specific session by ID")
    var resumeSession: String?
    
    @Flag(name: .long, help: "List available sessions")
    var listSessions = false
    
    @Flag(name: .long, help: "Disable session caching (always create new session)")
    var noCache = false
    
    /// Computed property for output mode based on flags
    private var outputMode: OutputMode {
        return quiet ? .quiet : (verbose ? .verbose : .compact)
    }

    mutating func run() async throws {
        do {
            try await runInternal()
        } catch let error as DecodingError {
            aiDebugPrint("DEBUG: Caught DecodingError in run(): \(error)")
            throw error
        } catch let error as NSError {
            aiDebugPrint("DEBUG: Caught NSError in run(): \(error)")
            aiDebugPrint("DEBUG: Domain: \(error.domain)")
            aiDebugPrint("DEBUG: Code: \(error.code)")
            aiDebugPrint("DEBUG: UserInfo: \(error.userInfo)")
            throw error
        } catch {
            aiDebugPrint("DEBUG: Caught unknown error in run(): \(error)")
            throw error
        }
    }
    
    private mutating func runInternal() async throws {
        // Initialize services
        let services = PeekabooServices.shared
        
        // Check if agent service is available
        guard let agentService = services.agent else {
            if jsonOutput {
                let error = ["success": false, "error": "Agent service not available. Please set OPENAI_API_KEY environment variable."] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\(TerminalColor.red)Error: Agent service not available. Please set OPENAI_API_KEY environment variable.\(TerminalColor.reset)")
            }
            return
        }
        
        // Handle list sessions
        if listSessions {
            try await showSessions(agentService)
            return
        }
        
        // Handle resume with specific session ID
        if let sessionId = resumeSession {
            guard let continuationTask = task else {
                if jsonOutput {
                    let error = ["success": false, "error": "Task argument required when resuming session"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: Task argument required when resuming session\(TerminalColor.reset)")
                    print("Usage: peekaboo agent --resume-session <session-id> \"<continuation-task>\"")
                }
                return
            }
            try await resumeSession(agentService, sessionId: sessionId, task: continuationTask)
            return
        }
        
        // Handle resume most recent session
        if resume {
            guard let continuationTask = task else {
                if jsonOutput {
                    let error = ["success": false, "error": "Task argument required when resuming"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: Task argument required when resuming\(TerminalColor.reset)")
                    print("Usage: peekaboo agent --resume \"<continuation-task>\"")
                }
                return
            }
            
            // Get the most recent session
            guard let peekabooAgent = agentService as? PeekabooAgentService else {
                throw PeekabooCore.PeekabooError.commandFailed("Agent service not properly initialized")
            }
            let sessions = try await peekabooAgent.listSessions()
            
            if let mostRecent = sessions.first {
                try await resumeSession(agentService, sessionId: mostRecent.id, task: continuationTask)
                return
            } else {
                if jsonOutput {
                    let error = ["success": false, "error": "No sessions found to resume"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: No sessions found to resume\(TerminalColor.reset)")
                }
                return
            }
        }
        
        // Regular execution requires task
        guard let executionTask = task else {
            if jsonOutput {
                let error = ["success": false, "error": "Task argument is required"] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\(TerminalColor.red)Error: Task argument is required\(TerminalColor.reset)")
                print("Usage: peekaboo agent \"<your-task>\"")
            }
            return
        }
        
        // Execute task
        try await executeTask(agentService, task: executionTask)
    }
    
    // MARK: - Task Execution
    
    private func executeTask(_ agentService: AgentServiceProtocol, task: String, sessionId: String? = nil) async throws {
        // Update terminal title with VibeTunnel
        updateTerminalTitle("Starting: \(task.prefix(50))...")
        
        // Create event delegate for real-time updates
        let eventDelegate = await MainActor.run {
            CompactEventDelegate(outputMode: outputMode, jsonOutput: jsonOutput, task: task)
        }
        
        // Show header
        if outputMode != .quiet && !jsonOutput {
            switch outputMode {
            case .verbose:
                print("\n═══════════════════════════════════════════════════════════════")
                print(" PEEKABOO AGENT")
                print("═══════════════════════════════════════════════════════════════\n")
                print("Task: \"\(task)\"")
                let modelName = model ?? "o3"  // Default model
                print("Model: \(modelName)")
                if let sessionId = sessionId {
                    print("Session: \(sessionId.prefix(8))... (resumed)")
                }
                print("\nInitializing agent...\n")
            case .compact:
                let modelName = model ?? "o3"  // Default model
                print("\(TerminalColor.cyan)\(TerminalColor.bold)🤖 Peekaboo Agent\(TerminalColor.reset) \(TerminalColor.gray)v\(Version.fullVersion) (\(modelName))\(TerminalColor.reset)")
                if let sessionId = sessionId {
                    print("\(TerminalColor.gray)🔄 Session: \(sessionId.prefix(8))...\(TerminalColor.reset)")
                }
                print()
            case .quiet:
                break
            }
        }
        
        do {
            // Cast to PeekabooAgentService for enhanced functionality
            guard let peekabooAgent = agentService as? PeekabooAgentService else {
                throw PeekabooCore.PeekabooError.commandFailed("Agent service not properly initialized")
            }
            
            let result = try await peekabooAgent.executeTask(
                task,
                sessionId: sessionId,
                modelName: model ?? "o3",
                eventDelegate: eventDelegate
            )
            
            // Handle result display
            displayResult(result)
            
            // Show API key info in verbose mode
            if outputMode == .verbose, let apiKey = result.metadata.maskedApiKey {
                print("\(TerminalColor.gray)API Key: \(apiKey)\(TerminalColor.reset)")
            }
            
            // Update terminal title to show completion
            updateTerminalTitle("Completed: \(task.prefix(50))")
        } catch let error as DecodingError {
            aiDebugPrint("DEBUG: DecodingError caught: \(error)")
            throw error
        } catch {
            // Extract the actual error message from NSError if available
            var errorMessage = error.localizedDescription
            let nsError = error as NSError
            if
               let detailedMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                errorMessage = detailedMessage
            }
            
            if jsonOutput {
                let response = [
                    "success": false,
                    "error": errorMessage
                ] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\n\(TerminalColor.red)\(TerminalColor.bold)❌ Error:\(TerminalColor.reset) \(errorMessage)")
            }
            
            // Update terminal title to show error
            updateTerminalTitle("Error: \(task.prefix(40))...")
            throw error
        }
    }
    
    private func displayResult(_ result: AgentExecutionResult) {
        if jsonOutput {
            let response = [
                "success": true,
                "result": [
                    "content": result.content,
                    "sessionId": result.sessionId,
                    "toolCalls": result.toolCalls.map { toolCall in
                        [
                            "id": toolCall.id,
                            "type": toolCall.type.rawValue,
                            "function": [
                                "name": toolCall.function.name,
                                "arguments": toolCall.function.arguments
                            ]
                        ]
                    },
                    "metadata": [
                        "duration": result.metadata.duration,
                        "toolCallCount": result.metadata.toolCallCount,
                        "modelName": result.metadata.modelName,
                        "isResumed": result.metadata.isResumed
                    ],
                    "usage": result.usage.map { usage in
                        [
                            "promptTokens": usage.promptTokens,
                            "completionTokens": usage.completionTokens,
                            "totalTokens": usage.totalTokens
                        ]
                    } as Any
                ]
            ] as [String: Any]
            if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted) {
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            }
        } else if outputMode == .quiet {
            // Quiet mode - only show final result
            print(result.content)
        } else {
            // Compact/verbose mode - show completion message
            print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Task completed\(TerminalColor.reset)")
            if !result.content.isEmpty {
                print(result.content)
            }
        }
    }
    
    // MARK: - Session Management
    
    private func showSessions(_ agentService: AgentServiceProtocol) async throws {
        // Cast to PeekabooAgentService - this should always succeed
        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw PeekabooCore.PeekabooError.commandFailed("Agent service not properly initialized")
        }
        let sessions = try await peekabooAgent.listSessions()
        
        if sessions.isEmpty {
            if jsonOutput {
                let response = ["success": true, "sessions": []] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("No agent sessions found.")
            }
            return
        }
        
        if jsonOutput {
            let sessionData = sessions.map { session in
                [
                    "id": session.id,
                    "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
                    "updatedAt": ISO8601DateFormatter().string(from: session.updatedAt),
                    "messageCount": session.messageCount
                ]
            }
            let response = ["success": true, "sessions": sessionData] as [String: Any]
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            print(String(data: jsonData, encoding: .utf8) ?? "{}")
        } else {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)Agent Sessions:\(TerminalColor.reset)\n")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            for (index, session) in sessions.prefix(10).enumerated() {
                let timeAgo = formatTimeAgo(session.updatedAt)
                print("\(TerminalColor.blue)\(index + 1).\(TerminalColor.reset) \(TerminalColor.bold)\(session.id.prefix(8))\(TerminalColor.reset)")
                print("   Messages: \(session.messageCount)")
                print("   Last activity: \(timeAgo)")
                if index < sessions.count - 1 {
                    print()
                }
            }
            
            if sessions.count > 10 {
                print("\n\(TerminalColor.dim)... and \(sessions.count - 10) more sessions\(TerminalColor.reset)")
            }
            
            print("\n\(TerminalColor.dim)To resume: peekaboo agent --resume <session-id> \"<continuation>\"\(TerminalColor.reset)")
        }
    }
    
    private func resumeSession(_ agentService: AgentServiceProtocol, sessionId: String, task: String) async throws {
        if !jsonOutput {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)🔄 Resuming session \(sessionId.prefix(8))...\(TerminalColor.reset)\n")
        }
        
        // Execute task with existing session
        try await executeTask(agentService, task: task, sessionId: sessionId)
    }
    
    private func updateTerminalTitle(_ title: String) {
        // Use VibeTunnel to update terminal title if available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["vt", "title", title]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Silently ignore if vt is not available
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Event Delegate for Real-time Updates

@available(macOS 14.0, *)
final class CompactEventDelegate: AgentEventDelegate {
    let outputMode: OutputMode
    let jsonOutput: Bool
    private var currentTool: String?
    private let ghostAnimator = GhostAnimator()
    private var hasReceivedContent = false
    private var isThinking = true
    private let task: String
    
    init(outputMode: OutputMode, jsonOutput: Bool, task: String) {
        self.outputMode = outputMode
        self.jsonOutput = jsonOutput
        self.task = task
    }
    
    func agentDidEmitEvent(_ event: AgentEvent) {
        guard !jsonOutput else { return }
        
        switch event {
        case .started(let task):
            if outputMode == .verbose {
                print("🚀 Starting: \(task)")
            } else if outputMode == .compact {
                // Start the ghost animation when agent starts thinking
                ghostAnimator.start()
            }
            
        case .toolCallStarted(let name, let arguments):
            currentTool = name
            
            // Update terminal title for current tool
            let toolSummary = getToolSummaryForTitle(name, arguments)
            updateTerminalTitle("\(name): \(toolSummary) - \(task.prefix(30))")
            
            if outputMode != .quiet {
                // Stop the ghost animation when a tool starts
                ghostAnimator.stop()
                isThinking = false
                
                // Only print newline if we haven't received content yet
                if !hasReceivedContent {
                    // No assistant message was shown, just the ghost animation
                    // No need for extra newline
                } else {
                    // Assistant message was shown, add newline before tool output
                    print()
                }
                
                hasReceivedContent = false  // Reset for next thinking phase
                
                let icon = iconForTool(name)
                print("\(TerminalColor.blue)\(icon) \(name)\(TerminalColor.reset)", terminator: "")
                
                if outputMode == .verbose {
                    print("\n   Arguments: \(arguments)")
                } else {
                    // Show compact summary based on tool and args
                    if let data = arguments.data(using: .utf8),
                       let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let summary = compactToolSummary(name, args)
                        if !summary.isEmpty {
                            print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
                        }
                    }
                }
                fflush(stdout)
            }
            
        case .toolCallCompleted(let name, let result):
            if outputMode != .quiet {
                if let data = result.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool {
                    if success {
                        print(" \(TerminalColor.green)✓\(TerminalColor.reset)")
                    } else {
                        print(" \(TerminalColor.red)✗\(TerminalColor.reset)")
                        
                        // Display enhanced error information
                        displayEnhancedError(tool: name, json: json)
                    }
                } else {
                    print(" \(TerminalColor.green)✓\(TerminalColor.reset)")
                }
            }
            currentTool = nil
            isThinking = true  // Agent is thinking again after tool completion
            
        case .assistantMessage(let content):
            if outputMode == .verbose {
                print("\n💭 Assistant: \(content)")
            } else if outputMode == .compact {
                // Stop animation on first content if still running
                if isThinking && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ghostAnimator.stop()
                    isThinking = false
                    hasReceivedContent = true
                    // Print newline after animation to start content on new line
                    print()
                }
                
                // In compact mode, show all streaming text directly
                print(content, terminator: "")
                fflush(stdout)
            }
            
        case .thinkingMessage(let content):
            if outputMode == .verbose {
                print("\n🤔 Thinking: \(content)")
            } else if outputMode == .compact {
                // Stop animation when thinking content arrives
                if isThinking {
                    ghostAnimator.stop()
                    isThinking = false
                    // Print thinking prefix once
                    print("\n\(TerminalColor.cyan)💭 Thinking:\(TerminalColor.reset) ", terminator: "")
                }
                
                // Show thinking content
                print(content, terminator: "")
                fflush(stdout)
            }
            
        case .error(let message):
            ghostAnimator.stop() // Stop animation on error
            print("\n\(TerminalColor.red)❌ Error: \(message)\(TerminalColor.reset)")
            
        case .completed(_):
            ghostAnimator.stop() // Ensure animation is stopped
            // Final summary is handled by the main execution flow
            break
        }
    }
    
    private func displayEnhancedError(tool: String, json: [String: Any]) {
        let error = json["error"] as? String ?? "Unknown error"
        
        // Check for enhanced error details
        if let errorDetails = json["errorDetails"] as? [String: Any],
           let context = errorDetails["context"] as? [String: Any] {
            
            // Display main error
            print("   \(TerminalColor.red)Error: \(error)\(TerminalColor.reset)")
            
            // Display contextual information based on available fields
            if let available = context["available"] as? [String], !available.isEmpty {
                let availableStr = available.prefix(3).joined(separator: ", ")
                let suffix = available.count > 3 ? " (+\(available.count - 3) more)" : ""
                print("   \(TerminalColor.gray)Available: \(availableStr)\(suffix)\(TerminalColor.reset)")
            }
            
            if let suggestions = context["suggestions"] as? [String], !suggestions.isEmpty {
                let suggestion = suggestions.first!
                print("   \(TerminalColor.yellow)Suggestion: \(suggestion)\(TerminalColor.reset)")
            }
            
            if let currentState = context["currentState"] as? String {
                print("   \(TerminalColor.gray)Current: \(currentState)\(TerminalColor.reset)")
            }
            
            if let requiredState = context["requiredState"] as? String {
                print("   \(TerminalColor.gray)Required: \(requiredState)\(TerminalColor.reset)")
            }
            
            if let fix = context["fix"] as? String {
                print("   \(TerminalColor.cyan)Fix: \(fix)\(TerminalColor.reset)")
            }
            
            if let example = context["example"] as? String {
                print("   \(TerminalColor.gray)Example: \(example)\(TerminalColor.reset)")
            }
        } else {
            // Fallback to old error display for tools not yet updated
            switch tool {
            case "shell":
                // Show command output if present
                if let output = json["output"] as? String, !output.isEmpty {
                    print("   \(TerminalColor.gray)Output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))\(TerminalColor.reset)")
                }
                // Show error message with exit code on same line
                let exitCode = json["exitCode"] as? Int ?? 0
                print("   \(TerminalColor.red)Error (Exit code: \(exitCode)): \(error.trimmingCharacters(in: .whitespacesAndNewlines))\(TerminalColor.reset)")
            default:
                // For other tools, just show the error
                print("   \(TerminalColor.red)\(error)\(TerminalColor.reset)")
            }
        }
    }
    
    private func compactToolSummary(_ toolName: String, _ args: [String: Any]) -> String {
        switch toolName {
        case "see":
            var parts: [String] = []
            if let mode = args["mode"] as? String {
                parts.append(mode == "window" ? "active window" : mode)
            } else if let app = args["app"] as? String {
                parts.append(app)
            } else {
                parts.append("screen")
            }
            if args["analyze"] != nil {
                parts.append("and analyze")
            }
            return parts.joined(separator: " ")
            
        case "screenshot":
            if let mode = args["mode"] as? String {
                return mode == "window" ? "active window" : mode
            } else if let app = args["app"] as? String {
                return app
            }
            return "full screen"
            
        case "window_capture":
            if let app = args["appName"] as? String {
                return app
            }
            return "active window"
            
        case "click":
            if let target = args["target"] as? String {
                // Check if it's an element ID (like B7, O6, etc.) or text
                if target.count <= 3 && target.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    // It's an element ID - show it with a label indicator
                    return "element \(target)"
                } else {
                    // It's text or other target
                    return "'\(target)'"
                }
            } else if let element = args["element"] as? String {
                // Element ID format
                return "element \(element)"
            } else if let x = args["x"], let y = args["y"] {
                return "at (\(x), \(y))"
            }
            return ""
            
        case "type":
            if let text = args["text"] as? String {
                // Show full text in compact mode, even if it's long
                return "'\(text)'"
            }
            return ""
            
        case "scroll":
            if let direction = args["direction"] as? String {
                if let amount = args["amount"] as? Int {
                    return "\(direction) \(amount)px"
                }
                return direction
            }
            return "down"
            
        case "focus_window":
            if let app = args["appName"] as? String {
                return app
            }
            return "active window"
            
        case "resize_window":
            var parts: [String] = []
            if let app = args["appName"] as? String {
                parts.append(app)
            }
            if let width = args["width"], let height = args["height"] {
                parts.append("to \(width)x\(height)")
            }
            return parts.isEmpty ? "active window" : parts.joined(separator: " ")
            
        case "launch_app":
            if let app = args["appName"] as? String {
                return app
            }
            return "application"
            
        case "hotkey":
            if let keys = args["keys"] as? String {
                // Format keyboard shortcuts with proper symbols
                let formatted = keys.replacingOccurrences(of: "cmd", with: "⌘")
                    .replacingOccurrences(of: "command", with: "⌘")
                    .replacingOccurrences(of: "shift", with: "⇧")
                    .replacingOccurrences(of: "option", with: "⌥")
                    .replacingOccurrences(of: "opt", with: "⌥")
                    .replacingOccurrences(of: "alt", with: "⌥")
                    .replacingOccurrences(of: "control", with: "⌃")
                    .replacingOccurrences(of: "ctrl", with: "⌃")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "+", with: "")
                return formatted
            }
            return "keyboard shortcut"
            
        case "shell":
            if let command = args["command"] as? String {
                // Show full command in compact mode
                return "'\(command)'"
            }
            return "command"
            
        case "list":
            if let target = args["target"] as? String {
                switch target {
                case "apps": return "running applications"
                case "windows": 
                    if let app = args["appName"] as? String {
                        return "windows for \(app)"
                    }
                    return "all windows"
                case "elements":
                    if let type = args["type"] as? String {
                        return "\(type) elements"
                    }
                    return "UI elements"
                default: return target
                }
            }
            return ""
            
        case "menu":
            if let action = args["action"] as? String {
                if action == "click", let menuPath = args["menuPath"] as? [String] {
                    return menuPath.joined(separator: " → ")
                }
                return action
            }
            return "menu action"
            
        case "menu_click":
            if let menuPath = args["menuPath"] as? String {
                return "'\(menuPath)'"
            }
            return "menu item"
            
        case "list_windows":
            if let app = args["appName"] as? String {
                return "for \(app)"
            }
            return "all windows"
            
        case "find_element":
            if let text = args["text"] as? String {
                return "'\(text)'"
            } else if let elementId = args["elementId"] as? String {
                return "element \(elementId)"
            }
            return "UI element"
            
        case "list_apps":
            return "running applications"
            
        case "list_elements":
            if let type = args["type"] as? String {
                return "\(type) elements"
            }
            return "UI elements"
            
        case "focused":
            return "current element"
            
        case "list_menus":
            if let app = args["app"] as? String {
                return "for \(app)"
            }
            return "menu structure"
            
        case "dock_launch":
            if let app = args["appName"] as? String {
                return app
            }
            return "dock item"
            
        case "list_dock":
            return "dock items"
            
        case "dialog_click":
            if let button = args["button"] as? String {
                return "'\(button)'"
            }
            return "dialog button"
            
        case "dialog_input":
            if let text = args["text"] as? String {
                return "'\(text)'"
            }
            return "text input"
            
        default:
            return ""
        }
    }
    
    private func getToolSummaryForTitle(_ toolName: String, _ arguments: String) -> String {
        // Parse arguments and create a concise summary for terminal title
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        
        switch toolName {
        case "see", "screenshot":
            if let app = args["app"] as? String {
                return app
            } else if let mode = args["mode"] as? String {
                return mode
            }
            return "screen"
            
        case "click":
            if let target = args["target"] as? String {
                return String(target.prefix(20))
            } else if let element = args["element"] as? String {
                return element
            }
            return "element"
            
        case "type":
            if let text = args["text"] as? String {
                return "'\(String(text.prefix(15)))...'"
            }
            return "text"
            
        case "launch_app":
            if let app = args["appName"] as? String {
                return app
            }
            return "app"
            
        case "shell":
            if let cmd = args["command"] as? String {
                return String(cmd.prefix(20))
            }
            return "command"
            
        default:
            return compactToolSummary(toolName, args)
        }
    }
    
    private func updateTerminalTitle(_ title: String) {
        // Use VibeTunnel to update terminal title if available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["vt", "title", title]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Silently ignore if vt is not available
        }
    }
}
