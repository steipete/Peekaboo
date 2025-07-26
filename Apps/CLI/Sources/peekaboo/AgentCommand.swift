import ArgumentParser
import Foundation
import PeekabooCore

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
    
    // Background colors
    static let bgBlue = "\u{001B}[44m"
    static let bgGreen = "\u{001B}[42m"
    static let bgYellow = "\u{001B}[43m"
    static let bgRed = "\u{001B}[41m"
}

/// Get icon for command in compact mode
func iconForCommand(_ command: String) -> String {
    switch command {
    case "see": return "👁"
    case "click": return "👆"
    case "type": return "⌨️"
    case "app": return "📱"
    case "window": return "🪟"
    case "hotkey": return "⌨️"
    case "wait": return "⏱"
    case "shell": return "🐚"
    case "drag": return "↗️"
    case "swipe": return "👋"
    default: return "⚙️"
    }
}

/// Get compact argument summary for display
func compactArgsSummary(_ command: String, _ args: [String: Any]) -> String {
    switch command {
    case "see":
        if let app = args["app"] as? String {
            return "screenshot of \(app)"
        } else if let mode = args["mode"] as? String {
            switch mode {
            case "frontmost":
                return "screenshot of active window"
            case "screen":
                return "screenshot of screen"
            default:
                return "screenshot (\(mode))"
            }
        }
        return "screenshot"
    case "click":
        if let element = args["element"] as? String {
            return "on '\(element)'"
        } else if let x = args["x"], let y = args["y"] {
            return "at (\(x), \(y))"
        }
        return "element"
    case "type":
        if let text = args["text"] as? String {
            let preview = text.count > 40 ? String(text.prefix(40)) + "..." : text
            return "'\(preview)'"
        }
        return "text"
    case "app":
        if let action = args["action"] as? String, let name = args["name"] as? String {
            return "\(action) \(name)"
        }
        return "application"
    case "window":
        if let action = args["action"] as? String {
            if let app = args["app"] as? String {
                return "\(action) \(app) window"
            }
            return "\(action) window"
        }
        return "window operation"
    case "hotkey":
        if let keys = args["keys"] as? [String] {
            return keys.joined(separator: "+")
        }
        return "keyboard shortcut"
    case "shell":
        if let command = args["command"] as? String {
            // AppleScript command detection
            if command.hasPrefix("osascript ") {
                if command.contains("-e") && command.contains("tell application") {
                    // Extract app name from AppleScript
                    if let appName = extractAppNameFromAppleScript(command) {
                        return "AppleScript: control \(appName)"
                    }
                    return "AppleScript: control application"
                } else if command.contains(".scpt") {
                    return "AppleScript: run script file"
                }
                return "AppleScript command"
            }
            // Regular shell commands
            else if command.hasPrefix("open ") {
                if command.contains("google.com/search") || command.contains("search") {
                    return "search in browser"
                } else if command.contains("http") {
                    return "open URL in browser"
                } else {
                    return "open application/file"
                }
            } else if command.hasPrefix("curl ") {
                return "fetch web data"
            } else {
                let preview = command.count > 50 ? String(command.prefix(50)) + "..." : command
                return "'\(preview)'"
            }
        }
        return ""
    case "wait":
        if let duration = args["duration"] as? Double {
            return "for \(duration)s"
        }
        return "briefly"
    case "drag":
        if let fromX = args["from_x"], let fromY = args["from_y"],
           let toX = args["to_x"], let toY = args["to_y"] {
            return "from (\(fromX),\(fromY)) to (\(toX),\(toY))"
        } else if let element = args["element"] as? String {
            return "'\(element)'"
        }
        return "element"
    case "swipe":
        if let direction = args["direction"] as? String {
            return "\(direction)"
        }
        return "gesture"
    case "scroll":
        if let direction = args["direction"] as? String {
            if let amount = args["amount"] {
                return "\(direction) \(amount) units"
            }
            return direction
        }
        return "page"
    case "list":
        if let target = args["target"] as? String {
            switch target {
            case "apps":
                return "running applications"
            case "windows":
                if let app = args["app"] as? String {
                    return "\(app) windows"
                }
                return "all windows"
            default:
                return target
            }
        }
        return "items"
    default:
        // For unknown commands, try to extract the most important parameter
        if let text = args["text"] as? String {
            let preview = text.count > 30 ? String(text.prefix(30)) + "..." : text
            return "'\(preview)'"
        } else if let target = args["target"] as? String {
            return "'\(target)'"
        } else if let name = args["name"] as? String {
            return name
        }
        return ""
    }
}

