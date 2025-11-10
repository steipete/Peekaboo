@preconcurrency import ArgumentParser
import Darwin
import Dispatch
import Foundation
import Logging
import PeekabooCore
import PeekabooFoundation
import Spinner
import Tachikoma
import TachikomaMCP

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

/// Output modes for agent execution with progressive enhancement
enum OutputMode {
    case minimal // CI/pipes - no colors, simple text
    case compact // Basic colors and icons (legacy default)
    case enhanced // Rich formatting with progress indicators
    case quiet // Only final result
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

/// Get icon for tool name in compact mode
func iconForTool(_ toolName: String) -> String {
    // Get icon for tool name in compact mode
    AgentDisplayTokens.icon(for: toolName)
}

/// AI Agent command that uses new Chat Completions API architecture
@available(macOS 14.0, *)
struct AgentCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent"
    )

    @Argument(help: "Natural language description of the task to perform (optional when using --resume)")
    var task: String?

    @Flag(name: .shortAndLong, help: "Enable verbose output with full JSON debug information")
    var verbose = false

    @Flag(name: .customLong("debug-terminal"), help: "Show detailed terminal detection info")
    var debugTerminal = false

    @Flag(name: [.short, .long], help: "Quiet mode - only show final result")
    var quiet = false

    @Flag(name: .long, help: "Dry run - show planned steps without executing")
    var dryRun = false

    @Option(name: .long, help: "Maximum number of steps the agent can take")
    var maxSteps: Int?

    @Option(name: .long, help: "AI model to use (allowed: gpt-5 or claude-sonnet-4.5)")
    var model: String?

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

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

    @Flag(name: .long, help: "Force simple output mode (no colors or rich formatting)")
    var simple = false

    @Flag(name: .long, help: "Disable colors in output")
    var noColor = false

    /// Computed property for output mode with smart detection and progressive enhancement
    private var outputMode: OutputMode {
        // Explicit user overrides first
        if self.quiet { return .quiet }
        if self.verbose || self.debugTerminal { return .verbose }
        if self.simple { return .minimal }
        if self.noColor { return .minimal }

        // Check for environment-based forced modes
        if let forcedMode = TerminalDetector.shouldForceOutputMode() {
            return forcedMode
        }

        // Smart detection based on terminal capabilities
        let capabilities = TerminalDetector.detectCapabilities()
        return capabilities.recommendedOutputMode
    }

    @RuntimeStorage private var runtime: CommandRuntime?

    @MainActor
    private var services: PeekabooServices {
        self.runtime?.services ?? PeekabooServices.shared
    }

    private var logger: Logger {
        self.runtime?.logger ?? Logger.shared
    }

