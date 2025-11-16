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
import TauTUI

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
        abstract: "Execute complex automation tasks using the Peekaboo agent",
        discussion: """
        Launches the autonomous Peekaboo operator so it can interpret a natural-language goal,
        choose tools (see, click, type, etc.), and report progress back to you. Supports resuming
        previous sessions, dry-run planning, audio input, and JSON/quiet output modes for CI.
        """,
        usageExamples: [
            CommandUsageExample(
                command: "peekaboo agent \"Prepare the TestFlight build for review\"",
                description: "Start a brand-new session with a natural-language brief."
            ),
            CommandUsageExample(
                command: "peekaboo agent --resume",
                description: "Resume the most recent session without retyping the task."
            ),
            CommandUsageExample(
                command: "peekaboo agent --resume-session SESSION_ID --max-steps 12",
                description: "Resume a known session while capping the step budget."
            )
        ]
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

    @Option(name: .long, help: "AI model to use (allowed: gpt-5.1 or claude-sonnet-4.5)")
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

    @Flag(name: .long, help: "Start an interactive chat session")
    var chat = false

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
    private var services: any PeekabooServiceProviding {
        self.resolvedRuntime.services
    }

    private var logger: Logger {
        self.resolvedRuntime.logger
    }

    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

    var verbose: Bool { self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose }
}

@MainActor
private final class TerminalModeGuard {
    private let fd: Int32
    private var original = termios()
    private var active = false

    init?(fd: Int32 = STDIN_FILENO) {
        guard isatty(fd) == 1 else { return nil }
        guard tcgetattr(fd, &self.original) == 0 else { return nil }

        var raw = self.original
        cfmakeraw(&raw)
        raw.c_lflag |= tcflag_t(ISIG) // keep signals like Ctrl+C enabled

        guard tcsetattr(fd, TCSANOW, &raw) == 0 else { return nil }
        self.fd = fd
        self.active = true
    }

    var fileDescriptor: Int32 { self.fd }

    func restore() {
        guard self.active else { return }
        _ = tcsetattr(self.fd, TCSANOW, &self.original)
        self.active = false
    }

    @MainActor
    deinit {
        self.restore()
    }
}

private final class EscapeKeyMonitor {
    private var source: (any DispatchSourceRead)?
    private var terminalGuard: TerminalModeGuard?
    private let handler: @Sendable () async -> ()
    private let queue = DispatchQueue(label: "peekaboo.escape.monitor")

    init(handler: @escaping @Sendable () async -> ()) {
        self.handler = handler
    }

    func start() {
        guard self.source == nil else { return }
        guard let termGuard = TerminalModeGuard() else { return }

        let fd = termGuard.fileDescriptor
        let handler = self.handler
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: self.queue)

        source.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 16)
            let count = read(fd, &buffer, buffer.count)
            guard count > 0 else { return }
            if buffer[..<count].contains(0x1B) {
                Task.detached(priority: .userInitiated) {
                    await handler()
                }
            }
        }

        source.setCancelHandler {
            termGuard.restore()
        }

        source.resume()
        self.source = source
        self.terminalGuard = termGuard
    }

    func stop() {
        self.source?.cancel()
        self.source = nil
        self.terminalGuard = nil
    }
}

private enum ChatLaunchStrategy {
    case none
    case helpOnly
    case interactive(initialPrompt: String?)
}

