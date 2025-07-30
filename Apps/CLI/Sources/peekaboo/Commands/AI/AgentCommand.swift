import ArgumentParser
import Dispatch
import Foundation
import PeekabooCore

// Temporary session info struct until PeekabooAgentService implements session management
// Test: Icon notifications are now working
struct AgentSessionInfo: Codable {
    let id: String
    let task: String
    let created: Date
    let lastModified: Date
    let messageCount: Int
}

// Simple debug logging check
private var isDebugLoggingEnabled: Bool {
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

private func aiDebugPrint(_ message: String) {
    if isDebugLoggingEnabled {
        print(message)
    }
}

/// Output modes for agent execution
enum OutputMode {
    case quiet // Only final result
    case compact // Clean, colorized output with tool calls (default)
    case verbose // Full JSON debug information
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
    private var animationTask: Task<(), Never>?
    private let emojis: [String]
    private let message: String

    init() {
        // Rotating emojis with some rare ones that appear occasionally
        self.emojis = [
            "👻", "👻", "👻", "👻", // Ghost appears most often
            "💭", "💭", "💭", // Thought bubble
            "🤔", "🤔", // Thinking face
            "🌀", "🌀", // Swirl
            "✨", "✨", // Sparkles
            "🔮", // Crystal ball (rare)
            "🧠", // Brain (rare)
            "⚡", // Lightning (rare)
            "🎭", // Theater masks (rare)
            "🌟" // Glowing star (rare)
        ]
        self.message = "Thinking..."
    }

    func start() {
        self.stop() // Ensure no previous animation is running

        self.animationTask = Task { [weak self] in
            guard let self else { return }
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
        self.animationTask?.cancel()
        self.animationTask = nil
        // Move to next line, keeping the thinking text visible
        print() // New line
        fflush(stdout)
    }
}

/// Get icon for tool name in compact mode
func iconForTool(_ toolName: String) -> String {
    guard let tool = PeekabooTool(from: toolName) else {
        return "⚙️"
    }

    switch tool {
    case .see, .screenshot, .windowCapture: return "👁"
    case .click, .dialogClick: return "🖱"
    case .type, .dialogInput: return "⌨️"
    case .listApps, .launchApp, .dockLaunch: return "📱"
    case .listWindows, .focusWindow, .resizeWindow: return "🪟"
    case .hotkey: return "⌨️"
    case .wait: return "⏱"
    case .scroll: return "📜"
    case .findElement, .listElements, .focused: return "🔍"
    case .shell: return "💻"
    case .menuClick, .listMenus: return "📋"
    case .listDock: return "📋"
    case .taskCompleted: return "✅"
    case .needMoreInformation: return "❓"
    case .listSpaces, .switchSpace, .moveWindowToSpace: return "🪟"
    case .drag, .swipe: return "👆"
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
          peekaboo agent "Find the Terminal app and run 'ls -la'"

          # Audio input:
          peekaboo agent --audio  # Record from microphone
          peekaboo agent --audio-file recording.wav  # Use audio file
          peekaboo agent --audio "summarize this"  # Record and process with task

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

        Audio input requires OpenAI API key for transcription via Whisper API.
        """
    )

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

    @Flag(name: .long, help: "Enable audio input mode (record from microphone)")
    var audio = false

    @Option(name: .long, help: "Audio input file path (instead of microphone)")
    var audioFile: String?

    @Flag(name: .long, help: "Use real-time audio streaming (OpenAI only)")
    var realtime = false

    /// Computed property for output mode based on flags
    private var outputMode: OutputMode {
        self.quiet ? .quiet : (self.verbose ? .verbose : .compact)
    }

    @MainActor
    mutating func run() async throws {
        do {
            try await self.runInternal()
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

    @MainActor
    private mutating func runInternal() async throws {
        // Initialize services
        let services = PeekabooServices.shared

        // Check if agent service is available
        guard let agentService = services.agent else {
            if self.jsonOutput {
                let error = [
                    "success": false,
                    "error": "Agent service not available. Please set OPENAI_API_KEY environment variable."
                ] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print(
                    "\(TerminalColor.red)Error: Agent service not available. Please set OPENAI_API_KEY environment variable.\(TerminalColor.reset)"
                )
            }
            return
        }

        // Handle list sessions
        if self.listSessions {
            try await self.showSessions(agentService)
            return
        }

        // Handle resume with specific session ID
        if let sessionId = resumeSession {
            guard let continuationTask = task else {
                if self.jsonOutput {
                    let error = [
                        "success": false,
                        "error": "Task argument required when resuming session"
                    ] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print(
                        "\(TerminalColor.red)Error: Task argument required when resuming session\(TerminalColor.reset)"
                    )
                    print("Usage: peekaboo agent --resume-session <session-id> \"<continuation-task>\"")
                }
                return
            }
            try await self.resumeSession(agentService, sessionId: sessionId, task: continuationTask)
            return
        }

        // Handle resume most recent session
        if self.resume {
            guard let continuationTask = task else {
                if self.jsonOutput {
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
            guard let peekabooService = agentService as? PeekabooAgentService else {
                throw PeekabooCore.PeekabooError.commandFailed("Agent service not properly initialized")
            }

            let sessions = try await peekabooService.listSessions()

            if let mostRecent = sessions.first {
                try await self.resumeSession(agentService, sessionId: mostRecent.id, task: continuationTask)
                return
            } else {
                if self.jsonOutput {
                    let error = ["success": false, "error": "No sessions found to resume"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: No sessions found to resume\(TerminalColor.reset)")
                }
                return
            }
        }

        // Handle audio input
        var executionTask: String
        if self.audio || self.audioFile != nil {
            if !self.jsonOutput && !self.quiet {
                if let audioPath = audioFile {
                    print("\(TerminalColor.cyan)🎙️ Processing audio file: \(audioPath)\(TerminalColor.reset)")
                } else {
                    print(
                        "\(TerminalColor.cyan)🎙️ Starting audio recording... (Press Ctrl+C to stop)\(TerminalColor.reset)"
                    )
                }
            }

            let audioService = services.audioInput

            do {
                if let audioPath = audioFile {
                    // Transcribe from file
                    let url = URL(fileURLWithPath: audioPath)
                    executionTask = try await audioService.transcribeAudioFile(url)
                } else {
                    // Record from microphone
                    try await audioService.startRecording()

                    // Create a continuation to handle the async signal
                    let transcript = try await withTaskCancellationHandler {
                        try await withCheckedThrowingContinuation { continuation in
                            // Set up signal handler for Ctrl+C
                            let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
                            signalSource.setEventHandler {
                                signalSource.cancel()
                                Task { @MainActor in
                                    do {
                                        let transcript = try await audioService.stopRecording()
                                        continuation.resume(returning: transcript)
                                    } catch {
                                        continuation.resume(throwing: error)
                                    }
                                }
                            }
                            signalSource.resume()

                            // Also provide a way to stop recording after a timeout (optional)
                            // This could be configured via a flag if needed
                        }
                    } onCancel: {
                        Task { @MainActor in
                            _ = try? await audioService.stopRecording()
                        }
                    }

                    executionTask = transcript
                }

                if !self.jsonOutput && !self.quiet {
                    print("\(TerminalColor.green)✅ Transcription complete\(TerminalColor.reset)")
                    print("\(TerminalColor.gray)Transcript: \(executionTask.prefix(100))...\(TerminalColor.reset)")
                }

                // If we have both audio and a task, combine them
                if let providedTask = task {
                    executionTask = "\(providedTask)\n\nAudio transcript:\n\(executionTask)"
                }

            } catch {
                if self.jsonOutput {
                    let errorObj = [
                        "success": false,
                        "error": "Audio processing failed: \(error.localizedDescription)"
                    ] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: errorObj, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print(
                        "\(TerminalColor.red)❌ Audio processing failed: \(error.localizedDescription)\(TerminalColor.reset)"
                    )
                }
                return
            }
        } else {
            // Regular execution requires task
            guard let providedTask = task else {
                if self.jsonOutput {
                    let error = ["success": false, "error": "Task argument is required"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: Task argument is required\(TerminalColor.reset)")
                    print("Usage: peekaboo agent \"<your-task>\"")
                    print("       peekaboo agent --audio")
                    print("       peekaboo agent --audio-file recording.wav")
                }
                return
            }
            executionTask = providedTask
        }

        // Execute task
        try await self.executeTask(agentService, task: executionTask)
    }

    // MARK: - Task Execution

    @MainActor
    private func getActualModelName(_ agentService: PeekabooAgentService) async -> String {
        // If model is explicitly provided via CLI, use that
        if let providedModel = model {
            return providedModel
        }

        // Otherwise, get the default model from the agent service
        // The agent service determines this based on PEEKABOO_AI_PROVIDERS
        return agentService.defaultModel
    }

    /// Convert internal model names to properly cased display names
    private func getDisplayModelName(_ modelName: String) -> String {
        let lowercased = modelName.lowercased()

        // OpenAI models - GPT should be uppercase with hyphen
        if lowercased.hasPrefix("gpt-") {
            let parts = modelName.split(separator: "-", maxSplits: 1)
            if parts.count == 2 {
                return "GPT-\(parts[1])"
            }
        }

        // O3/O4 models - keep lowercase "o" as OpenAI uses
        if lowercased.hasPrefix("o3") || lowercased.hasPrefix("o4") {
            return modelName.lowercased()
        }

        // Grok models - "Grok" with capital G and hyphen
        if lowercased.hasPrefix("grok-") {
            let parts = modelName.split(separator: "-", maxSplits: 1)
            if parts.count == 2 {
                let version = String(parts[1])
                // Handle special cases like "grok-2-vision-1212"
                if version.contains("-vision-") {
                    return "Grok-2 Vision"
                } else if version.contains("-image-") {
                    return "Grok-2 Image"
                } else if version.hasSuffix("-fast") {
                    let base = version.replacingOccurrences(of: "-fast", with: "")
                    return "Grok-\(base) Fast"
                } else if version.hasSuffix("-mini-fast") {
                    let base = version.replacingOccurrences(of: "-mini-fast", with: "")
                    return "Grok-\(base) Mini Fast"
                } else if version.hasSuffix("-mini") {
                    let base = version.replacingOccurrences(of: "-mini", with: "")
                    return "Grok-\(base) Mini"
                } else {
                    // Simple version like grok-3, grok-4-0709
                    return "Grok-\(version)"
                }
            }
        }

        // Claude models - proper spacing and capitalization
        if lowercased.hasPrefix("claude-") {
            // Special handling for specific model formats
            if modelName.contains("opus-4-") {
                return "Claude Opus 4"
            } else if modelName.contains("sonnet-4-") {
                return "Claude Sonnet 4"
            } else if modelName.contains("haiku-4-") {
                return "Claude Haiku 4"
            }

            // Handle Claude 3.x models
            let parts = modelName.split(separator: "-")
            if parts.count >= 3 {
                var result = "Claude"

                // Check for model type first (opus, sonnet, haiku)
                if let modelTypeIndex = parts
                    .firstIndex(where: { ["opus", "sonnet", "haiku"].contains($0.lowercased()) }) {
                    let modelType = String(parts[modelTypeIndex]).capitalized

                    // Look for version number before model type
                    if modelTypeIndex > 1 {
                        let version = String(parts[1])
                        if parts.count > 2 && modelTypeIndex > 2, let decimal = Int(parts[2]) {
                            result += " \(version).\(decimal)"
                        } else {
                            result += " \(version)"
                        }
                    }

                    result += " \(modelType)"
                    return result
                }

                // Fallback for other formats
                if parts.count > 1 {
                    let version = String(parts[1])
                    result += " \(version)"

                    if parts.count > 2 {
                        let modelType = String(parts[2]).capitalized
                        result += " \(modelType)"
                    }
                }

                return result
            }
        }

        // Default: return as-is
        return modelName
    }

    private func executeTask(
        _ agentService: AgentServiceProtocol,
        task: String,
        sessionId: String? = nil
    ) async throws {
        // Update terminal title with VibeTunnel
        self.updateTerminalTitle("Starting: \(task.prefix(50))...")

        // Cast to PeekabooAgentService early for enhanced functionality
        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw PeekabooCore.PeekabooError.commandFailed("Agent service not properly initialized")
        }

        // Get the actual model name that will be used
        let actualModelName = await getActualModelName(peekabooAgent)
        let displayModelName = self.getDisplayModelName(actualModelName)

        // Create event delegate for real-time updates
        let eventDelegate = await MainActor.run {
            CompactEventDelegate(outputMode: self.outputMode, jsonOutput: self.jsonOutput, task: task)
        }

        // Show header with properly cased model name
        if self.outputMode != .quiet && !self.jsonOutput {
            switch self.outputMode {
            case .verbose:
                print("\n╭─────────────────────────────────────────────────────────────╮")
                print(
                    "│ \(TerminalColor.bold)\(TerminalColor.cyan)PEEKABOO AGENT\(TerminalColor.reset)                                              │"
                )
                print("├─────────────────────────────────────────────────────────────┤")
                print(
                    "│ \(TerminalColor.gray)Task:\(TerminalColor.reset) \(task.truncated(to: 50).padding(toLength: 50, withPad: " ", startingAt: 0))│"
                )
                print(
                    "│ \(TerminalColor.gray)Model:\(TerminalColor.reset) \(displayModelName.padding(toLength: 49, withPad: " ", startingAt: 0))│"
                )
                print("╰─────────────────────────────────────────────────────────────╯")
                if let sessionId {
                    print("Session: \(sessionId.prefix(8))... (resumed)")
                }
                print("\nInitializing agent...\n")
            case .compact:
                // Show model in header
                let versionNumber = Version.current.replacingOccurrences(of: "Peekaboo ", with: "")
                let versionInfo = "(\(Version.gitBranch)/\(Version.gitCommit), \(Version.gitCommitDate))"
                print(
                    "\(TerminalColor.cyan)\(TerminalColor.bold)🤖 Peekaboo Agent\(TerminalColor.reset) \(TerminalColor.gray)\(versionNumber) using \(displayModelName) \(versionInfo)\(TerminalColor.reset)"
                )
                if let sessionId {
                    print("\(TerminalColor.gray)🔄 Session: \(sessionId.prefix(8))...\(TerminalColor.reset)")
                }
            case .quiet:
                break
            }
        }

        do {
            let result = try await peekabooAgent.executeTask(
                task,
                sessionId: sessionId,
                modelName: actualModelName, // Use the actual model name from config/env
                eventDelegate: eventDelegate
            )

            // Update token count in delegate if available
            if let usage = result.usage {
                await MainActor.run {
                    eventDelegate.updateTokenCount(usage.totalTokens)
                }
            }

            // Handle result display
            self.displayResult(result)

            // Show final summary if not already shown
            if !self.jsonOutput && self.outputMode != .quiet {
                await MainActor.run {
                    eventDelegate.showFinalSummaryIfNeeded(result)
                }
            }

            // Show API key info in verbose mode
            if self.outputMode == .verbose, let apiKey = result.metadata.maskedApiKey {
                print("\(TerminalColor.gray)API Key: \(apiKey)\(TerminalColor.reset)")
            }

            // Update terminal title to show completion
            self.updateTerminalTitle("Completed: \(task.prefix(50))")
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

            if self.jsonOutput {
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
            self.updateTerminalTitle("Error: \(task.prefix(40))...")
            throw error
        }
    }

    private func displayResult(_ result: AgentExecutionResult) {
        if self.jsonOutput {
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
        } else if self.outputMode == .quiet {
            // Quiet mode - only show final result
            print(result.content)
        } else {
            // Don't print here - let the event handler show the enhanced summary
            if !result.content.isEmpty {
                print(result.content)
            }
        }
    }

    // MARK: - Session Management

    private func showSessions(_ agentService: AgentServiceProtocol) async throws {
        // Cast to PeekabooAgentService - this should always succeed
        guard let peekabooService = agentService as? PeekabooAgentService else {
            throw PeekabooCore.PeekabooError.commandFailed("Agent service not properly initialized")
        }

        let sessionSummaries = try await peekabooService.listSessions()

        // Convert SessionSummary to AgentSessionInfo for display
        let sessions = sessionSummaries.map { summary in
            AgentSessionInfo(
                id: summary.id,
                task: summary.metadata?.string("task") ?? "Unknown task",
                created: summary.createdAt,
                lastModified: summary.updatedAt,
                messageCount: summary.messageCount
            )
        }

        if sessions.isEmpty {
            if self.jsonOutput {
                let response = ["success": true, "sessions": []] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("No agent sessions found.")
            }
            return
        }

        if self.jsonOutput {
            let sessionData = sessions.map { session in
                [
                    "id": session.id,
                    "createdAt": ISO8601DateFormatter().string(from: session.created),
                    "updatedAt": ISO8601DateFormatter().string(from: session.lastModified),
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
                let timeAgo = self.formatTimeAgo(session.lastModified)
                print(
                    "\(TerminalColor.blue)\(index + 1).\(TerminalColor.reset) \(TerminalColor.bold)\(session.id.prefix(8))\(TerminalColor.reset)"
                )
                print("   Messages: \(session.messageCount)")
                print("   Last activity: \(timeAgo)")
                if index < sessions.count - 1 {
                    print()
                }
            }

            if sessions.count > 10 {
                print("\n\(TerminalColor.dim)... and \(sessions.count - 10) more sessions\(TerminalColor.reset)")
            }

            print(
                "\n\(TerminalColor.dim)To resume: peekaboo agent --resume <session-id> \"<continuation>\"\(TerminalColor.reset)"
            )
        }
    }

    private func resumeSession(_ agentService: AgentServiceProtocol, sessionId: String, task: String) async throws {
        if !self.jsonOutput {
            print(
                "\(TerminalColor.cyan)\(TerminalColor.bold)🔄 Resuming session \(sessionId.prefix(8))...\(TerminalColor.reset)\n"
            )
        }

        // Execute task with existing session
        try await self.executeTask(agentService, task: task, sessionId: sessionId)
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
    private var toolStartTimes: [String: Date] = [:]
    private let startTime = Date()
    private var toolCallCount = 0
    private var totalTokens = 0
    private var hasShownFinalSummary = false

    init(outputMode: OutputMode, jsonOutput: Bool, task: String) {
        self.outputMode = outputMode
        self.jsonOutput = jsonOutput
        self.task = task
    }

    func updateTokenCount(_ tokens: Int) {
        self.totalTokens = tokens
    }

    func showFinalSummaryIfNeeded(_ result: AgentExecutionResult) {
        // Don't show summary if task_completed already handled it
        guard !self.hasShownFinalSummary else { return }

        // Show a simple completion summary
        let totalElapsed = result.metadata.duration
        let tokenInfo = self.totalTokens > 0 ? ", \(self.totalTokens) tokens" : ""
        let toolsText = result.metadata.toolCallCount == 1 ? "1 tool" : "\(result.metadata.toolCallCount) tools"

        if self.outputMode == .compact {
            print(
                "\n\(TerminalColor.bold)\(TerminalColor.green)✅ Task completed\(TerminalColor.reset) \(TerminalColor.gray)(Total: \(self.formatDuration(totalElapsed)), \(toolsText)\(tokenInfo))\(TerminalColor.reset)"
            )
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.0fµs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%dmin %ds", minutes, remainingSeconds)
        }
    }

    // Extract meaningful summary from tool results
    private func getToolResultSummary(_ toolName: String, _ result: [String: Any]) -> String {
        guard let tool = PeekabooTool(from: toolName) else {
            // Fallback for unknown tools
            if let success = result["success"] as? Bool {
                return success ? "Success" : "Failed"
            }
            return ""
        }

        // Handle wrapped results {"type": "object", "value": {...}}
        let actualResult: [String: Any] = if result["type"] as? String == "object",
                                             let value = result["value"] as? [String: Any] {
            value
        } else {
            result
        }

        switch tool {
        case .listDock:
            // Check for totalCount directly in result
            if let totalCount = actualResult["totalCount"] as? String {
                return "\(totalCount) items"
            }
            // Check for wrapped totalCount
            else if let totalCountWrapper = actualResult["totalCount"] as? [String: Any],
                    let value = totalCountWrapper["value"] {
                return "\(value) items"
            }
            // Check for metadata.totalCount
            else if let metadata = actualResult["metadata"] as? [String: Any],
                    let totalCount = metadata["totalCount"] as? String {
                return "\(totalCount) items"
            }
            // Check for count value (tool result format)
            else if let countValue = actualResult["count"] as? [String: Any],
                    let count = countValue["value"] as? String {
                return "\(count) items"
            }
            // Fallback to items array
            else if let items = actualResult["items"] as? [[String: Any]] {
                return "\(items.count) items"
            }

        case .listApps:
            // Check for count value first (tool result format)
            if let countValue = actualResult["count"] as? [String: Any],
               let count = countValue["value"] as? String {
                return "\(count) apps"
            }
            // Check nested structure
            else if let data = actualResult["data"] as? [String: Any],
                    let apps = data["applications"] as? [[String: Any]] {
                return "\(apps.count) apps"
            }
            // Fallback to direct structure
            else if let apps = actualResult["apps"] as? [[String: Any]] {
                return "\(apps.count) apps"
            }
            // Try applications key directly
            else if let apps = actualResult["applications"] as? [[String: Any]] {
                return "\(apps.count) apps"
            }

        case .listWindows:
            var parts: [String] = []

            // Get window count
            var windowCount = 0
            if let windows = actualResult["windows"] as? [[String: Any]] {
                windowCount = windows.count
            } else if let countWrapper = actualResult["count"] as? [String: Any],
                      let count = countWrapper["value"] as? Int {
                windowCount = count
            }

            if windowCount == 0 {
                parts.append("No windows")
            } else if windowCount == 1 {
                parts.append("1 window")
            } else {
                parts.append("\(windowCount) windows")
            }

            // Get app name if specified
            if let app = actualResult["app"] as? String {
                parts.append("for \(app)")
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appValue = appWrapper["value"] as? String {
                parts.append("for \(appValue)")
            }

            return parts.joined(separator: " ")

        case .listElements:
            if let elements = actualResult["elements"] as? [[String: Any]] {
                return "\(elements.count) elements"
            }

        case .listSpaces:
            if let spaces = actualResult["spaces"] as? [[String: Any]] {
                return "\(spaces.count) spaces"
            }

        case .listMenus:
            if let menus = actualResult["menus"] as? [[String: Any]] {
                return "\(menus.count) menus"
            }

        case .see:
            var parts: [String] = []
            parts.append("Captured")

            // Get app/mode context
            if let app = actualResult["app"] as? String, app != "entire screen" {
                parts.append(app)
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appValue = appWrapper["value"] as? String, appValue != "entire screen" {
                parts.append(appValue)
            } else if let mode = actualResult["mode"] as? String {
                if mode == "window" {
                    // Try to get the actual window/app name
                    if let windowTitle = actualResult["windowTitle"] as? String {
                        parts.append(windowTitle)
                    } else {
                        parts.append("active window")
                    }
                } else {
                    parts.append(mode)
                }
            } else {
                parts.append("screen")
            }

            // Add element counts if available
            var elementCounts: [String] = []

            // Check for dialog detection
            if let dialogDetected = actualResult["dialogDetected"] as? Bool, dialogDetected {
                elementCounts.append("dialog detected")
            }

            if let elementCount = actualResult["elementCount"] as? Int {
                elementCounts.append("\(elementCount) elements")
            } else if let resultText = actualResult["result"] as? String {
                // Extract counts from result text
                let patterns = [
                    (#"(\d+) button"#, "buttons"),
                    (#"(\d+) text"#, "text fields"),
                    (#"(\d+) link"#, "links"),
                    (#"(\d+) image"#, "images"),
                    (#"(\d+) static text"#, "labels")
                ]

                for (pattern, label) in patterns {
                    if let range = resultText.range(of: pattern, options: .regularExpression) {
                        let match = String(resultText[range])
                        if let numberRange = match.range(of: #"\d+"#, options: .regularExpression) {
                            let count = String(match[numberRange])
                            elementCounts.append("\(count) \(label)")
                        }
                    }
                }
            }

            if !elementCounts.isEmpty {
                parts.append("(\(elementCounts.joined(separator: ", ")))")
            }

            return parts.joined(separator: " ")

        case .screenshot, .windowCapture:
            if let path = actualResult["path"] as? String {
                return "Saved \(URL(fileURLWithPath: path).lastPathComponent)"
            }
            return "Saved screenshot"

        case .click:
            var parts: [String] = []

            // Get click type
            var clickType = "Clicked"
            if let type = actualResult["type"] as? String {
                if type == "right_click" {
                    clickType = "Right-clicked"
                } else if type == "double_click" {
                    clickType = "Double-clicked"
                }
            } else if let typeWrapper = actualResult["type"] as? [String: Any],
                      let typeValue = typeWrapper["value"] as? String {
                if typeValue == "right_click" {
                    clickType = "Right-clicked"
                } else if typeValue == "double_click" {
                    clickType = "Double-clicked"
                }
            }
            parts.append(clickType)

            // Add what was clicked (element or coordinates)
            if let element = actualResult["element"] as? String {
                // Handle element IDs like B7, T2
                if element.count <= 3 && element.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    parts.append("element \(element)")
                } else {
                    parts.append("'\(element)'")
                }
            } else if let elementWrapper = actualResult["element"] as? [String: Any],
                      let elementValue = elementWrapper["value"] as? String {
                if elementValue.count <= 3 && elementValue
                    .range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    parts.append("element \(elementValue)")
                } else {
                    parts.append("'\(elementValue)'")
                }
            } else if let x = actualResult["x"], let y = actualResult["y"] {
                // Handle wrapped coordinate values
                var xCoord = ""
                var yCoord = ""

                if let xDict = x as? [String: Any], let xValue = xDict["value"] {
                    xCoord = String(describing: xValue)
                } else {
                    xCoord = String(describing: x)
                }

                if let yDict = y as? [String: Any], let yValue = yDict["value"] {
                    yCoord = String(describing: yValue)
                } else {
                    yCoord = String(describing: y)
                }

                parts.append("at (\(xCoord), \(yCoord))")
            }

            // Add app context
            if let app = actualResult["app"] as? String, app != "any" {
                parts.append("in \(app)")
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appValue = appWrapper["value"] as? String, appValue != "any" {
                parts.append("in \(appValue)")
            }

            return parts.joined(separator: " ")

        case .type:
            var parts: [String] = []
            parts.append("Typed")

            // Get field info first
            var hasField = false
            if let field = actualResult["field"] as? String, field != "current focus" {
                parts.append("in '\(field)'")
                hasField = true
            } else if let fieldWrapper = actualResult["field"] as? [String: Any],
                      let fieldValue = fieldWrapper["value"] as? String,
                      fieldValue != "current focus" {
                parts.append("in '\(fieldValue)'")
                hasField = true
            }

            // If no specific field, try to get app context
            if !hasField {
                if let app = actualResult["app"] as? String {
                    parts.append("in \(app)")
                } else if let appWrapper = actualResult["app"] as? [String: Any],
                          let appValue = appWrapper["value"] as? String {
                    parts.append("in \(appValue)")
                }
            }

            return parts.joined(separator: " ")

        case .hotkey:
            var parts: [String] = []
            parts.append("Pressed")

            // Get keys (handle wrapped format)
            var keys: String?
            if let k = actualResult["keys"] as? String {
                keys = k
            } else if let keysWrapper = actualResult["keys"] as? [String: Any],
                      let keysValue = keysWrapper["value"] as? String {
                keys = keysValue
            }

            if let k = keys {
                // Format keys with proper symbols
                let formatted = k.replacingOccurrences(of: "cmd", with: "⌘")
                    .replacingOccurrences(of: "command", with: "⌘")
                    .replacingOccurrences(of: "shift", with: "⇧")
                    .replacingOccurrences(of: "option", with: "⌥")
                    .replacingOccurrences(of: "alt", with: "⌥")
                    .replacingOccurrences(of: "control", with: "⌃")
                    .replacingOccurrences(of: "ctrl", with: "⌃")
                    .replacingOccurrences(of: ",", with: "")
                parts.append(formatted)
            }

            // Add app context
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appValue = appWrapper["value"] as? String {
                parts.append("in \(appValue)")
            }

            return parts.joined(separator: " ")

        case .scroll:
            var parts: [String] = []
            parts.append("Scrolled")

            // Get direction (handle wrapped format)
            var direction: String?
            if let dir = actualResult["direction"] as? String {
                direction = dir
            } else if let dirWrapper = actualResult["direction"] as? [String: Any],
                      let dirValue = dirWrapper["value"] as? String {
                direction = dirValue
            }

            // Get amount
            var amount: Int?
            if let amt = actualResult["amount"] as? Int {
                amount = amt
            } else if let amtWrapper = actualResult["amount"] as? [String: Any],
                      let amtValue = amtWrapper["value"] as? Int {
                amount = amtValue
            }

            if let dir = direction {
                parts.append(dir)
                if let amt = amount {
                    parts.append("(\(amt) lines)")
                }
            }

            return parts.joined(separator: " ")

        case .focusWindow:
            if let app = actualResult["app"] as? String {
                return "Focused \(app)"
            }
            return "Focused window"

        case .launchApp:
            var parts: [String] = []
            parts.append("Launched")

            // Check for app name in various possible locations
            if let app = actualResult["app"] as? String {
                parts.append(app)
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appValue = appWrapper["value"] as? String {
                parts.append(appValue)
            }

            // Add status if it was already running
            if let wasRunning = actualResult["wasRunning"] as? String, wasRunning == "true" {
                parts.append("(was already running)")
            }

            return parts.joined(separator: " ")

        case .resizeWindow:
            var parts: [String] = []
            parts.append("Resized")

            if let app = actualResult["app"] as? String {
                parts.append(app)
            }

            if let width = actualResult["width"] as? Int, let height = actualResult["height"] as? Int {
                parts.append("to \(width)x\(height)")
            }

            return parts.joined(separator: " ")

        case .menuClick:
            var parts: [String] = []
            parts.append("Clicked")

            // Get the menu path (could be in menuPath or path)
            var menuPath: String?
            if let path = actualResult["menuPath"] as? String {
                menuPath = path
            } else if let pathWrapper = actualResult["menuPath"] as? [String: Any],
                      let pathValue = pathWrapper["value"] as? String {
                menuPath = pathValue
            }

            // Get the app name
            var appName: String?
            if let app = actualResult["app"] as? String {
                appName = app
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appValue = appWrapper["value"] as? String {
                appName = appValue
            }

            // Format the output
            if let path = menuPath {
                parts.append("'\(path)'")
            }

            if let app = appName, app != "frontmost app" {
                parts.append("in \(app)")
            }

            return parts.joined(separator: " ")

        case .dialogClick:
            var parts: [String] = []
            parts.append("Clicked")

            if let button = actualResult["button"] as? String {
                parts.append("'\(button)'")
            }

            if let dialog = actualResult["dialogType"] as? String {
                parts.append("in \(dialog)")
            }

            return parts.joined(separator: " ")

        case .findElement:
            var parts: [String] = []

            // Check if found
            var found = false
            if let f = actualResult["found"] as? Bool {
                found = f
            } else if let foundWrapper = actualResult["found"] as? [String: Any],
                      let foundValue = foundWrapper["value"] as? Bool {
                found = foundValue
            }

            if found {
                parts.append("Found")

                // Get element details
                if let element = actualResult["element"] as? String {
                    parts.append("'\(element)'")
                } else if let elementWrapper = actualResult["element"] as? [String: Any],
                          let elementValue = elementWrapper["value"] as? String {
                    parts.append("'\(elementValue)'")
                } else if let text = actualResult["text"] as? String {
                    parts.append("'\(text)'")
                }

                // Add element type if available
                if let type = actualResult["type"] as? String {
                    parts.append("(\(type))")
                }

                // Add location if available
                if let elementId = actualResult["elementId"] as? String {
                    parts.append("as \(elementId)")
                }
            } else {
                parts.append("Not found")

                // Add what was searched for
                if let query = actualResult["query"] as? String {
                    parts.append("'\(query)'")
                } else if let text = actualResult["text"] as? String {
                    parts.append("'\(text)'")
                }
            }

            return parts.joined(separator: " ")

        case .focused:
            if let label = actualResult["label"] as? String {
                if let app = actualResult["app"] as? String {
                    return "'\(label)' field in \(app)"
                }
                return "'\(label)' field"
            } else if let elementType = actualResult["type"] as? String {
                if let app = actualResult["app"] as? String {
                    return "\(elementType) in \(app)"
                }
                return elementType
            }

        case .shell:
            var parts: [String] = []

            // Get command
            var command: String?
            if let cmd = actualResult["command"] as? String {
                command = cmd
            } else if let cmdWrapper = actualResult["command"] as? [String: Any],
                      let cmdValue = cmdWrapper["value"] as? String {
                command = cmdValue
            }

            if let cmd = command {
                // Show more of the command in compact mode
                let truncatedCmd = cmd.count > 40 ? String(cmd.prefix(40)) + "..." : cmd
                parts.append("'\(truncatedCmd)'")

                // Get exit code
                var exitCode: Int?
                if let code = actualResult["exitCode"] as? Int {
                    exitCode = code
                } else if let codeWrapper = actualResult["exitCode"] as? [String: Any],
                          let codeValue = codeWrapper["value"] as? Int {
                    exitCode = codeValue
                }

                if let code = exitCode {
                    if code == 0 {
                        parts.append("✓")
                    } else {
                        parts.append("✗ (exit \(code))")
                    }
                }

                // Add execution time if available
                if let duration = actualResult["duration"] as? Double {
                    parts.append("(\(String(format: "%.1fs", duration)))")
                }
            }

            return parts.joined(separator: " ")

        default:
            break
        }

        // Default: just show success/failure
        if let success = actualResult["success"] as? Bool {
            return success ? "" : "Failed"
        }

        return ""
    }

    func agentDidEmitEvent(_ event: AgentEvent) {
        guard !self.jsonOutput else { return }

        switch event {
        case let .started(task):
            if self.outputMode == .verbose {
                print("🚀 Starting: \(task)")
            } else if self.outputMode == .compact {
                // Start the ghost animation when agent starts thinking
                self.ghostAnimator.start()
            }

        case let .toolCallStarted(name, arguments):
            self.currentTool = name
            self.toolStartTimes[name] = Date()
            self.toolCallCount += 1

            // Update terminal title for current tool
            let toolSummary = self.getToolSummaryForTitle(name, arguments)
            self.updateTerminalTitle("\(name): \(toolSummary) - \(self.task.prefix(30))")

            if self.outputMode != .quiet {
                // Stop the ghost animation when a tool starts
                self.ghostAnimator.stop()
                self.isThinking = false

                // Check if this is a special communication tool that should be displayed as assistant text
                let isCommunicationTool = (name == "task_completed" || name == "need_more_information")
                
                if !isCommunicationTool {
                    // Always add a newline before tool output for better formatting
                    // This ensures consistent spacing between thinking/content and tools
                    print()

                    self.hasReceivedContent = false // Reset for next thinking phase

                    let icon = iconForTool(name)
                    print("\(TerminalColor.blue)\(icon) \(name)\(TerminalColor.reset)", terminator: "")

                    if self.outputMode == .verbose {
                        // Show formatted arguments in verbose mode
                        if arguments.isEmpty || arguments == "{}" {
                            print("\n\(TerminalColor.gray)Arguments: (none)\(TerminalColor.reset)")
                        } else if let formatted = formatJSON(arguments) {
                            print("\n\(TerminalColor.gray)Arguments:\(TerminalColor.reset)")
                            print(formatted)
                        } else {
                            print("\n\(TerminalColor.gray)Arguments: \(arguments)\(TerminalColor.reset)")
                        }
                    } else {
                        // Show compact summary based on tool and args
                        if let data = arguments.data(using: .utf8),
                           let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let summary = self.compactToolSummary(name, args)
                            if !summary.isEmpty {
                                print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
                            }
                        }
                    }
                    fflush(stdout)
                }
            }

        case let .toolCallCompleted(name, result):
            // Calculate duration
            let duration: String
            if let startTime = toolStartTimes[name] {
                let elapsed = Date().timeIntervalSince(startTime)
                duration = " \(TerminalColor.gray)(\(self.formatDuration(elapsed)))\(TerminalColor.reset)"
                self.toolStartTimes.removeValue(forKey: name)
            } else {
                duration = ""
            }

            if self.outputMode != .quiet {
                if let data = result.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Get result summary for compact mode
                    let resultSummary = self.getToolResultSummary(name, json)

                    // Debug logging only with debug log level
                    if isDebugLoggingEnabled {
                        print("\nDEBUG: Tool \(name) result keys: \(json.keys.sorted())")
                        if let data = json["data"] as? [String: Any] {
                            print("DEBUG: data keys: \(data.keys.sorted())")
                        }
                        print("DEBUG: Result summary for \(name): '\(resultSummary)'")
                    }

                    // Special handling for task_completed tool
                    if name == "task_completed" {
                        // Show as assistant message, not tool execution
                        print() // Add newline for spacing
                        
                        if let summary = json["summary"] as? String {
                            print("\(summary)")
                        }

                        if let nextSteps = json["next_steps"] as? String {
                            print("\n\(nextSteps)")
                        }

                        // Show completion stats after the message
                        let totalElapsed = Date().timeIntervalSince(startTime)
                        let tokenInfo = self.totalTokens > 0 ? ", \(self.totalTokens) tokens" : ""
                        let toolsText = self.toolCallCount == 1 ? "1 tool" : "\(self.toolCallCount) tools"
                        print(
                            "\n\(TerminalColor.gray)Task completed in \(self.formatDuration(totalElapsed)) with \(toolsText)\(tokenInfo)\(TerminalColor.reset)"
                        )

                        self.hasShownFinalSummary = true
                    }
                    // Special handling for need_more_information tool
                    else if name == "need_more_information" {
                        // Show as assistant message, not tool execution
                        print() // Add newline for spacing
                        
                        if let question = json["question"] as? String {
                            print("\(question)")
                            
                            if let context = json["context"] as? String {
                                print("\n\(TerminalColor.gray)Context: \(context)\(TerminalColor.reset)")
                            }
                        }
                    }
                    // Regular tool handling
                    else if let success = json["success"] as? Bool {
                        if success {
                            if !resultSummary.isEmpty {
                                print(" \(TerminalColor.green)✓\(TerminalColor.reset) \(resultSummary)\(duration)")
                            } else {
                                print(" \(TerminalColor.green)✓\(TerminalColor.reset)\(duration)")
                            }

                            // Show formatted result in verbose mode
                            if self.outputMode == .verbose {
                                if let formatted = formatJSON(result) {
                                    print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                                    print(formatted)
                                }
                            }
                        } else {
                            print(" \(TerminalColor.red)✗\(TerminalColor.reset)\(duration)")

                            // Display enhanced error information
                            self.displayEnhancedError(tool: name, json: json)
                        }
                    } else {
                        // Tools that don't have explicit success field
                        if !resultSummary.isEmpty {
                            print(" \(TerminalColor.green)✓\(TerminalColor.reset) \(resultSummary)\(duration)")
                        } else {
                            print(" \(TerminalColor.green)✓\(TerminalColor.reset)\(duration)")
                        }

                        // Show formatted result in verbose mode
                        if self.outputMode == .verbose {
                            if let formatted = formatJSON(result) {
                                print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                                print(formatted)
                            }
                        }
                    }
                } else {
                    print(" \(TerminalColor.green)✓\(TerminalColor.reset)\(duration)")
                }
            }
            self.currentTool = nil
            self.isThinking = true // Agent is thinking again after tool completion

        case let .assistantMessage(content):
            if self.outputMode == .verbose {
                print("\n💭 Assistant: \(content)")
            } else if self.outputMode == .compact {
                // Stop animation on first content if still running
                if self.isThinking && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.ghostAnimator.stop()
                    self.isThinking = false
                    self.hasReceivedContent = true
                    // Print newline after animation to start content on new line
                    print()
                }

                // In compact mode, show all streaming text directly
                print(content, terminator: "")
                fflush(stdout)
            }

        case let .thinkingMessage(content):
            if self.outputMode == .verbose {
                print("\n🤔 Thinking: \(content)")
            } else if self.outputMode == .compact {
                // Stop animation when thinking content arrives
                if self.isThinking {
                    self.ghostAnimator.stop()
                    self.isThinking = false
                    // Print thinking prefix once
                    print("\n\(TerminalColor.cyan)💭 Thinking:\(TerminalColor.reset) ", terminator: "")
                }

                // Show thinking content
                print(content, terminator: "")
                fflush(stdout)
            }

        case let .error(message):
            self.ghostAnimator.stop() // Stop animation on error
            print("\n\(TerminalColor.red)❌ Error: \(message)\(TerminalColor.reset)")

        case .completed:
            self.ghostAnimator.stop() // Ensure animation is stopped
            // Final summary is handled by the main execution flow
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
            guard let toolEnum = PeekabooTool(from: tool) else {
                return
            }

            switch toolEnum {
            case .shell:
                // Show command output if present
                if let output = json["output"] as? String, !output.isEmpty {
                    print(
                        "   \(TerminalColor.gray)Output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))\(TerminalColor.reset)"
                    )
                }
                // Show error message with exit code on same line
                let exitCode = json["exitCode"] as? Int ?? 0
                let errorMsg = error.trimmingCharacters(in: .whitespacesAndNewlines)
                print(
                    "   \(TerminalColor.red)Error (Exit code: \(exitCode)): \(errorMsg)\(TerminalColor.reset)"
                )
            default:
                // For other tools, just show the error
                print("   \(TerminalColor.red)\(error)\(TerminalColor.reset)")
            }
        }
    }

    private func compactToolSummary(_ toolName: String, _ args: [String: Any]) -> String {
        guard let tool = PeekabooTool(from: toolName) else {
            return toolName.replacingOccurrences(of: "_", with: " ").capitalized
        }

        switch tool {
        case .see:
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

        case .screenshot:
            if let mode = args["mode"] as? String {
                return mode == "window" ? "active window" : mode
            } else if let app = args["app"] as? String {
                return app
            }
            return "full screen"

        case .windowCapture:
            if let app = args["appName"] as? String {
                return app
            }
            return "active window"

        case .click:
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

        case .type:
            if let text = args["text"] as? String {
                // Show full text in compact mode, even if it's long
                return "'\(text)'"
            }
            return ""

        case .scroll:
            if let direction = args["direction"] as? String {
                if let amount = args["amount"] as? Int {
                    return "\(direction) \(amount)px"
                }
                return direction
            }
            return "down"

        case .focusWindow:
            if let app = args["appName"] as? String {
                return app
            }
            return "active window"

        case .resizeWindow:
            var parts: [String] = []
            if let app = args["appName"] as? String {
                parts.append(app)
            }
            if let width = args["width"], let height = args["height"] {
                parts.append("to \(width)x\(height)")
            }
            return parts.isEmpty ? "active window" : parts.joined(separator: " ")

        case .launchApp:
            if let app = args["appName"] as? String {
                return app
            } else if let name = args["name"] as? String {
                return name
            }
            return "application"

        case .hotkey:
            // Check for the complete keys string first (includes modifiers and key)
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
            } else if let key = args["key"] as? String {
                // Fallback to key + modifiers format
                var parts: [String] = []
                if let modifiers = args["modifiers"] as? [String], !modifiers.isEmpty {
                    for mod in modifiers {
                        switch mod.lowercased() {
                        case "command": parts.append("⌘")
                        case "shift": parts.append("⇧")
                        case "option": parts.append("⌥")
                        case "control": parts.append("⌃")
                        default: parts.append(mod)
                        }
                    }
                }
                parts.append(key)
                return parts.joined()
            }
            return "keyboard shortcut"

        case .shell:
            var parts: [String] = []
            if let command = args["command"] as? String {
                // Show full command in compact mode
                parts.append("'\(command)'")
            } else {
                parts.append("command")
            }

            // Only show timeout if different from default (30s)
            if let timeout = args["timeout"] as? Double, timeout != 30.0 {
                parts.append("(timeout: \(Int(timeout))s)")
            }

            return parts.joined(separator: " ")

        case .listApps, .listWindows, .listElements, .listMenus, .listDock, .listSpaces:
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

        case .menuClick:
            var parts: [String] = []
            if let app = args["app"] as? String {
                parts.append(app)
            }
            if let menuPath = args["menuPath"] as? String {
                parts.append("→ \(menuPath)")
            } else if let path = args["path"] as? String {
                parts.append("→ \(path)")
            }
            return parts.isEmpty ? "menu item" : parts.joined(separator: " ")

        case .findElement:
            if let text = args["text"] as? String {
                return "'\(text)'"
            } else if let elementId = args["elementId"] as? String {
                return "element \(elementId)"
            }
            return "UI element"

        case .focused:
            return "current element"

        case .dockLaunch:
            if let app = args["appName"] as? String {
                return app
            }
            return "dock item"

        case .switchSpace:
            if let to = args["to"] as? Int {
                return "to space \(to)"
            }
            return "space"

        case .moveWindowToSpace:
            var parts: [String] = []
            if let app = args["app"] as? String {
                parts.append(app)
            }
            if let to = args["to"] as? Int {
                parts.append("to space \(to)")
            }
            return parts.isEmpty ? "window to space" : parts.joined(separator: " ")

        case .wait:
            if let seconds = args["seconds"] as? Double {
                return "\(seconds)s"
            } else if let seconds = args["seconds"] as? Int {
                return "\(seconds)s"
            }
            return "1s"

        case .dialogClick:
            var parts: [String] = []
            if let button = args["button"] as? String {
                parts.append("'\(button)'")
            }
            if let window = args["window"] as? String {
                parts.append("in \(window)")
            }
            return parts.isEmpty ? "dialog button" : parts.joined(separator: " ")

        case .dialogInput:
            var parts: [String] = []
            if let text = args["text"] as? String {
                let truncated = text.count > 20 ? String(text.prefix(20)) + "..." : text
                parts.append("'\(truncated)'")
            }
            if let field = args["field"] as? String {
                parts.append("in '\(field)'")
            }
            return parts.isEmpty ? "text input" : parts.joined(separator: " ")

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

        guard let tool = PeekabooTool(from: toolName) else {
            return ""
        }

        switch tool {
        case .see, .screenshot:
            if let app = args["app"] as? String {
                return app
            } else if let mode = args["mode"] as? String {
                return mode
            }
            return "screen"

        case .click:
            if let target = args["target"] as? String {
                return String(target.prefix(20))
            } else if let element = args["element"] as? String {
                return element
            }
            return "element"

        case .type:
            if let text = args["text"] as? String {
                return "'\(String(text.prefix(15)))...'"
            }
            return "text"

        case .launchApp:
            if let app = args["appName"] as? String {
                return app
            }
            return "app"

        case .shell:
            if let cmd = args["command"] as? String {
                return String(cmd.prefix(20))
            }
            return "command"

        default:
            return self.compactToolSummary(toolName, args)
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