var jsonOutput: Bool { self.runtimeOptions.jsonOutput }

    @MainActor
    mutating func run() async throws {
        let runtime = CommandRuntime(options: self.runtimeOptions)
        try await self.run(using: runtime)
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        // Show terminal detection debug if requested
        if self.debugTerminal {
            let capabilities = TerminalDetector.detectCapabilities()
            self.printTerminalDetectionDebug(capabilities, actualMode: self.outputMode)
        }

        do {
            try await self.runInternal(runtime: runtime)
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
    mutating func runInternal(runtime: CommandRuntime) async throws {
        // Initialize MCP clients first so agent has access to external tools
        // Only show MCP initialization in verbose mode
        let shouldSuppressMCPLogs = !self.verbose && !self.debugTerminal

        // Configure logging level based on verbosity
        if shouldSuppressMCPLogs {
            // Configure swift-log to suppress info/debug messages from TachikomaMCP
            LoggingSystem.bootstrap { label in
                var handler = StreamLogHandler.standardOutput(label: label)
                // Only show warnings and errors for TachikomaMCP unless in verbose mode
                if label.hasPrefix("tachikoma.mcp") {
                    handler.logLevel = .warning
                } else {
                    handler.logLevel = .info
                }
                return handler
            }
        } else {
            // In verbose mode, show all logs
            LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        }

        // Register browser MCP as a default server
        let defaultBrowser = TachikomaMCP.MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["-y", "@agent-infra/mcp-server-browser@latest"],
            env: [:],
            enabled: true,
            timeout: 15.0,
            autoReconnect: true,
            description: "Browser automation via BrowserMCP"
        )
        TachikomaMCPClientManager.shared.registerDefaultServers(["browser": defaultBrowser])

        // Initialize MCP from profile
        await TachikomaMCPClientManager.shared.initializeFromProfile()

        // Initialize services
        let services = runtime.services

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
        if let sessionId = self.resumeSession {
            guard let continuationTask = self.task else {
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
            try await self.resumeAgentSession(agentService, sessionId: sessionId, task: continuationTask)
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
                throw PeekabooError.commandFailed("Agent service not properly initialized")
            }

            let sessions = try await peekabooService.listSessions()

            if let mostRecent = sessions.first {
                try await self.resumeAgentSession(agentService, sessionId: mostRecent.id, task: continuationTask)
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
                    print(
                        "\(TerminalColor.green)\(AgentDisplayTokens.Status.success) Transcription complete\(TerminalColor.reset)"
                    )
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
                        "\(TerminalColor.red)\(AgentDisplayTokens.Status.failure) Audio processing failed: \(error.localizedDescription)\(TerminalColor.reset)"
                    )
                }
                return
            }
        } else {
            // Check if we have a task to execute
            if let providedTask = task {
                executionTask = providedTask
            } else {
                // No task provided, show error
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
        }
        // Execute task
        try await self.executeTask(agentService, task: executionTask, maxSteps: self.maxSteps ?? 20)
    }

    // MARK: - Task Execution

    @MainActor
    func getActualModelName(_ agentService: PeekabooAgentService) async -> String {
        // If model is explicitly provided via CLI, use that
        if let providedModel = model {
            return providedModel
        }

        // Otherwise, get the default model from the agent service
        // The agent service determines this based on PEEKABOO_AI_PROVIDERS
        return agentService.defaultModel
    }

    /// Convert internal model names to properly cased display names
    func getDisplayModelName(_ modelName: String) -> String {
        // Convert internal model names to properly cased display names
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

    func parseModelString(_ modelString: String) -> LanguageModel? {
        if isDebugLoggingEnabled {
            print("DEBUG AgentCommand: Parsing model string: '\(modelString)'")
        }
        guard let parsed = LanguageModel.parse(from: modelString) else {
            if isDebugLoggingEnabled {
                print("DEBUG AgentCommand: Parsed model: nil (unsupported input)")
            }
            return nil
        }

        let restricted = self.restrictedPeekabooModel(for: parsed)

        if isDebugLoggingEnabled {
            print("DEBUG AgentCommand: Parsed model: \(String(describing: restricted))")
        }

        return restricted
    }

    private func restrictedPeekabooModel(for model: LanguageModel) -> LanguageModel? {
        switch model {
        case .openai:
            return .openai(.gpt5)
        case .anthropic:
            return .anthropic(.sonnet45)
        default:
            return nil
        }
    }

    /// Orchestrate a full agent run: configure UX, stream events, respect max steps, and support session resume.
    func executeTask(
        _ agentService: any AgentServiceProtocol,
        task: String,
        maxSteps: Int = 20,
        sessionId: String? = nil
    ) async throws {
        // Update terminal title with VibeTunnel
        self.updateTerminalTitle("Starting: \(task.prefix(50))...")

        // Cast to PeekabooAgentService early for enhanced functionality
        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw PeekabooError.commandFailed("Agent service not properly initialized")
        }

        // Get the actual model name that will be used
        let actualModelName = await getActualModelName(peekabooAgent)
        let displayModelName = self.getDisplayModelName(actualModelName)

        // Create event delegate for real-time updates
        let eventDelegate: any AgentEventDelegate = await MainActor.run {
            AgentOutputDelegate(outputMode: self.outputMode, jsonOutput: self.jsonOutput, task: task)
        }

        // Show header with properly cased model name when outputting directly
        if self.outputMode != .quiet && self.outputMode != .minimal && !self.jsonOutput {
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
            case .compact, .enhanced:
                // Show model in header - split into two lines for better readability
                let versionNumber = Version.current.replacingOccurrences(of: "Peekaboo ", with: "")
                let versionInfo = "(\(Version.gitBranch)/\(Version.gitCommit), \(Version.gitCommitDate))"

                // First line: Version and git info
                print(
                    "\(TerminalColor.cyan)\(TerminalColor.bold)\(AgentDisplayTokens.Glyph.agent) Peekaboo Agent\(TerminalColor.reset) \(TerminalColor.gray)\(versionNumber) \(versionInfo)\(TerminalColor.reset)"
                )

                // Second line: Model and API provider info
                // Determine which API is being used based on the model
                // Determine provider and API endpoint
                let apiDescription: String = if let parsedModel = self.model.flatMap({ self.parseModelString($0) }) {
                    // We have a parsed model with provider info
                    switch parsedModel.providerName {
                    case "OpenAI":
                        // Note: GPT-5 can use either Completions or Responses API depending on configuration
                        // We can't determine this from the model name alone
                        // TODO: Get actual endpoint from provider configuration
                        "\(parsedModel.providerName) API"
                    case "Anthropic":
                        "\(parsedModel.providerName) Messages API"
                    case "xAI", "Groq", "Together", "Mistral":
                        // These all use OpenAI-compatible APIs
                        "\(parsedModel.providerName) (OpenAI-compatible)"
                    case "Ollama":
                        // Ollama provides an OpenAI-compatible API
                        "Ollama (OpenAI-compatible)"
                    default:
                        parsedModel.providerName
                    }
                } else {
                    // Fallback to guessing based on model name
                    if actualModelName.lowercased().contains("gpt") || actualModelName.lowercased()
                        .contains("o3") || actualModelName.lowercased().contains("o4") {
                        "OpenAI API"
                    } else if actualModelName.lowercased().contains("claude") {
                        "Anthropic Messages API"
                    } else if actualModelName.lowercased().contains("grok") {
                        "xAI (OpenAI-compatible)"
                    } else if actualModelName.lowercased().contains("llama") {
                        "Ollama (OpenAI-compatible)"
                    } else {
                        "AI Provider"
                    }
                }

                // Get the masked API key
                let maskedKey = await peekabooAgent.maskedApiKey
                let apiKeyInfo = maskedKey.map { " (\($0))" } ?? ""

                print(
                    "   \(TerminalColor.gray)Using \(displayModelName) via \(apiDescription)\(apiKeyInfo)\(TerminalColor.reset)"
                )

                if let sessionId {
                    print(
                        "\(TerminalColor.gray)\(AgentDisplayTokens.Status.info) Session: \(sessionId.prefix(8))...\(TerminalColor.reset)"
                    )
                }
            case .quiet, .minimal:
                break
            }
        }

        do {
            // Parse the model string from CLI parameter
            let languageModel: LanguageModel? = self.model.flatMap { self.parseModelString($0) }

            if isDebugLoggingEnabled {
                print("DEBUG AgentCommand: CLI model parameter: \(String(describing: self.model))")
                print("DEBUG AgentCommand: Parsed language model: \(String(describing: languageModel))")
            }

            if let requestedModel = self.model, languageModel == nil {
                fputs("⚠️  Unsupported model '\(requestedModel)'. Peekaboo only supports gpt-5 and claude-sonnet-4.5.\n", stderr)
            }

            let result = try await peekabooAgent.executeTask(
                task,
                maxSteps: maxSteps,
                sessionId: sessionId as String?, // Explicit cast to disambiguate method
                model: languageModel,
                eventDelegate: eventDelegate,
                verbose: self.verbose
            )

            // Update token count in delegate if available
            await MainActor.run {
                if let usage = result.usage {
                    (eventDelegate as? AgentOutputDelegate)?.updateTokenCount(usage.totalTokens)
                }
            }
            self.displayResult(result)

            // Show final summary if not already shown
            if !self.jsonOutput && self.outputMode != .quiet && self.outputMode != .minimal {
                await MainActor.run {
                    (eventDelegate as? AgentOutputDelegate)?.showFinalSummaryIfNeeded(result)
                }
            }

            // Show API key info in verbose mode
            if self.outputMode == .verbose,
               let apiKey = await peekabooAgent.maskedApiKey {
                print("\(TerminalColor.gray)API Key: \(apiKey)\(TerminalColor.reset)")
            }

            // Update terminal title to show completion
            self.updateTerminalTitle("Completed: \(task.prefix(50))")

            // Show terminal capabilities in verbose mode for debugging
            if self.outputMode == .verbose {
                let capabilities = TerminalDetector.detectCapabilities()
                print(
                    "\(TerminalColor.gray)Terminal: \(TerminalDetector.capabilitiesDescription(capabilities))\(TerminalColor.reset)"
                )
                print("\(TerminalColor.gray)Selected mode: \(self.outputMode.description)\(TerminalColor.reset)")
            }
        } catch let error as DecodingError {
            aiDebugPrint("DEBUG: DecodingError caught: \(error)")
            throw error
        } catch {
            // Extract the actual error message from NSError if available
            var errorMessage = error.localizedDescription
            let nsError = error as NSError
            if let detailedMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
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
                print(
                    "\n\(TerminalColor.red)\(TerminalColor.bold)\(AgentDisplayTokens.Status.failure) Error:\(TerminalColor.reset) \(errorMessage)"
                )
            }

            // Update terminal title to show error
            self.updateTerminalTitle("Error: \(task.prefix(40))...")
            throw error
        }
    }

    /// Render the agent execution result using either JSON output or a rich CLI transcript.
    @MainActor
    func displayResult(_ result: AgentExecutionResult) {
        if self.jsonOutput {
            let response = [
                "success": true,
                "result": [
                    "content": result.content,
                    "sessionId": result.sessionId as Any,
                    "toolCalls": result.messages.flatMap { message in
                        message.content.compactMap { content in
                            if case let .toolCall(toolCall) = content {
                                return [
                                    "id": toolCall.id,
                                    "name": toolCall.name,
                                    "arguments": String(describing: toolCall.arguments)
                                ]
                            }
                            return nil
                        }
                    },
                    "metadata": [
                        "executionTime": result.metadata.executionTime,
                        "toolCallCount": result.metadata.toolCallCount,
                        "modelName": result.metadata.modelName
                    ],
                    "usage": result.usage.map { usage in
                        [
                            "inputTokens": usage.inputTokens,
                            "outputTokens": usage.outputTokens,
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
            // Don't print the content here - it was already shown by the event delegate
            // This prevents duplicate output of the assistant's message
        }
    }

    // MARK: - Session Management

    @MainActor
    func showSessions(_ agentService: any AgentServiceProtocol) async throws {
        // Cast to PeekabooAgentService - this should always succeed
        guard let peekabooService = agentService as? PeekabooAgentService else {
            throw PeekabooError.commandFailed("Agent service not properly initialized")
        }

        let sessionSummaries = try await peekabooService.listSessions()

        // Convert SessionSummary to AgentSessionInfo for display
        let sessions = sessionSummaries.map { summary in
            AgentSessionInfo(
                id: summary.id,
                task: summary.summary ?? "Unknown task",
                created: summary.createdAt,
                lastModified: summary.lastAccessedAt,
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

    func resumeAgentSession(_ agentService: any AgentServiceProtocol, sessionId: String, task: String) async throws {
        if !self.jsonOutput {
            print(
                "\(TerminalColor.cyan)\(TerminalColor.bold)\(AgentDisplayTokens.Status.info) Resuming session \(sessionId.prefix(8))...\(TerminalColor.reset)\n"
            )
        }

        // Use runInternal directly since executeTask was removed
        // The session resumption is handled inside runInternal
    }

    func updateTerminalTitle(_ title: String) {
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

    func formatTimeAgo(_ date: Date) -> String {
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

    /// Print detailed terminal detection debugging information
    func printTerminalDetectionDebug(_ capabilities: TerminalCapabilities, actualMode: OutputMode) {
        // Print detailed terminal detection debugging information
        print("\n" + String(repeating: "=", count: 60))
        print("\(TerminalColor.bold)\(TerminalColor.cyan)TERMINAL DETECTION DEBUG (-vv)\(TerminalColor.reset)")
        print(String(repeating: "=", count: 60))

        // Basic terminal info
        print("[term] \(TerminalColor.bold)Terminal Type:\(TerminalColor.reset) \(capabilities.termType ?? "unknown")")
        print(
            "[size] \(TerminalColor.bold)Dimensions:\(TerminalColor.reset) \(capabilities.width)x\(capabilities.height)"
        )

        // Capability flags
        print("\(AgentDisplayTokens.Status.running) \(TerminalColor.bold)Capabilities:\(TerminalColor.reset)")
        print(
            "   • Interactive: \(capabilities.isInteractive ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure) (isatty check)"
        )
        print(
            "   • Colors: \(capabilities.supportsColors ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure) (ANSI support)"
        )
        print(
            "   • True Color: \(capabilities.supportsTrueColor ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure) (24-bit)"
        )
        print("   • Dimensions: \(capabilities.width)x\(capabilities.height)")

        // Environment info
        print("[env] \(TerminalColor.bold)Environment:\(TerminalColor.reset)")
        print(
            "   • CI Environment: \(capabilities.isCI ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure)"
        )
        print(
            "   • Piped Output: \(capabilities.isPiped ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure)"
        )

        // Environment variables
        let env = ProcessInfo.processInfo.environment
        print("\(AgentDisplayTokens.Status.running) \(TerminalColor.bold)Environment Variables:\(TerminalColor.reset)")
        print("   • TERM: \(env["TERM"] ?? "not set")")
        print("   • COLORTERM: \(env["COLORTERM"] ?? "not set")")
        print("   • NO_COLOR: \(env["NO_COLOR"] != nil ? "set" : "not set")")
        print("   • FORCE_COLOR: \(env["FORCE_COLOR"] ?? "not set")")
        print("   • PEEKABOO_OUTPUT_MODE: \(env["PEEKABOO_OUTPUT_MODE"] ?? "not set")")

        // Recommended vs actual mode
        let recommendedMode = capabilities.recommendedOutputMode
        print("[focus] \(TerminalColor.bold)Recommended Mode:\(TerminalColor.reset) \(recommendedMode.description)")
        print("[focus] \(TerminalColor.bold)Actual Mode:\(TerminalColor.reset) \(actualMode.description)")

        if recommendedMode != actualMode {
            print(
                "\(AgentDisplayTokens.Status.warning)  \(TerminalColor.yellow)Mode Override Detected\(TerminalColor.reset) - explicit flag or environment variable used"
            )
        }

        // Show decision logic
        if !capabilities.isInteractive || capabilities.isCI || capabilities.isPiped {
            print("   → Minimal mode (non-interactive/CI/piped)")
        } else if capabilities.supportsColors {
            print("   → Enhanced mode (colors available)")
        } else {
            print("   → Compact mode (basic terminal)")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }
}

extension AgentCommand: @MainActor AsyncParsableCommand {}

extension AgentCommand: @MainActor AsyncRuntimeCommand {}