/// Extract application name from AppleScript command
func extractAppNameFromAppleScript(_ command: String) -> String? {
    // Look for patterns like: tell application "AppName"
    let patterns = [
        "tell application \"([^\"]+)\"",  // tell application "Safari"
        "tell application '([^']+)'",    // tell application 'Safari'
        "tell app \"([^\"]+)\"",         // tell app "Safari"  
        "tell app '([^']+)'"             // tell app 'Safari'
    ]
    
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(command.startIndex..<command.endIndex, in: command)
            if let match = regex.firstMatch(in: command, options: [], range: range) {
                if let appRange = Range(match.range(at: 1), in: command) {
                    return String(command[appRange])
                }
            }
        }
    }
    return nil
}

/// AI Agent command that uses OpenAI Assistants API to automate complex tasks
@available(macOS 14.0, *)
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent",
        discussion: """
        Uses OpenAI Assistants API to break down and execute complex automation tasks.
        The agent can see the screen, interact with UI elements, and verify results.

        EXAMPLES:
          peekaboo agent "Open TextEdit and write 'Hello World'"
          peekaboo agent "Take a screenshot of Safari and save it to Desktop"
          peekaboo agent "Click on the login button and fill the form"
          peekaboo "Find the Terminal app and run 'ls -la'" # Direct invocation

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

    @Option(name: .long, help: "OpenAI model to use")
    var model: String?

    @Flag(name: .long, help: "Output in JSON format")
    var jsonOutput = false
    
    @Option(name: .long, help: "Resume agent session: --resume \"<task>\" (latest session) or --resume <session-id> <task> (specific session) or --resume \"\" (show sessions)")
    var resume: String?
    
    /// Computed property for output mode based on flags
    private var outputMode: OutputMode {
        return quiet ? .quiet : (verbose ? .verbose : .compact)
    }

    mutating func run() async throws {
        // Handle resume functionality
        if let resumeSessionId = resume {
            if resumeSessionId.isEmpty {
                // Show recent sessions if empty string provided
                try await showRecentSessions()
                return
            } else {
                // Check if this looks like a session ID (UUID format) or if it's actually the task
                if isValidSessionId(resumeSessionId) {
                    // Resume specific session - task is required for continuation
                    guard let continuationTask = task else {
                        if jsonOutput {
                            let error = ["success": false, "error": "Task argument required when resuming session"] as [String: Any]
                            let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                            print(String(data: jsonData, encoding: .utf8) ?? "{}")
                        } else {
                            print("\(TerminalColor.red)Error: Task argument required when resuming session\(TerminalColor.reset)")
                            print("Usage: peekaboo agent --resume <session-id> \"<continuation-task>\"")
                        }
                        return
                    }
                    try await resumeSession(sessionId: resumeSessionId, continuationTask: continuationTask)
                    return
                } else {
                    // The "session ID" is actually a task - resume latest session with this task
                    try await resumeLatestSession(continuationTask: resumeSessionId)
                    return
                }
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
        
        // Load configuration defaults
        let config = PeekabooCore.ConfigurationManager.shared.getConfiguration()
        let agentConfig = config?.agent
        
        // Use command line args first, then config, then hardcoded defaults
        let effectiveModel = model ?? agentConfig?.defaultModel ?? "gpt-4-turbo"
        let effectiveMaxSteps = maxSteps ?? agentConfig?.maxSteps ?? 20
        // Get OpenAI API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(AgentError.missingAPIKey))
            } else {
                throw AgentError.missingAPIKey
            }
            return
        }

        let agent = OpenAIAgent(
            apiKey: apiKey,
            model: effectiveModel,
            verbose: self.outputMode == .verbose,
            maxSteps: effectiveMaxSteps,
            showThoughts: self.outputMode != .quiet,
            outputMode: self.outputMode)

        do {
            if self.outputMode != .quiet && !self.jsonOutput {
                switch self.outputMode {
                case .verbose:
                    print("\n═══════════════════════════════════════════════════════════════")
                    print(" PEEKABOO AGENT")
                    print("═══════════════════════════════════════════════════════════════\n")
                    print("Task: \"\(executionTask)\"")
                    print("Model: \(effectiveModel)")
                    print("Max steps: \(effectiveMaxSteps)")
                    print("API Key: \(String(apiKey.prefix(10)))***")
                    print("\nInitializing agent...\n")
                case .compact:
                    print("\(TerminalColor.cyan)\(TerminalColor.bold)🤖 Peekaboo Agent\(TerminalColor.reset) \(TerminalColor.gray)(\(Version.fullVersion))\(TerminalColor.reset)")
                    print("\(TerminalColor.gray)Task: \(executionTask)\(TerminalColor.reset)\n")
                case .quiet:
                    break
                }
            }

            let result = try await agent.executeTask(executionTask, dryRun: self.dryRun)

            if self.jsonOutput {
                let response = AgentJSONResponse<OpenAIAgent.AgentResult>(
                    success: true,
                    data: result,
                    error: nil)
                outputAgentJSON(response)
            } else if self.outputMode == .quiet {
                // Quiet mode - only show final result
                if let summary = result.summary {
                    print(summary)
                } else {
                    print("✅ Task completed successfully!")
                }
            } else {
                // Compact mode - clean output with result
                if let summary = result.summary {
                    print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Task completed\(TerminalColor.reset)")
                    print("\(summary)")
                } else {
                    print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Task completed successfully!\(TerminalColor.reset)")
                }
            }
        } catch let error as AgentError {
            if jsonOutput {
                outputAgentJSON(createAgentErrorResponse(error))
            } else {
                throw error
            }
        } catch {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(AgentError.apiError(error.localizedDescription)))
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Resume Functionality
    
    private func showRecentSessions() async throws {
        let sessions = await AgentSessionManager.shared.getRecentSessions()
        
        if sessions.isEmpty {
            if jsonOutput {
                let response = ["success": true, "sessions": []] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("No recent agent sessions found.")
            }
            return
        }
        
        if jsonOutput {
            let sessionData = sessions.map { session in [
                "id": session.id,
                "task": session.task,
                "steps": session.steps.count,
                "lastQuestion": session.lastQuestion as Any,
                "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
                "lastActivityAt": ISO8601DateFormatter().string(from: session.lastActivityAt)
            ]}
            let response = ["success": true, "sessions": sessionData] as [String: Any]
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            print(String(data: jsonData, encoding: .utf8) ?? "{}")
        } else {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)Recent Agent Sessions:\(TerminalColor.reset)\n")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            for (index, session) in sessions.enumerated() {
                let timeAgo = formatTimeAgo(session.lastActivityAt)
                print("\(TerminalColor.blue)\(index + 1).\(TerminalColor.reset) \(TerminalColor.bold)\(session.id.prefix(8))\(TerminalColor.reset)")
                print("   Task: \(session.task)")
                print("   Steps: \(session.steps.count)")
                if let question = session.lastQuestion {
                    print("   \(TerminalColor.yellow)❓ Question: \(question)\(TerminalColor.reset)")
                }
                print("   Last activity: \(timeAgo)")
                if index < sessions.count - 1 {
                    print()
                }
            }
            
            print("\n\(TerminalColor.dim)To resume a session: peekaboo agent --resume <session-id> \"<continuation>\"\(TerminalColor.reset)")
        }
    }
    
    private func resumeSession(sessionId: String, continuationTask: String) async throws {
        guard let session = await AgentSessionManager.shared.getSession(id: sessionId) else {
            if jsonOutput {
                let error = ["success": false, "error": "Session not found"] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\(TerminalColor.red)Error: Session '\(sessionId)' not found.\(TerminalColor.reset)")
                print("Use --resume without an ID to see available sessions.")
            }
            return
        }
        
        if !jsonOutput {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)🔄 Resuming session \(sessionId.prefix(8))\(TerminalColor.reset)")
            print("\(TerminalColor.gray)Original task: \(session.task)\(TerminalColor.reset)")
            print("\(TerminalColor.gray)Previous steps: \(session.steps.count)\(TerminalColor.reset)")
            if let question = session.lastQuestion {
                print("\(TerminalColor.yellow)❓ Previous question: \(question)\(TerminalColor.reset)")
            }
            print()
        }
        
        // Continue with the new task in the context of the existing session
        let resumePrompt = "Continue with the original task. The user's response: \(continuationTask)"
        
        // Load configuration for the resume
        let config = PeekabooCore.ConfigurationManager.shared.getConfiguration()
        let agentConfig = config?.agent
        let effectiveModel = self.model ?? agentConfig?.defaultModel ?? "gpt-4-turbo"
        let effectiveMaxSteps = self.maxSteps ?? agentConfig?.maxSteps ?? 20
        
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(AgentError.missingAPIKey))
            } else {
                throw AgentError.missingAPIKey
            }
            return
        }
        
        let agent = OpenAIAgent(
            apiKey: apiKey,
            model: effectiveModel,
            verbose: self.outputMode == .verbose,
            maxSteps: effectiveMaxSteps,
            showThoughts: self.outputMode != .quiet,
            outputMode: self.outputMode)
        
        do {
            let result = try await agent.executeTask(resumePrompt, dryRun: self.dryRun, sessionId: sessionId)
            
            if self.jsonOutput {
                let response = AgentJSONResponse<OpenAIAgent.AgentResult>(
                    success: true,
                    data: result,
                    error: nil)
                outputAgentJSON(response)
            } else if self.outputMode == .quiet {
                if let summary = result.summary {
                    print(summary)
                } else {
                    print("✅ Session resumed and task completed!")
                }
            } else {
                if let summary = result.summary {
                    print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Session resumed and completed\(TerminalColor.reset)")
                    print("\(summary)")
                } else {
                    print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Session resumed successfully!\(TerminalColor.reset)")
                }
            }
        } catch let error as AgentError {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(error))
            } else {
                throw error
            }
        } catch {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(AgentError.apiError(error.localizedDescription)))
            } else {
                throw error
            }
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
    
    private func isValidSessionId(_ sessionId: String) -> Bool {
        // Check if it looks like a UUID (36 characters with dashes)
        let uuidPattern = "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: sessionId.utf16.count)
        return regex?.firstMatch(in: sessionId, options: [], range: range) != nil
    }
    
    private func resumeLatestSession(continuationTask: String) async throws {
        let sessions = await AgentSessionManager.shared.getRecentSessions(limit: 1)
        
        guard let latestSession = sessions.first else {
            if jsonOutput {
                let error = ["success": false, "error": "No previous sessions found to resume"] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\(TerminalColor.red)Error: No previous sessions found to resume\(TerminalColor.reset)")
                print("Run a task first to create a session, then use --resume to continue it.")
            }
            return
        }
        
        if !jsonOutput {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)🔄 Resuming latest session \(latestSession.id.prefix(8))\(TerminalColor.reset)")
            print("\(TerminalColor.gray)Original task: \(latestSession.task)\(TerminalColor.reset)")
            print("\(TerminalColor.gray)Previous steps: \(latestSession.steps.count)\(TerminalColor.reset)")
            if let question = latestSession.lastQuestion {
                print("\(TerminalColor.yellow)❓ Previous question: \(question)\(TerminalColor.reset)")
            }
            print()
        }
        
        try await resumeSession(sessionId: latestSession.id, continuationTask: continuationTask)
    }
}

// MARK: - OpenAI Agent Implementation

@available(macOS 14.0, *)
struct OpenAIAgent {
    let apiKey: String
    let model: String
    let verbose: Bool
    let maxSteps: Int
    let showThoughts: Bool
    let outputMode: OutputMode

    private let session = URLSession.shared
    private let executor: AgentExecutor
    private let retryConfig = RetryConfiguration.default
    
    init(apiKey: String, model: String, verbose: Bool, maxSteps: Int, showThoughts: Bool = false, outputMode: OutputMode = .compact) {
        self.apiKey = apiKey
        self.model = model
        self.verbose = verbose
        self.maxSteps = maxSteps
        self.showThoughts = showThoughts
        self.outputMode = outputMode
        // Use direct PeekabooCore services for better performance
        self.executor = AgentExecutor(verbose: verbose)
    }

    struct AgentResult: Codable {
        let steps: [Step]
        let summary: String?
        let success: Bool

        struct Step: Codable {
            let description: String
            let command: String?
            let output: String?
            let screenshot: String? // Base64 encoded
        }
    }

    func executeTask(_ task: String, dryRun: Bool, sessionId: String? = nil) async throws -> AgentResult {

        // Get or create shared assistant (reused across commands)
        if self.outputMode == .verbose {
            print("Getting shared AI assistant...")
        }
        let assistantManager = await AgentAssistantManager.shared(apiKey: apiKey, model: model)
        let assistant = try await assistantManager.getOrCreateAssistant()
        if self.outputMode == .verbose {
            print("Assistant ready - ID: \(assistant.id)")
        }

        // Create thread (one per conversation)
        if self.outputMode == .verbose {
            print("\nCreating conversation thread...")
        }
        let thread = try await createThread()
        if self.outputMode == .verbose {
            print("Thread created: \(thread.id)")
        }

        // Store thread ID for cleanup (assistant is shared and persistent)
        let threadId = thread.id
        
        // Create or get session for tracking
        let currentSessionId: String
        if let existingSessionId = sessionId {
            currentSessionId = existingSessionId
        } else {
            currentSessionId = await AgentSessionManager.shared.createSession(task: task, threadId: threadId)
        }

        defer {
            // Only clean up thread - keep assistant for reuse
            Task {
                try? await deleteThread(threadId)
            }
        }

        // Add initial message
        if self.verbose {
            print("Adding task message to thread...")
        }
        try await self.addMessage(threadId: threadId, content: task)

        // Run the assistant
        var steps: [AgentResult.Step] = []
        var stepCount = 0

        // Create initial run
        if self.verbose {
            print("\nCreating initial run...")
        }
        let run = try await createRun(threadId: threadId, assistantId: assistant.id)
        if self.verbose {
            print("Run created: \(run.id) with status: \(run.status)")
        }

        // Process the run until it's completed or we hit max steps
        runLoop: while stepCount < self.maxSteps {
            // Poll for run status
            if self.verbose {
                print("Polling run status...")
            }
            var runStatus = try await getRun(threadId: threadId, runId: run.id)

            // Wait while in progress
            var pollCount = 0
            let thinkingMessages = [
                "Thinking about the best approach...",
                "Analyzing the situation...",
                "Coming up with a plan...",
                "Determining next steps...",
                "Processing the request..."
            ]
            
            while runStatus.status == .inProgress || runStatus.status == .queued {
                if self.outputMode == .compact, pollCount % 3 == 0 { // Show thinking every 3 seconds
                    let messageIndex = (pollCount / 3) % thinkingMessages.count
                    print("\r\(TerminalColor.dim)\(thinkingMessages[messageIndex])\(TerminalColor.reset)", terminator: "")
                    fflush(stdout)
                } else if self.outputMode == .verbose, pollCount % 5 == 0 { // Log every 5 seconds
                    print("Run \(run.id) status: \(runStatus.status) [\(pollCount)s]")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                pollCount += 1

                if pollCount > 60 { // 60 second timeout for any single wait
                    throw AgentError.timeout
                }
            }

            switch runStatus.status {
            case .requiresAction:
                // Handle function calls
                guard let toolCalls = runStatus.requiredAction?.submitToolOutputs.toolCalls else {
                    break
                }

                var toolOutputs: [(toolCallId: String, output: String)] = []

                for (_, toolCall) in toolCalls.enumerated() {
                    stepCount += 1
                    let commandName = toolCall.function.name.replacingOccurrences(of: "peekaboo_", with: "")
                    
                    // Clear any thinking message on the same line
                    if self.outputMode == .compact {
                        print("\r\(String(repeating: " ", count: 80))\r", terminator: "")
                    }
                    
                    if self.outputMode != .quiet, !dryRun {
                        switch self.outputMode {
                        case .verbose:
                            print("\n═══════════════════════════════════════════════════════")
                            print(" STEP \(stepCount): \(commandName.uppercased())")
                            print("═══════════════════════════════════════════════════════")
                        case .compact:
                            let icon = iconForCommand(commandName)
                            print("\(TerminalColor.blue)\(icon) \(commandName)\(TerminalColor.reset)", terminator: "")
                            fflush(stdout)
                        case .quiet:
                            break
                        }
                        
                        if self.outputMode == .verbose {
                            print("\nCommand: \(toolCall.function.name)")
                            print("Arguments: \(toolCall.function.arguments)")
                        } else if self.outputMode == .compact {
                            // Show compact argument summary
                            if let data = toolCall.function.arguments.data(using: .utf8),
                               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                let summary = compactArgsSummary(commandName, args)
                                if !summary.isEmpty {
                                    print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
                                }
                            }
                        }
                        
                        if self.outputMode != .quiet {
                            fflush(stdout)
                        }
                    }

                    let step = AgentResult.Step(
                        description: toolCall.function.name,
                        command: toolCall.function.arguments,
                        output: nil,
                        screenshot: nil)

                    if !dryRun {
                        let output = try await executor.executeFunction(
                            name: toolCall.function.name,
                            arguments: toolCall.function.arguments)
                        
                        if self.outputMode != .quiet {
                            // Parse output to show results nicely
                            if let data = output.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let success = json["success"] as? Bool {
                                
                                switch self.outputMode {
                                case .verbose:
                                    if success {
                                        print("\n✅ SUCCESS!")
                                    } else {
                                        print("\n❌ Command failed")
                                        if let error = json["error"] as? [String: Any],
                                           let message = error["message"] as? String {
                                            print("   Error: \(message)")
                                        }
                                    }
                                case .compact:
                                    if success {
                                        print(" \(TerminalColor.green)✓\(TerminalColor.reset)")
                                    } else {
                                        print(" \(TerminalColor.red)✗\(TerminalColor.reset)")
                                        if let error = json["error"] as? [String: Any],
                                           let message = error["message"] as? String {
                                            print(" \(TerminalColor.red)\(message)\(TerminalColor.reset)")
                                        }
                                    }
                                case .quiet:
                                    break
                                }
                            } else if self.outputMode == .verbose {
                                print("\n📝 Raw output: \(output.prefix(200))...")
                            }
                        }
                        
                        toolOutputs.append((toolCallId: toolCall.id, output: output))
                        
                        // Log step to session
                        await AgentSessionManager.shared.addStep(
                            sessionId: currentSessionId,
                            description: toolCall.function.name,
                            command: toolCall.function.arguments,
                            output: output
                        )
                    }

                    steps.append(step)
                }

                if !dryRun {
                    // Submit tool outputs
                    if self.outputMode == .verbose {
                        print("\nSubmitting \(toolOutputs.count) tool outputs to run \(run.id)")
                        for output in toolOutputs {
                            print("  Tool \(output.toolCallId): \(output.output.prefix(100))...")
                        }
                    }
                    try await self.submitToolOutputs(
                        threadId: threadId,
                        runId: run.id,
                        toolOutputs: toolOutputs)

                    // Wait for the run to complete after submitting tool outputs
                    runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                    while runStatus.status == .inProgress || runStatus.status == .queued {
                        if self.outputMode == .verbose {
                            print("Waiting for run to complete... (status: \(runStatus.status))")
                        }
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                    }

                    // Continue with the same run - it might need more actions
                    if self.outputMode == .verbose {
                        print("Continuing with run \(run.id) after tool outputs...")
                    }
                    // Loop will continue to poll the same run
                }

            case .completed:
                // Get the final message
                if self.outputMode == .verbose {
                    print("\n═══════════════════════════════════════════════════════")
                    print(" TASK COMPLETED")
                    print("═══════════════════════════════════════════════════════")
                }
                let messages = try await getMessages(threadId: threadId)
                let summary = messages.first?.content.first?.text?.value
                if self.outputMode == .verbose, let summary {
                    print("\n═══════════════════════════════════════════════════════")
                    print(" RESULT")
                    print("═══════════════════════════════════════════════════════")
                    print("\n\(summary)")
                }


                return AgentResult(
                    steps: steps,
                    summary: summary,
                    success: true)

            case .failed, .cancelled, .expired:
                throw AgentError.apiError("Assistant run failed with status: \(runStatus.status)")

            case .cancelling:
                // Wait for cancellation to complete
                if self.outputMode == .verbose {
                    print("Waiting for run cancellation...")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue

            case .queued, .inProgress:
                // Should not happen here, but continue if it does
                continue
            }
        }


        return AgentResult(
            steps: steps,
            summary: "I completed \(stepCount) steps but the agent did not provide a specific summary. The task appears to have been executed.",
            success: true)
    }

    // MARK: - Assistant Management

    // Assistant management now handled by AgentAssistantManager
    // No longer need createAssistant() and deleteAssistant() methods

    private func deleteThread(_ threadId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "DELETE",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func createThread() async throws -> Thread {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")
        request.httpBody = "{}".data(using: .utf8)

        return try await self.session.retryableDataTask(
            for: request,
            decodingType: Thread.self,
            retryConfig: self.retryConfig)
    }

    private func addMessage(threadId: String, content: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")

        let message = ["role": "user", "content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: message)

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func createRun(threadId: String, assistantId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")

        let runData = ["assistant_id": assistantId]
        request.httpBody = try JSONSerialization.data(withJSONObject: runData)

        do {
            return try await self.session.retryableDataTask(
                for: request,
                decodingType: Run.self,
                retryConfig: self.retryConfig)
        } catch let error as AgentError {
            // If thread already has active run, wait and retry
            if case let .apiError(message) = error,
               message.contains("already has an active run")
            {
                // Extract the run ID from error message like "run_abc123"
                let components = message.components(separatedBy: " ")
                if let runIdComponent = components.last(where: { $0.starts(with: "run_") }) {
                    let existingRunId = runIdComponent.trimmingCharacters(in: .punctuationCharacters)

                    if verbose {
                        print("Found existing run: \(existingRunId), checking status...")
                    }

                    // Check the status of the existing run
                    do {
                        let existingRun = try await getRun(threadId: threadId, runId: existingRunId)

                        if verbose {
                            print("   Existing run status: \(existingRun.status)")
                        }

                        // If the run is done, try creating a new one immediately
                        if existingRun.status == .completed || existingRun.status == .failed ||
                            existingRun.status == .cancelled || existingRun.status == .expired
                        {
                            if verbose {
                                print("   Run is finished, creating new run...")
                            }
                            return try await session.retryableDataTask(
                                for: request,
                                decodingType: Run.self,
                                retryConfig: retryConfig)
                        }

                        // If run requires action, we need to handle it differently
                        if existingRun.status == .requiresAction {
                            if verbose {
                                print("   Run requires action - cancelling it...")
                            }

                            // Cancel the existing run that's waiting for tool outputs
                            try await cancelRun(threadId: threadId, runId: existingRunId)

                            // Wait a moment for cancellation to process
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                            // Now create a new run
                            return try await session.retryableDataTask(
                                for: request,
                                decodingType: Run.self,
                                retryConfig: retryConfig)
                        }

                        // If still in progress, wait for it
                        if existingRun.status == .inProgress || existingRun.status == .queued {
                            if verbose {
                                print("   Run still in progress, waiting...")
                            }

                            // Poll until the run completes
                            var pollCount = 0
                            while pollCount < 10 { // Max 10 seconds
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                let status = try await getRun(threadId: threadId, runId: existingRunId)

                                if status.status != .inProgress, status.status != .queued {
                                    if verbose {
                                        print("   Existing run completed with status: \(status.status)")
                                    }
                                    break
                                }
                                pollCount += 1
                            }

                            // Try creating a new run now
                            return try await session.retryableDataTask(
                                for: request,
                                decodingType: Run.self,
                                retryConfig: retryConfig)
                        }
                    } catch {
                        if verbose {
                            print("   Could not check existing run status: \(error)")
                        }
                    }
                }

                // Fallback to simple wait and retry
                if verbose {
                    print("Thread has active run, waiting...")
                }
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

                // Try once more
                return try await session.retryableDataTask(
                    for: request,
                    decodingType: Run.self,
                    retryConfig: retryConfig)
            }
            throw error
        }
    }

    private func getRun(threadId: String, runId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "GET",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        return try await self.session.retryableDataTask(
            for: request,
            decodingType: Run.self,
            retryConfig: self.retryConfig)
    }

    private func submitToolOutputs(
        threadId: String,
        runId: String,
        toolOutputs: [(toolCallId: String, output: String)]) async throws
    {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/submit_tool_outputs")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")

        let outputs = toolOutputs.map { ["tool_call_id": $0.toolCallId, "output": $0.output] }
        let data = ["tool_outputs": outputs]
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func getMessages(threadId: String) async throws -> [Message] {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "GET",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        let messageList = try await session.retryableDataTask(
            for: request,
            decodingType: MessageList.self,
            retryConfig: self.retryConfig)
        return messageList.data
    }

    private func cancelRun(threadId: String, runId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/cancel")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")
        request.httpBody = "{}".data(using: .utf8)

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }
}

// MARK: - OpenAI API Types

struct Message: Codable {
    let id: String
    let role: String
    let content: [Content]

    struct Content: Codable {
        let type: String
        let text: TextContent?

        struct TextContent: Codable {
            let value: String
        }
    }
}

struct MessageList: Codable {
    let data: [Message]
}

struct Assistant: Codable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Thread: Codable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Run: Codable {
    let id: String
    let object: String
    let status: Status
    let requiredAction: RequiredAction?

    enum Status: String, Codable {
        case queued
        case inProgress = "in_progress"
        case requiresAction = "requires_action"
        case cancelling
        case cancelled
        case failed
        case completed
        case expired
    }

    struct RequiredAction: Codable {
        let type: String
        let submitToolOutputs: SubmitToolOutputs

        struct SubmitToolOutputs: Codable {
            let toolCalls: [ToolCall]
        }
    }

    struct ToolCall: Codable {
        let id: String
        let type: String
        let function: FunctionCall

        struct FunctionCall: Codable {
            let name: String
            let arguments: String
        }
    }
}

struct CreateAssistantRequest: Codable {
    let model: String
    let name: String
    let description: String
    let instructions: String
    let tools: [Tool]
}

struct Tool: Codable {
    let type: String
    let function: FunctionDefinition
}