@available(macOS 14.0, *)
extension AgentCommand {
    @MainActor
    mutating func run() async throws {
        let runtime = CommandRuntime.makeDefault()
        try await self.run(using: runtime)
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime

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

        let terminalCapabilities = TerminalDetector.detectCapabilities()
        if self.debugTerminal {
            self.printTerminalDetectionDebug(terminalCapabilities, actualMode: self.outputMode)
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
        // Warm up MCP servers off the main actor so chat can start immediately.
        Task.detached(priority: .utility) {
            await Self.initializeMCP()
        }

        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw PeekabooError.commandFailed("Agent service not properly initialized")
        }

        let requestedModel: LanguageModel?
        do {
            requestedModel = try self.validatedModelSelection()
        } catch {
            self.printAgentExecutionError(error.localizedDescription)
            return
        }

        guard await self.ensureAgentHasCredentials(peekabooAgent, requestedModel: requestedModel) else {
            return
        }

        switch self.determineChatLaunchStrategy(capabilities: terminalCapabilities) {
        case .helpOnly:
            self.printNonInteractiveChatHelp()
            return
        case let .interactive(initialPrompt):
            try await self.runChatLoop(
                peekabooAgent,
                requestedModel: requestedModel,
                initialPrompt: initialPrompt,
                capabilities: terminalCapabilities
            )
            return
        case .none:
            break
        }

        if try await self.handleSessionResumption(peekabooAgent, requestedModel: requestedModel) {
            return
        }

        guard let executionTask = try await self.buildExecutionTask() else {
            return
        }

        _ = try await self.executeAgentTask(
            peekabooAgent,
            task: executionTask,
            requestedModel: requestedModel,
            maxSteps: self.maxSteps ?? 100
        )
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

    private static func initializeMCP() async {
        if ProcessInfo.processInfo.environment["PEEKABOO_ENABLE_BROWSER_MCP"] == "1" {
            let defaultBrowser = TachikomaMCP.MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "@agent-infra/mcp-server-browser@latest"],
                env: [:],
                enabled: true,
                timeout: 60.0,
                autoReconnect: true,
                description: "Browser automation via BrowserMCP"
            )
            TachikomaMCPClientManager.shared.registerDefaultServers(["browser": defaultBrowser])
        }
        await TachikomaMCPClientManager.shared.initializeFromProfile()
    }

    private func ensureAgentHasCredentials(
        _ peekabooAgent: PeekabooAgentService,
        requestedModel: LanguageModel?
    ) async -> Bool {
        if let requestedModel {
            if self.hasCredentials(for: requestedModel) {
                return true
            }

            let providerName = self.providerDisplayName(for: requestedModel)
            let envVar = self.providerEnvironmentVariable(for: requestedModel)
            self.printAgentExecutionError(
                "Missing API key for \(providerName). Set \(envVar) and retry."
            )
            return false
        }

        let hasCredential = await peekabooAgent.maskedApiKey != nil
        if !hasCredential {
            self.emitAgentUnavailableMessage()
        }
        return hasCredential
    }

    private func handleSessionResumption(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?
    ) async throws -> Bool {
        if let sessionId = self.resumeSession {
            guard let continuationTask = self.task else {
                self.printMissingTaskError(
                    message: "Task argument required when resuming session",
                    usage: "Usage: peekaboo agent --resume-session <session-id> \"<continuation-task>\""
                )
                return true
            }
            try await self.resumeAgentSession(
                agentService,
                sessionId: sessionId,
                task: continuationTask,
                requestedModel: requestedModel
            )
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

            let sessions = try await agentService.listSessions()

            if let mostRecent = sessions.first {
                try await self.resumeAgentSession(
                    agentService,
                    sessionId: mostRecent.id,
                    task: continuationTask,
                    requestedModel: requestedModel
                )
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
    func displayResult(_ result: AgentExecutionResult, delegate: AgentOutputDelegate? = nil) {
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
        }

        delegate?.showFinalSummaryIfNeeded(result)
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

    func resumeAgentSession(
        _ agentService: PeekabooAgentService,
        sessionId: String,
        task: String,
        requestedModel: LanguageModel?
    ) async throws {
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

        let delegate = self.makeEventDelegate(for: task)
        do {
            let result = try await agentService.resumeSession(
                sessionId: sessionId,
                model: requestedModel,
                eventDelegate: delegate
            )
            self.displayResult(result, delegate: delegate)
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
        _ agentService: PeekabooAgentService,
        task: String,
        requestedModel: LanguageModel?,
        maxSteps: Int
    ) async throws -> AgentExecutionResult {
        let delegate = self.makeEventDelegate(for: task)
        do {
            let result = try await agentService.executeTask(
                task,
                maxSteps: maxSteps,
                sessionId: nil,
                model: requestedModel,
                dryRun: self.dryRun,
                eventDelegate: delegate,
                verbose: self.verbose
            )
            self.displayResult(result, delegate: delegate)
            return result
        } catch {
            self.printAgentExecutionError("Agent execution failed: \(error.localizedDescription)")
            throw error
        }
    }

    private var normalizedTaskInput: String? {
        guard let task else { return nil }
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasTaskInput: Bool {
        self.normalizedTaskInput != nil || self.audio || self.audioFile != nil
    }

    private var resolvedMaxSteps: Int { self.maxSteps ?? 100 }

    private func determineChatLaunchStrategy(capabilities: TerminalCapabilities) -> ChatLaunchStrategy {
        if self.chat {
            return .interactive(initialPrompt: self.normalizedTaskInput)
        }

        if self.hasTaskInput || self.listSessions {
            return .none
        }

        if capabilities.isInteractive && !capabilities.isPiped && !capabilities.isCI {
            return .interactive(initialPrompt: nil)
        }

        return .helpOnly
    }

    private func ensureChatModePreconditions() -> Bool {
        if self.jsonOutput {
            self.printAgentExecutionError("Interactive chat is not available while --json output is enabled.")
            return false
        }
        if self.quiet {
            self.printAgentExecutionError("Interactive chat requires visible output. Remove --quiet to continue.")
            return false
        }
        if self.dryRun {
            self.printAgentExecutionError("Interactive chat cannot run in --dry-run mode.")
            return false
        }
        if self.noCache {
            self.printAgentExecutionError("Interactive chat needs session caching. Remove --no-cache.")
            return false
        }
        if self.audio || self.audioFile != nil {
            self.printAgentExecutionError("Interactive chat currently accepts typed input only.")
            return false
        }
        return true
    }

    private func printNonInteractiveChatHelp() {
        if self.jsonOutput {
            self
                .printAgentExecutionError(
                    "Provide a task or run with --chat in an interactive terminal to start the agent chat loop."
                )
            return
        }

        let hint = [
            "Interactive chat requires a TTY.",
            "To force it from scripts: peekaboo agent --chat < prompts.txt",
            "Provide a task arg or use --chat when piping input.",
            "",
        ]
        hint.forEach { print($0) }
        self.printChatHelpMenu()
    }

    @MainActor
    private func runChatLoop(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?,
        initialPrompt: String?,
        capabilities: TerminalCapabilities
    ) async throws {
        guard self.ensureChatModePreconditions() else { return }

        if capabilities.isInteractive && !capabilities.isPiped {
            do {
                try await self.runTauTUIChatLoop(
                    agentService,
                    requestedModel: requestedModel,
                    initialPrompt: initialPrompt,
                    capabilities: capabilities
                )
                return
            } catch {
                self.printAgentExecutionError(
                    "Failed to launch TauTUI chat: \(error.localizedDescription). Falling back to basic chat.")
            }
        }

        try await self.runLineChatLoop(
            agentService,
            requestedModel: requestedModel,
            initialPrompt: initialPrompt,
            capabilities: capabilities
        )
    }

    @MainActor
    private func runLineChatLoop(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?,
        initialPrompt: String?,
        capabilities: TerminalCapabilities
    ) async throws {
        var activeSessionId: String?
        do {
            activeSessionId = try await self.initialChatSessionId(agentService)
        } catch {
            self.printAgentExecutionError(error.localizedDescription)
            return
        }

        self.printChatWelcome(
            sessionId: activeSessionId,
            modelDescription: self.describeModel(requestedModel)
        )
        self.printChatHelpIntro()

        if let seed = initialPrompt {
            try await self.performChatTurn(
                seed,
                agentService: agentService,
                sessionId: &activeSessionId,
                requestedModel: requestedModel
            )
        }

        while true {
            guard let line = self.readChatLine(prompt: "> ", capabilities: capabilities) else {
                if capabilities.isInteractive {
                    print()
                }
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "/help" {
                self.printChatHelpMenu()
                continue
            }

            do {
                try await self.performChatTurn(
                    trimmed,
                    agentService: agentService,
                    sessionId: &activeSessionId,
                    requestedModel: requestedModel
                )
            } catch {
                self.printAgentExecutionError(error.localizedDescription)
                break
            }
        }
    }

    @MainActor
    private func runAgentTurnForTUI(
        _ input: String,
        agentService: PeekabooAgentService,
        sessionId: String?,
        requestedModel: LanguageModel?,
        delegate: any AgentEventDelegate
    ) async throws -> AgentExecutionResult {
        if let existingSessionId = sessionId {
            return try await agentService.continueSession(
                sessionId: existingSessionId,
                userMessage: input,
                model: requestedModel,
                maxSteps: self.resolvedMaxSteps,
                dryRun: self.dryRun,
                eventDelegate: delegate,
                verbose: self.verbose
            )
        }

        return try await agentService.executeTask(
            input,
            maxSteps: self.resolvedMaxSteps,
            sessionId: nil,
            model: requestedModel,
            dryRun: self.dryRun,
            eventDelegate: delegate,
            verbose: self.verbose
        )
    }

    @MainActor
    private func runTauTUIChatLoop(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?,
        initialPrompt: String?,
        capabilities: TerminalCapabilities
    ) async throws {
        var activeSessionId: String?
        do {
            activeSessionId = try await self.initialChatSessionId(agentService)
        } catch {
            self.printAgentExecutionError(error.localizedDescription)
            return
        }

        let chatUI = AgentChatUI(
            modelDescription: self.describeModel(requestedModel),
            sessionId: activeSessionId,
            helpLines: self.chatHelpLines
        )

        try chatUI.start()
        defer { chatUI.stop() }

        var currentRun: Task<AgentExecutionResult, any Error>?
        chatUI.onCancelRequested = { [weak chatUI] in
            guard let run = currentRun else { return }
            if !run.isCancelled {
                run.cancel()
                chatUI?.markCancelling()
            }
        }

        chatUI.onInterruptRequested = { [weak chatUI] in
            if let run = currentRun, !run.isCancelled {
                run.cancel()
                chatUI?.markCancelling()
            } else {
                chatUI?.finishPromptStream()
            }
        }

        let promptStream = chatUI.promptStream(initialPrompt: initialPrompt)
        for await prompt in promptStream {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "/help" {
                chatUI.showHelpMenu()
                continue
            }

            chatUI.beginRun(prompt: trimmed)
            let tuiDelegate = AgentChatEventDelegate(ui: chatUI)

            currentRun = Task {
                try await self.runAgentTurnForTUI(
                    trimmed,
                    agentService: agentService,
                    sessionId: activeSessionId,
                    requestedModel: requestedModel,
                    delegate: tuiDelegate
                )
            }

            do {
                guard let run = currentRun else { continue }
                let result = try await run.value
                if let sessionId = result.sessionId {
                    activeSessionId = sessionId
                }
                chatUI.endRun(result: result, sessionId: activeSessionId)
            } catch is CancellationError {
                chatUI.showCancelled()
            } catch {
                chatUI.showError(error.localizedDescription)
            }

            currentRun = nil
            chatUI.setRunning(false)
        }
    }

    private func initialChatSessionId(
        _ agentService: PeekabooAgentService
    ) async throws -> String? {
        if let sessionId = self.resumeSession {
            guard try await agentService.getSessionInfo(sessionId: sessionId) != nil else {
                throw PeekabooError.sessionNotFound(sessionId)
            }
            return sessionId
        }

        if self.resume {
            let sessions = try await agentService.listSessions()
            guard let mostRecent = sessions.first else {
                throw PeekabooError.commandFailed("No sessions available to resume.")
            }
            return mostRecent.id
        }

        return nil
    }

    private func readChatLine(prompt: String, capabilities: TerminalCapabilities) -> String? {
        if capabilities.isInteractive {
            fputs(prompt, stdout)
            fflush(stdout)
        }
        return readLine()
    }

    private func performChatTurn(
        _ input: String,
        agentService: PeekabooAgentService,
        sessionId: inout String?,
        requestedModel: LanguageModel?
    ) async throws {
        let startingSessionId = sessionId
        let runTask = Task { () throws -> AgentExecutionResult in
            if let existingSessionId = startingSessionId {
                let delegate = self.makeEventDelegate(for: input)
                let result = try await agentService.continueSession(
                    sessionId: existingSessionId,
                    userMessage: input,
                    model: requestedModel,
                    maxSteps: self.resolvedMaxSteps,
                    dryRun: self.dryRun,
                    eventDelegate: delegate,
                    verbose: self.verbose
                )
                self.displayResult(result, delegate: delegate)
                return result
            } else {
                return try await self.executeAgentTask(
                    agentService,
                    task: input,
                    requestedModel: requestedModel,
                    maxSteps: self.resolvedMaxSteps
                )
            }
        }

        let cancelMonitor = EscapeKeyMonitor { [runTask] in
            if !runTask.isCancelled {
                runTask.cancel()
                await MainActor.run {
                    print("\n\(TerminalColor.yellow)Esc pressed – cancelling current run...\(TerminalColor.reset)")
                }
            }
        }
        cancelMonitor.start()

        let result: AgentExecutionResult
        do {
            defer { cancelMonitor.stop() }
            result = try await runTask.value
        } catch is CancellationError {
            cancelMonitor.stop()
            return
        }

        if let updatedSessionId = result.sessionId {
            sessionId = updatedSessionId
        }

        self.printChatTurnSummary(result)
    }

    private func printChatTurnSummary(_ result: AgentExecutionResult) {
        guard !self.quiet else { return }
        let duration = String(format: "%.1fs", result.metadata.executionTime)
        let sessionFragment = result.sessionId.map { String($0.prefix(8)) } ?? "–"
        let line = [
            TerminalColor.dim,
            "↺ Session ",
            sessionFragment,
            ": ",
            duration,
            " • ⚒ ",
            String(result.metadata.toolCallCount),
            TerminalColor.reset
        ].joined()
        print(line)
    }

    private func describeModel(_ requestedModel: LanguageModel?) -> String {
        requestedModel?.description ?? "default (gpt-5.1)"
    }

    private func printChatWelcome(sessionId: String?, modelDescription: String) {
        guard !self.quiet else { return }
        let header = [
            TerminalColor.cyan,
            TerminalColor.bold,
            "Interactive agent chat",
            TerminalColor.reset,
            " – model: ",
            modelDescription
        ].joined()
        print(header)
        if let sessionId {
            print("\(TerminalColor.dim)Resuming session \(sessionId.prefix(8))\(TerminalColor.reset)")
        } else {
            print("\(TerminalColor.dim)A new session will be created on the first prompt\(TerminalColor.reset)")
        }
        print()
    }

    private func printChatHelpIntro() {
        guard !self.quiet else { return }
        print("Type /help for chat commands (Ctrl+C to exit).")
        self.printChatHelpMenu()
    }

    private func printChatHelpMenu() {
        guard !self.quiet else { return }
        self.chatHelpLines.forEach { print($0) }
    }

    private var chatHelpLines: [String] {
        [
            "",
            "Chat commands:",
            "  • Type any prompt and press Return to run it.",
            "  • /help  Show this menu again.",
            "  • Esc    Cancel the active run (if one is in progress).",
            "  • Ctrl+C Cancel when running; exit immediately when idle.",
            "  • Ctrl+D Exit when idle (EOF).",
            ""
        ]
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
                return .openai(.gpt51)
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

    func validatedModelSelection() throws -> LanguageModel? {
        guard let modelString = self.model else { return nil }
        guard let parsed = self.parseModelString(modelString) else {
            throw PeekabooError.invalidInput(
                "Unsupported model '\(modelString)'. Allowed values: \(Self.allowedModelList)"
            )
        }
        return parsed
    }

    private static let supportedOpenAIInputs: Set<LanguageModel.OpenAI> = [
        .gpt51,
        .gpt51Mini,
        .gpt51Nano,
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

    private static var allowedModelList: String {
        let openAIModels = Self.supportedOpenAIInputs.map(\.modelId)
        let anthropicModels = Self.supportedAnthropicInputs.map(\.modelId)
        return (openAIModels + anthropicModels).sorted().joined(separator: ", ")
    }

    @MainActor
    private func hasCredentials(for model: LanguageModel) -> Bool {
        let configuration = self.services.configuration
        switch model {
        case .openai:
            return configuration.getOpenAIAPIKey()?.isEmpty == false
        case .anthropic:
            return configuration.getAnthropicAPIKey()?.isEmpty == false
        default:
            return false
        }
    }

    private func providerDisplayName(for model: LanguageModel) -> String {
        switch model {
        case .openai:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        default:
            "the selected provider"
        }
    }

    private func providerEnvironmentVariable(for model: LanguageModel) -> String {
        switch model {
        case .openai:
            "OPENAI_API_KEY"
        case .anthropic:
            "ANTHROPIC_API_KEY"
        default:
            "provider API key"
        }
    }
}

// MARK: - TauTUI Chat Helpers

@MainActor
private final class AgentChatInput: Component {
    private let editor = Editor()

    var onSubmit: ((String) -> ())?
    var onCancel: (() -> ())?
    var onInterrupt: (() -> ())?
    var onQueueWhileLocked: (() -> ())?

    var isLocked: Bool = false {
        didSet {
            // Keep submit enabled so users can queue prompts while a run is active.
            if !self.isLocked {
                self.editor.disableSubmit = false
            }
        }
    }

    init() {
        self.editor.onSubmit = { [weak self] value in
            self?.onSubmit?(value)
        }
    }

    func render(width: Int) -> [String] {
        self.editor.render(width: width)
    }

    func handle(input: TerminalInput) {
        switch input {
        case let .key(.character(char), modifiers):
            if modifiers.contains(.control) {
                let lower = String(char).lowercased()
                if lower == "c" || lower == "d" {
                    self.onInterrupt?()
                    return
                }
            }
        case .key(.escape, _):
            if self.isLocked {
                self.onCancel?()
                return
            }
        case .key(.end, _):
            if self.isLocked {
                self.onQueueWhileLocked?()
                return
            }
        default:
            break
        }

        self.editor.handle(input: input)
    }

    func clear() {
        self.editor.setText("")
    }

    func currentText() -> String {
        self.editor.getText()
    }
}

@MainActor
private final class AgentChatUI {
    var onCancelRequested: (() -> ())?
    var onInterruptRequested: (() -> ())?

    private let tui: TUI
    private let messages = Container()
    private let input = AgentChatInput()
    private let header: Text
    private let sessionLine: Text
    private let helpLines: [String]
    private let queueContainer = Container()
    private let queuePreview = Text(text: "", paddingX: 1, paddingY: 0)

    private var promptContinuation: AsyncStream<String>.Continuation?
    private var loader: Loader?
    private var assistantBuffer = ""
    private var assistantComponent: MarkdownComponent?
    private var thinkingComponent: Text?
    private var sessionId: String?
    private var queuedPrompts: [String] = []
    private var isRunning = false

    init(modelDescription: String, sessionId: String?, helpLines: [String]) {
        self.tui = TUI(terminal: ProcessTerminal())
        self.sessionId = sessionId
        self.helpLines = helpLines
        self.header = Text(
            text: "Interactive agent chat – model: \(modelDescription)",
            paddingX: 1,
            paddingY: 0
        )
        self.sessionLine = Text(
            text: AgentChatUI.sessionDescription(for: sessionId),
            paddingX: 1,
            paddingY: 0
        )

        self.input.onSubmit = { [weak self] value in
            self?.handleSubmit(value)
        }
        self.input.onCancel = { [weak self] in
            self?.onCancelRequested?()
        }
        self.input.onInterrupt = { [weak self] in
            self?.onInterruptRequested?()
        }
        self.input.onQueueWhileLocked = { [weak self] in
            self?.queueCurrentInput()
        }
    }

    func start() throws {
        self.tui.addChild(self.header)
        self.tui.addChild(self.sessionLine)
        self.tui.addChild(Spacer(lines: 1))
        self.tui.addChild(self.messages)
        self.tui.addChild(Spacer(lines: 1))
        self.tui.addChild(self.queueContainer)
        self.tui.addChild(self.input)
        self.tui.setFocus(self.input)

        try self.tui.start()
        self.showHelpMenu()
        self.tui.requestRender()
    }

    func stop() {
        self.tui.stop()
    }

    func promptStream(initialPrompt: String?) -> AsyncStream<String> {
        AsyncStream { continuation in
            self.promptContinuation = continuation
            if let seed = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !seed.isEmpty {
                self.appendUserMessage(seed)
                continuation.yield(seed)
            }
        }
    }

    func finishPromptStream() {
        self.promptContinuation?.finish()
    }

    func beginRun(prompt: String) {
        self.setRunning(true)
        self.removeLoader()
        self.loader = Loader(tui: self.tui, message: "Running…")
        if let loader {
            self.messages.addChild(loader)
        }
        self.assistantBuffer = ""
        self.assistantComponent = nil
        self.thinkingComponent = nil
        self.requestRender()
    }

    func endRun(result: AgentExecutionResult, sessionId: String?) {
        self.loader?.stop()
        self.loader = nil
        if let sessionId {
            self.sessionId = sessionId
            self.sessionLine.text = AgentChatUI.sessionDescription(for: sessionId)
        }
        let summary = self.summaryLine(for: result)
        let summaryComponent = Text(text: summary, paddingX: 1, paddingY: 0)
        self.messages.addChild(summaryComponent)
        self.requestRender()
    }

    func setRunning(_ running: Bool) {
        let wasRunning = self.isRunning
        self.isRunning = running
        self.input.isLocked = running
        if !running {
            self.removeLoader()
            if wasRunning {
                self.processNextQueuedPromptIfNeeded()
            }
        }
    }

    private func removeLoader() {
        guard let loader else { return }
        loader.stop()
        self.messages.removeChild(loader)
        self.loader = nil
        self.requestRender()
    }

    func markCancelling() {
        self.loader?.setMessage("Cancelling…")
        self.requestRender()
    }

    func showCancelled() {
        self.setRunning(false)
        let cancelled = Text(text: "◼︎ Cancelled", paddingX: 1, paddingY: 0)
        self.messages.addChild(cancelled)
        self.requestRender()
    }

    func showError(_ message: String) {
        self.setRunning(false)
        let errorText = Text(
            text: "✗ \(message)",
            paddingX: 1,
            paddingY: 0,
            background: Text.Background(red: 64, green: 0, blue: 0)
        )
        self.messages.addChild(errorText)
        self.requestRender()
    }

    func showHelpMenu() {
        let helpText = self.helpLines.joined(separator: "\n")
        let help = MarkdownComponent(text: helpText, padding: .init(horizontal: 1, vertical: 0))
        self.messages.addChild(help)
    }

    func updateThinking(_ content: String) {
        let message = "_\(content)_"
        if let thinkingComponent {
            thinkingComponent.text = message
        } else {
            let component = Text(text: message, paddingX: 1, paddingY: 0)
            self.thinkingComponent = component
            self.messages.addChild(component)
        }
        self.requestRender()
    }

    func appendAssistant(_ content: String) {
        self.assistantBuffer.append(content)
        let formatted = "**Agent:** \(self.assistantBuffer)"
        if let assistantComponent {
            assistantComponent.text = formatted
        } else {
            let component = MarkdownComponent(text: formatted, padding: .init(horizontal: 1, vertical: 0))
            self.assistantComponent = component
            self.messages.addChild(component)
        }
        self.requestRender()
    }

    func finishStreaming() {
        if let thinkingComponent {
            self.messages.removeChild(thinkingComponent)
            self.thinkingComponent = nil
        }
        self.requestRender()
    }

    func showToolStart(name: String, summary: String?) {
        let text = summary.flatMap { $0.isEmpty ? nil : $0 } ?? name
        let component = Text(text: "⚒ \(text)", paddingX: 1, paddingY: 0)
        self.messages.addChild(component)
        self.requestRender()
    }

    func showToolCompletion(name: String, success: Bool, summary: String?) {
        let prefix = success ? "✓" : "✗"
        let text = summary.flatMap { $0.isEmpty ? nil : $0 } ?? name
        let component = Text(text: "\(prefix) \(text)", paddingX: 1, paddingY: 0)
        self.messages.addChild(component)
        self.requestRender()
    }

    func requestRender() {
        self.tui.requestRender()
    }

    private func handleSubmit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if self.isRunning {
            self.enqueueQueuedPrompt(trimmed)
            self.input.clear()
            return
        }

        self.dispatchPrompt(trimmed)
    }

    private func queueCurrentInput() {
        guard self.isRunning else { return }
        let trimmed = self.input.currentText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.enqueueQueuedPrompt(trimmed)
        self.input.clear()
    }

    private func enqueueQueuedPrompt(_ prompt: String) {
        self.queuedPrompts.append(prompt)
        self.updateQueuePreview()
    }

    private func updateQueuePreview() {
        if self.queuedPrompts.isEmpty {
            self.queueContainer.clear()
            self.queuePreview.text = ""
            self.requestRender()
            return
        }

        self.queuePreview.text = self.queuePreviewLine()
        if self.queueContainer.children.isEmpty {
            self.queueContainer.addChild(self.queuePreview)
        }
        self.requestRender()
    }

    private func queuePreviewLine() -> String {
        let joined = self.queuedPrompts.joined(separator: "   ·   ")
        var summary = "Queued (\(self.queuedPrompts.count)): \(joined)"
        let limit = 96
        if summary.count > limit {
            let index = summary.index(summary.startIndex, offsetBy: max(0, limit - 1))
            summary = String(summary[..<index]) + "…"
        }
        return summary
    }

    private func processNextQueuedPromptIfNeeded() {
        guard !self.queuedPrompts.isEmpty else { return }
        let next = self.queuedPrompts.removeFirst()
        self.updateQueuePreview()
        self.dispatchPrompt(next)
    }

    private func dispatchPrompt(_ text: String) {
        self.appendUserMessage(text)
        self.promptContinuation?.yield(text)
    }

    private func appendUserMessage(_ text: String) {
        let message = MarkdownComponent(text: "**You:** \(text)", padding: .init(horizontal: 1, vertical: 0))
        self.messages.addChild(message)
        self.requestRender()
    }

    private func summaryLine(for result: AgentExecutionResult) -> String {
        let duration = String(format: "%.1fs", result.metadata.executionTime)
        let tools = result.metadata.toolCallCount == 1 ? "1 tool" : "\(result.metadata.toolCallCount) tools"
        let sessionFragment = self.sessionId.map { String($0.prefix(8)) } ?? "new session"
        return "✓ Session \(sessionFragment) • \(duration) • \(tools)"
    }

    private static func sessionDescription(for sessionId: String?) -> String {
        guard let sessionId else { return "Session: new (will be created on first run)" }
        return "Session: \(sessionId)"
    }
}

@MainActor
private final class AgentChatEventDelegate: AgentEventDelegate {
    private weak var ui: AgentChatUI?

    init(ui: AgentChatUI) {
        self.ui = ui
    }

    func agentDidEmitEvent(_ event: AgentEvent) {
        guard let ui else { return }
        switch event {
        case .started:
            break
        case let .assistantMessage(content):
            ui.appendAssistant(content)
        case let .thinkingMessage(content):
            ui.updateThinking(content)
        case let .toolCallStarted(name, arguments):
            let args = parseArguments(arguments)
            let formatter = self.toolFormatter(for: name)
            let summary = formatter?.formatStarting(arguments: args) ??
                name.replacingOccurrences(of: "_", with: " ")
            ui.showToolStart(name: name, summary: summary)
        case let .toolCallCompleted(name, result):
            let summary = self.toolResultSummary(name: name, result: result)
            let success = self.successFlag(from: result)
            ui.showToolCompletion(name: name, success: success, summary: summary)
        case let .error(message):
            ui.showError(message)
        case .completed:
            ui.finishStreaming()
        }
    }

    private func toolFormatter(for name: String) -> (any ToolFormatter)? {
        if let type = ToolType(rawValue: name) {
            return ToolFormatterRegistry.shared.formatter(for: type)
        }
        return nil
    }

    private func toolResultSummary(name: String, result: String) -> String? {
        guard let json = parseResult(result) else { return nil }
        if let summary = ToolEventSummary.from(resultJSON: json)?.shortDescription(toolName: name) {
            return summary
        }
        let formatter = self.toolFormatter(for: name)
        return formatter?.formatResultSummary(result: json)
    }

    private func successFlag(from result: String) -> Bool {
        guard let json = parseResult(result) else { return true }
        return (json["success"] as? Bool) ?? true
    }
}

extension AgentCommand: ParsableCommand {}

extension AgentCommand: AsyncRuntimeCommand {}
