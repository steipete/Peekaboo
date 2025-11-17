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

// swiftlint:disable file_length

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

private let defaultMCPServerName = "chrome-devtools"

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
    var services: any PeekabooServiceProviding {
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

final class EscapeKeyMonitor {
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

        let chatPolicy = AgentChatLaunchPolicy()
        let chatContext = AgentChatLaunchContext(
            chatFlag: self.chat,
            hasTaskInput: self.hasTaskInput,
            listSessions: self.listSessions,
            normalizedTaskInput: self.normalizedTaskInput,
            capabilities: terminalCapabilities
        )

        switch chatPolicy.strategy(for: chatContext) {
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
                    handler.logLevel = .critical // hide MCP init chatter unless --verbose
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
            let defaultChromeDevTools = ChromeDevToolsServerFactory.tachikomaConfig(timeout: 60.0, autoReconnect: true)
            TachikomaMCPClientManager.shared.registerDefaultServers(
                [defaultMCPServerName: defaultChromeDevTools])
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

    func printMissingTaskError(message: String, usage: String) {
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

        for (index, session) in sessions.prefix(10).indexed() {
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

        let outputDelegate = self.makeDisplayDelegate(for: task)
        let streamingDelegate = self.makeStreamingDelegate(using: outputDelegate)
        do {
            let result = try await agentService.resumeSession(
                sessionId: sessionId,
                model: requestedModel,
                eventDelegate: streamingDelegate
            )
            self.displayResult(result, delegate: outputDelegate)
        } catch {
            self.printAgentExecutionError("Failed to resume session: \(error.localizedDescription)")
            throw error
        }
    }

    func makeDisplayDelegate(for task: String) -> AgentOutputDelegate? {
        guard !self.jsonOutput, !self.quiet else { return nil }
        return AgentOutputDelegate(outputMode: self.outputMode, jsonOutput: self.jsonOutput, task: task)
    }

    func makeStreamingDelegate(using displayDelegate: AgentOutputDelegate?) -> (any AgentEventDelegate)? {
        if let displayDelegate {
            return displayDelegate
        }

        if self.jsonOutput || self.quiet {
            return SilentAgentEventDelegate()
        }

        return nil
}

final class SilentAgentEventDelegate: AgentEventDelegate {
    func agentDidEmitEvent(_ event: AgentEvent) {}
}

    func printAgentExecutionError(_ message: String) {
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

    func executeAgentTask(
        _ agentService: PeekabooAgentService,
        task: String,
        requestedModel: LanguageModel?,
        maxSteps: Int
    ) async throws -> AgentExecutionResult {
        let outputDelegate = self.makeDisplayDelegate(for: task)
        let streamingDelegate = self.makeStreamingDelegate(using: outputDelegate)
        do {
            let result = try await agentService.executeTask(
                task,
                maxSteps: maxSteps,
                sessionId: nil,
                model: requestedModel,
                dryRun: self.dryRun,
                eventDelegate: streamingDelegate,
                verbose: self.verbose
            )
            self.displayResult(result, delegate: outputDelegate)
            let duration = String(format: "%.2f", result.metadata.executionTime)
            let sessionId = result.sessionId ?? "none"
            let finalTokens = result.usage?.totalTokens ?? 0
            let status = result.metadata.context["status"] ?? "completed"
            AutomationEventLogger.log(
                .agent,
                "result status=\(status) task='\(task)' model=\(result.metadata.modelName) duration=\(duration)s tools=\(result.metadata.toolCallCount) dry_run=\(self.dryRun) session=\(sessionId) tokens=\(finalTokens)"
            )
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

    var resolvedMaxSteps: Int { self.maxSteps ?? 100 }

    func printChatWelcome(sessionId: String?, modelDescription: String) {
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

    func printChatHelpIntro() {
        guard !self.quiet else { return }
        print("Type /help for chat commands (Ctrl+C to exit).")
        self.printChatHelpMenu()
    }

    func printChatHelpMenu() {
        guard !self.quiet else { return }
        self.chatHelpLines.forEach { print($0) }
    }

    var chatHelpLines: [String] {
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

extension AgentCommand: ParsableCommand {}

extension AgentCommand: AsyncRuntimeCommand {}

// swiftlint:enable file_length
