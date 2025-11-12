import Commander
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

/// Get icon for tool name in compact mode
func iconForTool(_ toolName: String) -> String {
    AgentDisplayTokens.icon(for: toolName)
}

/// AI Agent command that uses new Chat Completions API architecture
@available(macOS 14.0, *)
struct AgentCommand: RuntimeOptionsConfigurable {
    static let commandDescription = CommandDescription(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent"
    )

    @Argument(help: "Natural language description of the task to perform (optional when using --resume)")
    var task: String?

    @Flag(name: .customLong("debug-terminal"), help: "Show detailed terminal detection info")
    var debugTerminal = false

    @Flag(names: [.short("q"), .long], help: "Quiet mode - only show final result")
    var quiet = false

    @Flag(name: .long, help: "Dry run - show planned steps without executing")
    var dryRun = false

    @Option(name: .long, help: "Maximum number of steps the agent can take")
    var maxSteps: Int?

    @Option(name: .long, help: "AI model to use (allowed: gpt-5 or claude-sonnet-4.5)")
    var model: String?
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
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    @MainActor
    private var services: PeekabooServices {
        self.resolvedRuntime.services
    }

    private var logger: Logger {
        self.resolvedRuntime.logger
    }

    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

    var verbose: Bool { self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose }
}

@available(macOS 14.0, *)
extension AgentCommand {
    @MainActor
    mutating func run() async throws {
        let runtime = CommandRuntime(options: CommandRuntimeOptions())
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
        if self.isAgentDisabled() {
            self.emitAgentUnavailableMessage()
            return
        }

        let services = runtime.services

        guard let agentService = services.agent else {
            self.emitAgentUnavailableMessage()
            return
        }

        if self.listSessions {
            try await self.showSessions(agentService)
            return
        }

        guard self.hasConfiguredAIProvider(configuration: services.configuration) else {
            self.emitAgentUnavailableMessage()
            return
        }

        let shouldSuppressMCPLogs = !self.verbose && !self.debugTerminal
        self.configureLogging(suppressingMCPLogs: shouldSuppressMCPLogs)
        await self.initializeMCP()

        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw PeekabooError.commandFailed("Agent service not properly initialized")
        }

        guard try await self.ensureAgentHasCredentials(peekabooAgent) else {
            return
        }

        if try await self.handleSessionResumption(agentService) {
            return
        }

        guard let executionTask = try await self.buildExecutionTask() else {
            return
        }

        try await self.executeAgentTask(agentService, task: executionTask, maxSteps: self.maxSteps ?? 20)
    }

    private func isAgentDisabled() -> Bool {
        let value = ProcessInfo.processInfo.environment["PEEKABOO_DISABLE_AGENT"]?.lowercased()
        return value == "1" || value == "true"
    }

    private func configureLogging(suppressingMCPLogs: Bool) {
        if suppressingMCPLogs {
            LoggingSystem.bootstrap { label in
                var handler = StreamLogHandler.standardOutput(label: label)
                if label.hasPrefix("tachikoma.mcp") {
                    handler.logLevel = .warning
                } else {
                    handler.logLevel = .info
                }
                return handler
            }
        } else {
            LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        }
    }

    private func initializeMCP() async {
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
        await TachikomaMCPClientManager.shared.initializeFromProfile()
    }

    private func ensureAgentHasCredentials(_ peekabooAgent: PeekabooAgentService) async throws -> Bool {
        let hasCredential = await peekabooAgent.maskedApiKey != nil
        if !hasCredential {
            self.emitAgentUnavailableMessage()
        }
        return hasCredential
    }

    private func handleSessionResumption(_ agentService: any AgentServiceProtocol) async throws -> Bool {
        if let sessionId = self.resumeSession {
            guard let continuationTask = self.task else {
                self.printMissingTaskError(
                    message: "Task argument required when resuming session",
                    usage: "Usage: peekaboo agent --resume-session <session-id> \"<continuation-task>\""
                )
                return true
            }
            try await self.resumeAgentSession(agentService, sessionId: sessionId, task: continuationTask)
            return true
        }

        if self.resume {
            guard let continuationTask = self.task else {
                self.printMissingTaskError(
                    message: "Task argument required when resuming",
                    usage: "Usage: peekaboo agent --resume \"<continuation-task>\""
                )
                return true
            }

            guard let peekabooService = agentService as? PeekabooAgentService else {
                throw PeekabooError.commandFailed("Agent service not properly initialized")
            }

            let sessions = try await peekabooService.listSessions()

            if let mostRecent = sessions.first {
                try await self.resumeAgentSession(agentService, sessionId: mostRecent.id, task: continuationTask)
            } else {
                if self.jsonOutput {
                    let error = ["success": false, "error": "No sessions found to resume"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: No sessions found to resume\(TerminalColor.reset)")
                }
            }
            return true
        }

        return false
    }

    private func printMissingTaskError(message: String, usage: String) {
        if self.jsonOutput {
            let error = ["success": false, "error": message] as [String: Any]
            if let jsonData = try? JSONSerialization.data(withJSONObject: error, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("{\"success\":false,\"error\":\"\(message)\"}")
            }
        } else {
            print("\(TerminalColor.red)Error: \(message)\(TerminalColor.reset)")
            if !usage.isEmpty {
                print(usage)
            }
        }
    }

    private func buildExecutionTask() async throws -> String? {
        if self.audio || self.audioFile != nil {
            return try await self.processAudioInput()
        }

        guard let providedTask = self.task else {
            self.printMissingTaskError(message: "Task argument is required", usage: "")
            return nil
        }
        return providedTask
    }

    private func processAudioInput() async throws -> String? {
        self.logAudioStartMessage()
        let audioService = self.services.audioInput

        do {
            let transcript = try await self.transcribeAudio(using: audioService)
            self.logTranscriptionSuccess(transcript)
            return self.composeExecutionTask(with: transcript)
        } catch {
            self.logAudioError(error)
            return nil
        }
    }

    private func logAudioStartMessage() {
        guard !self.jsonOutput && !self.quiet else { return }
        if let audioPath = self.audioFile {
            print("\(TerminalColor.cyan)🎙️ Processing audio file: \(audioPath)\(TerminalColor.reset)")
        } else {
            let recordingMessage = [
                "\(TerminalColor.cyan)🎙️ Starting audio recording...",
                " (Press Ctrl+C to stop)\(TerminalColor.reset)"
            ].joined()
            print(recordingMessage)
        }
    }

    private func transcribeAudio(using audioService: AudioInputService) async throws -> String {
        if let audioPath = self.audioFile {
            let url = URL(fileURLWithPath: audioPath)
            return try await audioService.transcribeAudioFile(url)
        } else {
            try await audioService.startRecording()
            return try await self.captureMicrophoneAudio(using: audioService)
        }
    }

    private func captureMicrophoneAudio(using audioService: AudioInputService) async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
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
            }
        } onCancel: {
            Task { @MainActor in
                _ = try? await audioService.stopRecording()
            }
        }
    }

    private func logTranscriptionSuccess(_ transcript: String) {
        guard !self.jsonOutput && !self.quiet else { return }
        let message = [
            "\(TerminalColor.green)\(AgentDisplayTokens.Status.success) Transcription complete",
            "\(TerminalColor.reset)"
        ].joined()
        print(message)
        print("\(TerminalColor.gray)Transcript: \(transcript.prefix(100))...\(TerminalColor.reset)")
    }

    private func composeExecutionTask(with transcript: String) -> String {
        guard let providedTask = self.task else {
            return transcript
        }
        return "\(providedTask)\n\nAudio transcript:\n\(transcript)"
    }

    private func logAudioError(_ error: any Error) {
        if self.jsonOutput {
            let errorObj = [
                "success": false,
                "error": "Audio processing failed: \(error.localizedDescription)"
            ] as [String: Any]
            if let jsonData = try? JSONSerialization.data(withJSONObject: errorObj, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("{\"success\":false,\"error\":\"Audio processing failed\"}")
            }
        } else {
            let failurePrefix = [
                "\(TerminalColor.red)\(AgentDisplayTokens.Status.failure)",
                " Audio processing failed: \(error.localizedDescription)"
            ].joined()
            let audioErrorMessage = [failurePrefix, "\(TerminalColor.reset)"].joined()
            print(audioErrorMessage)
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
        guard let peekabooService = agentService as? PeekabooAgentService else {
            throw PeekabooError.commandFailed("Agent service not properly initialized")
        }

        let sessionSummaries = try await peekabooService.listSessions()
        let sessions = sessionSummaries.map { summary in
            AgentSessionInfo(
                id: summary.id,
                task: summary.summary ?? "Unknown task",
                created: summary.createdAt,
                lastModified: summary.lastAccessedAt,
                messageCount: summary.messageCount
            )
        }

        guard !sessions.isEmpty else {
            self.printNoAgentSessions()
            return
        }

        if self.jsonOutput {
            self.printSessionsJSON(sessions)
        } else {
            self.printSessionsList(sessions)
        }
    }

    private func printNoAgentSessions() {
        if self.jsonOutput {
            let response = ["success": true, "sessions": []] as [String: Any]
            let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            print(String(data: jsonData ?? Data(), encoding: .utf8) ?? "{}")
        } else {
            print("No agent sessions found.")
        }
    }

    private func printSessionsJSON(_ sessions: [AgentSessionInfo]) {
        let sessionData = sessions.map { session in
            [
                "id": session.id,
                "createdAt": ISO8601DateFormatter().string(from: session.created),
                "updatedAt": ISO8601DateFormatter().string(from: session.lastModified),
                "messageCount": session.messageCount
            ]
        }
        let response = ["success": true, "sessions": sessionData] as [String: Any]
        if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted) {
            print(String(data: jsonData, encoding: .utf8) ?? "{}")
        }
    }

    private func printSessionsList(_ sessions: [AgentSessionInfo]) {
        let headerLine = [
            "\(TerminalColor.cyan)\(TerminalColor.bold)Agent Sessions:\(TerminalColor.reset)",
            "\n"
        ].joined()
        print(headerLine)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        for (index, session) in sessions.prefix(10).enumerated() {
            self.printSessionLine(index: index, session: session, dateFormatter: dateFormatter)
            if index < sessions.count - 1 {
                print()
            }
        }

        if sessions.count > 10 {
            print([
                "\n",
                "\(TerminalColor.dim)... and \(sessions.count - 10) more sessions\(TerminalColor.reset)"
            ].joined())
        }

        let resumeHintLine = [
            "\n",
            "\(TerminalColor.dim)To resume: peekaboo agent --resume <session-id>",
            " \"<continuation>\"\(TerminalColor.reset)"
        ].joined()
        print(resumeHintLine)
    }

    private func printSessionLine(index: Int, session: AgentSessionInfo, dateFormatter: DateFormatter) {
        let timeAgo = formatTimeAgo(session.lastModified)
        let sessionLine = [
            "\(TerminalColor.blue)\(index + 1).\(TerminalColor.reset)",
            " ",
            "\(TerminalColor.bold)\(session.id.prefix(8))\(TerminalColor.reset)"
        ].joined()
        print(sessionLine)
        print("   Messages: \(session.messageCount)")
        print("   Last activity: \(timeAgo)")
    }

    func resumeAgentSession(_ agentService: any AgentServiceProtocol, sessionId: String, task: String) async throws {
        if !self.jsonOutput {
            let resumingLine = [
                "\(TerminalColor.cyan)\(TerminalColor.bold)",
                "\(AgentDisplayTokens.Status.info)",
                " Resuming session \(sessionId.prefix(8))...",
                "\(TerminalColor.reset)",
                "\n"
            ].joined()
            print(resumingLine)
        }

        guard let peekabooService = agentService as? PeekabooAgentService else {
            throw PeekabooError.commandFailed("Agent service not properly initialized")
        }

        let delegate = self.makeEventDelegate(for: task)
        do {
            let result = try await peekabooService.resumeSession(sessionId: sessionId, eventDelegate: delegate)
            self.displayResult(result)
        } catch {
            self.printAgentExecutionError("Failed to resume session: \(error.localizedDescription)")
            throw error
        }
    }

    private func makeEventDelegate(for task: String) -> AgentOutputDelegate? {
        guard !self.jsonOutput, !self.quiet else { return nil }
        return AgentOutputDelegate(outputMode: self.outputMode, jsonOutput: self.jsonOutput, task: task)
    }

    private func printAgentExecutionError(_ message: String) {
        if self.jsonOutput {
            let error: [String: Any] = ["success": false, "error": message]
            if let jsonData = try? JSONSerialization.data(withJSONObject: error, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("{\"success\":false,\"error\":\"\(message)\"}")
            }
        } else {
            print("\(TerminalColor.red)Error: \(message)\(TerminalColor.reset)")
        }
    }

    private func executeAgentTask(
        _ agentService: any AgentServiceProtocol,
        task: String,
        maxSteps: Int
    ) async throws {
        let delegate = self.makeEventDelegate(for: task)
        do {
            let result = try await agentService.executeTask(
                task,
                maxSteps: maxSteps,
                dryRun: self.dryRun,
                eventDelegate: delegate
            )
            self.displayResult(result)
        } catch {
            self.printAgentExecutionError("Agent execution failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func printCapabilityFlag(_ label: String, supported: Bool, detail: String? = nil) {
        let status = supported ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure
        let detailSuffix = detail.map { " (\($0))" } ?? ""
        print("   • \(label): \(status)\(detailSuffix)")
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
        self.printCapabilityFlag("Interactive", supported: capabilities.isInteractive, detail: "isatty check")
        self.printCapabilityFlag("Colors", supported: capabilities.supportsColors, detail: "ANSI support")
        self.printCapabilityFlag("True Color", supported: capabilities.supportsTrueColor, detail: "24-bit")
        print("   • Dimensions: \(capabilities.width)x\(capabilities.height)")

        // Environment info
        print("[env] \(TerminalColor.bold)Environment:\(TerminalColor.reset)")
        self.printCapabilityFlag("CI Environment", supported: capabilities.isCI)
        self.printCapabilityFlag("Piped Output", supported: capabilities.isPiped)

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
            let modeOverrideLine = [
                "\(AgentDisplayTokens.Status.warning)  ",
                "\(TerminalColor.yellow)Mode Override Detected\(TerminalColor.reset)",
                " - explicit flag or environment variable used"
            ].joined()
            print(modeOverrideLine)
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

    private func hasConfiguredAIProvider(configuration: PeekabooCore.ConfigurationManager) -> Bool {
        let hasOpenAI = configuration.getOpenAIAPIKey()?.isEmpty == false
        let hasAnthropic = configuration.getAnthropicAPIKey()?.isEmpty == false
        return hasOpenAI || hasAnthropic
    }

    private func emitAgentUnavailableMessage() {
        if self.jsonOutput {
            let error = [
                "success": false,
                "error": "Agent service not available. Please set OPENAI_API_KEY environment variable."
            ] as [String: Any]
            if let jsonData = try? JSONSerialization.data(withJSONObject: error, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("{\"success\":false,\"error\":\"Agent service not available\"}")
            }
        } else {
            let errorPrefix = [
                "\(TerminalColor.red)Error: Agent service not available.",
                " Please set OPENAI_API_KEY environment variable."
            ].joined()
            let errorMessageLine = [errorPrefix, "\(TerminalColor.reset)"].joined()
            print(errorMessageLine)
        }
    }

    // MARK: - Model Parsing

    func parseModelString(_ modelString: String) -> LanguageModel? {
        let trimmed = modelString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let parsed = LanguageModel.parse(from: trimmed) else {
            return nil
        }

        switch parsed {
        case let .openai(model):
            if Self.supportedOpenAIInputs.contains(model) {
                return .openai(.gpt5)
            }
        case let .anthropic(model):
            if Self.supportedAnthropicInputs.contains(model) {
                return .anthropic(.sonnet45)
            }
        default:
            break
        }

        return nil
    }

    private static let supportedOpenAIInputs: Set<LanguageModel.OpenAI> = [
        .gpt5,
        .gpt5Pro,
        .gpt5Mini,
        .gpt5Nano,
        .gpt5Thinking,
        .gpt5ThinkingMini,
        .gpt5ThinkingNano,
        .gpt5ChatLatest,
        .gpt4o,
        .gpt4oMini,
        .gpt4oRealtime,
        .o4Mini,
    ]

    private static let supportedAnthropicInputs: Set<LanguageModel.Anthropic> = [
        .sonnet45,
        .sonnet4,
        .sonnet4Thinking,
        .opus4,
        .opus4Thinking,
    ]
}

extension AgentCommand: ParsableCommand {}

extension AgentCommand: AsyncRuntimeCommand {}
