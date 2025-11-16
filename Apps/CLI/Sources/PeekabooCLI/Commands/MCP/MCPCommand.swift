import Algorithms
import Commander
import Foundation
import Logging
import MCP
import PeekabooCore
import TachikomaMCP

private enum MCPDefaults {
    static let serverName = "chrome-devtools"
}

// MARK: - Shared MCP client abstraction

protocol MCPClientManaging: AnyObject {
    func registerDefaultServers(_ defaults: [String: TachikomaMCP.MCPServerConfig])
    func initializeFromProfile(connect: Bool) async
    func getServerInfo(name: String) async -> (config: TachikomaMCP.MCPServerConfig, connected: Bool)?
    func probeServer(name: String, timeoutMs: Int) async -> ServerProbeResult
    func probeAllServers(timeoutMs: Int) async -> [String: ServerProbeResult]
    func executeTool(serverName: String, toolName: String, arguments: [String: Any]) async throws -> ToolResponse
}

extension TachikomaMCPClientManager: MCPClientManaging {}

/// Command for Model Context Protocol server operations
@MainActor
struct MCPCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "mcp",
        abstract: "Model Context Protocol server and client operations",
        discussion: """
        The MCP command allows Peekaboo to act as both an MCP server (exposing its tools
        to AI clients like Claude) and an MCP client (consuming other MCP servers).

        EXAMPLES:
          peekaboo mcp serve                    # Start MCP server on stdio
          peekaboo mcp serve --transport http   # HTTP transport (future)
          peekaboo mcp call <server> <tool>     # Call tool on another MCP server
          peekaboo mcp list                     # List available MCP servers
        """,
        subcommands: [
            Serve.self,
            List.self,
            Add.self,
            Remove.self,
            Test.self,
            Info.self,
            Enable.self,
            Disable.self,
            Call.self,
            Inspect.self,
        ],
        showHelpOnEmptyInvocation: true
    )
}

// MARK: - Subcommands

extension MCPCommand {
    /// Start MCP server
    @MainActor
    struct Serve {
        static let commandDescription = CommandDescription(
            commandName: "serve",
            abstract: "Start Peekaboo as an MCP server",
            discussion: """
            Starts Peekaboo as an MCP server, exposing all its tools via the
            Model Context Protocol. This allows AI clients like Claude to use
            Peekaboo's automation capabilities.

            USAGE WITH CLAUDE CODE:
              claude mcp add peekaboo -- peekaboo mcp serve

            USAGE WITH MCP INSPECTOR:
              npx @modelcontextprotocol/inspector peekaboo mcp serve
            """
        )

        @Option(help: "Transport type (stdio, http, sse)")
        var transport: String = "stdio"

        @Option(help: "Port for HTTP/SSE transport")
        var port: Int = 8080
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            do {
                // Convert string transport to PeekabooCore.TransportType
                let transportType: PeekabooCore.TransportType = switch self.transport.lowercased() {
                case "stdio": .stdio
                case "http": .http
                case "sse": .sse
                default: .stdio
                }

                let server = try await PeekabooMCPServer()
                try await server.serve(transport: transportType, port: self.port)
            } catch {
                self.logger.error("Failed to start MCP server: \(error)")
                throw ExitCode.failure
            }
        }
    }

    /// Call tool on MCP server
    @MainActor
    struct Call {
        static let commandDescription = CommandDescription(
            commandName: "call",
            abstract: "Call a tool on another MCP server",
            discussion: """
            Connect to another MCP server and execute a tool. This allows
            Peekaboo to consume services from other MCP servers.

            EXAMPLE:
              peekaboo mcp call claude-code edit_file --args '{"path": "main.swift"}'
            """
        )

        private static let connectionTimeoutSeconds: TimeInterval = 15

        @Argument(help: "MCP server to connect to")
        var server: String?

        @Argument(help: "Tool to call")
        var tool: String?

        @Option(help: "Tool arguments as JSON")
        var args: String = "{}"

        @RuntimeStorage private var runtime: CommandRuntime?
        var clientManager: any MCPClientManaging = TachikomaMCPClientManager.shared

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }
        private var wantsJSON: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                guard let server = self.server, !server.isEmpty else {
                    throw CallError.invalidArguments("Specify the target MCP server via --server.")
                }
                guard let tool = self.tool, !tool.isEmpty else {
                    throw CallError.invalidArguments("Specify the MCP tool to call using --tool.")
                }

                let arguments = try self.parseArguments()
                try await self.ensureServerReady(serverName: server)

                let response = try await self.clientManager.executeTool(
                    serverName: server,
                    toolName: tool,
                    arguments: arguments
                )
                AutomationEventLogger.log(
                    .mcp,
                    "call server=\(server) tool=\(tool) error=\(response.isError)"
                )

                if self.wantsJSON {
                    self.outputJSON(response: response, serverName: server, toolName: tool)
                } else {
                    self.outputHumanReadable(response: response, server: server, toolName: tool)
                }

                if response.isError {
                    throw ExitCode.failure
                }
            } catch let error as CallError {
                self.emitError(message: error.localizedDescription ?? "Unknown MCP error", code: error.errorCode)
                throw ExitCode.failure
            } catch let exit as ExitCode {
                throw exit
            } catch {
                self.emitError(message: "Failed to call MCP tool: \(error.localizedDescription)", code: .UNKNOWN_ERROR)
                throw ExitCode.failure
            }
        }

        private func parseArguments() throws -> [String: Any] {
            let trimmed = self.args.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return [:]
            }

            guard let data = trimmed.data(using: .utf8) else {
                throw CallError.invalidArguments("Arguments must be valid UTF-8 text")
            }

            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

            if let dict = json as? [String: Any] {
                return dict
            }

            if json is NSNull {
                return [:]
            }

            throw CallError.invalidArguments("MCP tool arguments must be a JSON object")
        }

        private func registerDefaultServers() {
            let defaultChromeDevTools = TachikomaMCP.MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "chrome-devtools-mcp@latest"],
                env: [:],
                enabled: true,
                timeout: 15.0,
                autoReconnect: true,
                description: "Chrome DevTools automation"
            )

            self.clientManager.registerDefaultServers([MCPDefaults.serverName: defaultChromeDevTools])
        }

        private func ensureServerReady(serverName: String) async throws {
            await self.prepareClientManager()

            guard let info = await self.clientManager.getServerInfo(name: serverName) else {
                throw CallError.serverNotConfigured(serverName)
            }

            guard info.config.enabled else {
                throw CallError.serverDisabled(serverName)
            }

            let probe = await self.clientManager.probeServer(
                name: serverName,
                timeoutMs: Int(Self.connectionTimeoutSeconds * 1000)
            )

            guard probe.isConnected else {
                throw CallError.connectionFailed(server: serverName, reason: probe.error)
            }
        }

        private func prepareClientManager() async {
            self.registerDefaultServers()
            await self.clientManager.initializeFromProfile(connect: false)
        }

        private func outputHumanReadable(response: ToolResponse, server: String, toolName: String) {
            print("MCP server: \(server)")
            print("Tool: \(toolName)")

            if response.content.isEmpty {
                print("Response: (no content)")
            } else if response.content.count == 1 {
                print("Response: \(self.describe(content: response.content[0]))")
            } else {
                print("Response:")
                for (index, content) in response.content.indexed() {
                    print("  \(index + 1). \(self.describe(content: content))")
                }
            }

            if let metaDescription = self.describe(meta: response.meta) {
                print("Meta: \(metaDescription)")
            }

            if response.isError {
                print("Tool reported an error.")
            } else {
                print("Tool completed successfully.")
            }
        }

        private func outputJSON(response: ToolResponse, serverName: String, toolName: String) {
            let payload = self.makeJSONPayload(for: response, serverName: serverName, toolName: toolName)
            outputJSONCodable(payload, logger: self.logger)
        }

        private func makeJSONPayload(for response: ToolResponse, serverName: String, toolName: String) -> CallJSONPayload {
            let contents = response.content.map(SerializableContent.init)
            return CallJSONPayload(
                success: !response.isError,
                server: serverName,
                tool: toolName,
                response: .init(isError: response.isError, content: contents, meta: response.meta),
                errorMessage: self.extractErrorMessage(from: response)
            )
        }

        private func describe(content: MCP.Tool.Content) -> String {
            switch content {
            case let .text(text):
                text
            case let .image(_, mimeType, _):
                "Image response (\(mimeType))"
            case let .resource(uri, _, text):
                if let text, !text.isEmpty {
                    "Resource: \(uri) — \(text)"
                } else {
                    "Resource: \(uri)"
                }
            case let .audio(_, mimeType):
                "Audio response (\(mimeType))"
            }
        }

        private func describe(meta: Value?) -> String? {
            guard let meta else { return nil }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(meta), let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        }

        private func extractErrorMessage(from response: ToolResponse) -> String? {
            guard response.isError else { return nil }
            for content in response.content {
                if case let .text(text) = content {
                    return text
                }
            }
            return nil
        }

        private func emitError(message: String, code: ErrorCode) {
            if self.wantsJSON {
                let debugLogs = self.logger.getDebugLogs()
                let response = JSONResponse(
                    success: false,
                    messages: nil,
                    debugLogs: debugLogs,
                    error: ErrorInfo(message: message, code: code)
                )
                PeekabooCLI.outputJSON(response, logger: self.logger)
            } else {
                print("❌ \(message)")
            }
        }
    }

    private enum CallError: LocalizedError {
        case invalidArguments(String)
        case serverNotConfigured(String)
        case serverDisabled(String)
        case connectionFailed(server: String, reason: String?)

        var errorDescription: String? {
            switch self {
            case let .invalidArguments(message):
                message
            case let .serverNotConfigured(server):
                "MCP server '\(server)' is not configured. Use 'peekaboo mcp add' to register it."
            case let .serverDisabled(server):
                "MCP server '\(server)' is disabled. Run 'peekaboo mcp enable \(server)' before calling tools."
            case let .connectionFailed(server, reason):
                if let reason, !reason.isEmpty {
                    "Failed to connect to MCP server '\(server)' (\(reason))."
                } else {
                    "Failed to connect to MCP server '\(server)'."
                }
            }
        }

        var errorCode: ErrorCode {
            switch self {
            case .invalidArguments, .serverNotConfigured, .serverDisabled:
                .INVALID_ARGUMENT
            case .connectionFailed:
                .UNKNOWN_ERROR
            }
        }
    }

    private struct CallJSONPayload: Encodable {
        struct Response: Encodable {
            let isError: Bool
            let content: [SerializableContent]
            let meta: Value?
        }

        let success: Bool
        let server: String
        let tool: String
        let response: Response
        let errorMessage: String?
    }

    private struct SerializableContent: Encodable {
        enum ContentType: String, Encodable {
            case text
            case image
            case resource
            case audio
        }

        let type: ContentType
        let text: String?
        let mimeType: String?
        let data: String?
        let uri: String?
        let metadata: Value?

        init(content: MCP.Tool.Content) {
            switch content {
            case let .text(text):
                self.type = .text
                self.text = text
                self.mimeType = nil
                self.data = nil
                self.uri = nil
                self.metadata = nil
            case let .image(data, mimeType, metadata):
                self.type = .image
                self.text = nil
                self.mimeType = mimeType
                self.data = data
                self.uri = nil
                self.metadata = Self.valueMetadata(from: metadata)
            case let .resource(uri, mimeType, text):
                self.type = .resource
                self.text = text
                self.mimeType = mimeType
                self.data = nil
                self.uri = uri
                self.metadata = nil
            case let .audio(data, mimeType):
                self.type = .audio
                self.text = nil
                self.mimeType = mimeType
                self.data = data
                self.uri = nil
                self.metadata = nil
            }
        }

        private static func valueMetadata(from metadata: [String: String]?) -> Value? {
            guard let metadata else { return nil }
            var object: [String: Value] = [:]
            for (key, value) in metadata {
                object[key] = .string(value)
            }
            return .object(object)
        }
    }

    /// List available MCP servers with health checking
    struct List {
        @Flag(name: .long, help: "Skip health checks (faster)")
        var skipHealthCheck = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var configuration: CommandRuntime.Configuration { self.resolvedRuntime.configuration }
        private var logger: Logger { self.resolvedRuntime.logger }
        private var wantsJSON: Bool { self.configuration.jsonOutput }
        private var isVerbose: Bool { self.configuration.verbose }

        /// Initialize the MCP client manager, optionally probe server health, and render the chosen output format.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            // Register Chrome DevTools MCP as a default server
            let defaultChromeDevTools = TachikomaMCP.MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "chrome-devtools-mcp@latest"],
                env: [:],
                enabled: true,
                timeout: 15.0,
                autoReconnect: true,
                description: "Chrome DevTools automation"
            )
            TachikomaMCPClientManager.shared.registerDefaultServers(
                [MCPDefaults.serverName: defaultChromeDevTools])

            // Suppress os_log output unless verbose
            let originalStderr = dup(STDERR_FILENO)
            let devNull = open("/dev/null", O_WRONLY)
            if !self.isVerbose && devNull != -1 {
                // Redirect stderr to /dev/null to suppress os_log output
                dup2(devNull, STDERR_FILENO)
            }

            // Initialize Tachikoma MCP manager (don't connect yet - let health check measure timing)
            await TachikomaMCPClientManager.shared.initializeFromProfile(connect: false)
            let serverNames = TachikomaMCPClientManager.shared.getServerNames()

            // Restore stderr after initialization
            if !self.isVerbose && devNull != -1 {
                dup2(originalStderr, STDERR_FILENO)
                close(devNull)
                close(originalStderr)
            }

            if serverNames.isEmpty {
                if self.wantsJSON {
                    let output = ["servers": [String: Any](), "summary": ["total": 0, "healthy": 0]]
                    let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    print("No MCP servers configured.")
                    print("\nTo add a server:")
                    print("  peekaboo mcp add <name> -- <command> [args...]")
                }
                return
            }

            if !self.skipHealthCheck && !self.wantsJSON {
                print("Checking MCP server health...")
                print()
            }

            // Suppress os_log output during health checks unless verbose
            let originalStderr2 = dup(STDERR_FILENO)
            let devNull2 = open("/dev/null", O_WRONLY)
            if !self.isVerbose && devNull2 != -1 {
                dup2(devNull2, STDERR_FILENO)
            }

            // Get health status for all servers (5 second timeout should be sufficient)
            let probes = await TachikomaMCPClientManager.shared.probeAllServers(timeoutMs: 5000)
            var healthResults: [String: MCPServerHealth] = [:]
            for (name, probe) in probes {
                healthResults[name] = probe.isConnected ? .connected(
                    toolCount: probe.toolCount,
                    responseTime: probe.responseTime
                ) :
                    .disconnected(error: probe.error ?? "unknown error")
            }

            // Restore stderr after health checks
            if !self.isVerbose && devNull2 != -1 {
                dup2(originalStderr2, STDERR_FILENO)
                close(devNull2)
                close(originalStderr2)
            }

            if self.wantsJSON {
                try await self.outputJSON(serverNames: serverNames, healthResults: healthResults)
            } else {
                await self.outputFormatted(serverNames: serverNames, healthResults: healthResults)
            }
        }

        /// Render the MCP server inventory and health probes as a JSON payload compatible with scripting use.
        private func outputJSON(serverNames: [String], healthResults: [String: MCPServerHealth]) async throws {
            var servers: [String: Any] = [:]
            var healthyCount = 0

            for serverName in serverNames {
                let info = await TachikomaMCPClientManager.shared.getServerInfo(name: serverName)
                let isEnabled = info?.config.enabled ?? false
                let command = info?.config.command ?? ""
                let args = info?.config.args ?? []
                let isConnected = info?.connected ?? false
                let health: MCPServerHealth = healthResults[serverName] ?? (isConnected ? .connected(
                    toolCount: 0,
                    responseTime: 0
                ) : .unknown)

                var serverDict: [String: Any] = [:]
                serverDict["command"] = command
                serverDict["args"] = args
                serverDict["enabled"] = isEnabled
                serverDict["health"] = [
                    "status": health.isHealthy ? "connected" : "disconnected",
                    "details": health.statusText
                ]
                servers[serverName] = serverDict

                if health.isHealthy {
                    healthyCount += 1
                }
            }

            let output: [String: Any] = [
                "servers": servers,
                "summary": [
                    "total": serverNames.count,
                    "healthy": healthyCount,
                    "configured": serverNames.count
                ]
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }

        /// Simplify command path for display
        private func simplifyCommandPath(command: String, args: [String]) -> String {
            // Handle npx commands - they're already clean
            if command == "npx" || command.hasSuffix("/npx") {
                return ([command.components(separatedBy: "/").last ?? command] + args).joined(separator: " ")
            }

            // Handle node commands with node_modules packages
            if command.contains("node") && !args.isEmpty {
                if let firstArg = args.first {
                    // Extract package name from node_modules path
                    if firstArg.contains("/node_modules/") {
                        if let packageStart = firstArg.range(of: "/node_modules/") {
                            let afterModules = String(firstArg[packageStart.upperBound...])
                            // Get just the package name (could be @org/package or package)
                            let components = afterModules.split(separator: "/")
                            if components.count >= 1 {
                                if components[0].starts(with: "@") && components.count >= 2 {
                                    // Scoped package like chrome-devtools-mcp
                                    return "\(components[0])/\(components[1])"
                                } else {
                                    // Regular package
                                    return String(components[0])
                                }
                            }
                        }
                    }
                    // If it's a direct script path, show just the filename
                    return URL(fileURLWithPath: firstArg).lastPathComponent
                }
            }

            // For other commands, simplify the path
            var simplifiedCommand = command

            // Replace home directory with ~
            if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
                simplifiedCommand = simplifiedCommand.replacingOccurrences(of: homeDir, with: "~")
            }

            // If still too long, just show the command name
            if simplifiedCommand.count > 50 {
                simplifiedCommand = URL(fileURLWithPath: command).lastPathComponent
            }

            // Combine with meaningful args (skip version specifiers and paths)
            let meaningfulArgs = args.filter { arg in
                !arg.starts(with: "-y") &&
                    !arg.starts(with: "--yes") &&
                    !arg.contains("/") &&
                    !arg.starts(with: "@") // Keep package names in the command part
            }

            if meaningfulArgs.isEmpty {
                return simplifiedCommand
            } else {
                return ([simplifiedCommand] + meaningfulArgs).joined(separator: " ")
            }
        }

        /// Print a human-friendly table of server health, including highlights for defaults and connection state.
        private func outputFormatted(serverNames: [String], healthResults: [String: MCPServerHealth]) async {
            var healthyCount = 0

            for serverName in serverNames.sorted() {
                let serverInfo = await TachikomaMCPClientManager.shared.getServerInfo(name: serverName)
                let health = healthResults[serverName] ?? (serverInfo?.connected == true ? .connected(
                    toolCount: 0,
                    responseTime: 0
                ) : .unknown)

                if health.isHealthy {
                    healthyCount += 1
                }

                let command = serverInfo?.config.command ?? "unknown"
                let args = serverInfo?.config.args ?? []
                let simplifiedCommand = self.simplifyCommandPath(command: command, args: args)

                let healthSymbol = health.symbol
                let healthText = health.statusText

                // Show if this is a default server
                let isDefault = (serverName == MCPDefaults.serverName)
                let defaultMarker = isDefault ? " [default]" : ""

                print("\(serverName): \(simplifiedCommand) - \(healthSymbol) \(healthText)\(defaultMarker)")
            }

            print()
            print("Total: \(serverNames.count) servers configured, \(healthyCount) healthy")

            // Show tool count if we have external tools
            let externalTools = await TachikomaMCPClientManager.shared.getExternalToolsByServer()
            let totalExternalTools = externalTools.values.reduce(0) { $0 + $1.count }
            if totalExternalTools > 0 {
                print("External tools available: \(totalExternalTools)")
            }
        }
    }

    /// Add a new MCP server
    struct Add {
        @Argument(help: "Name for the MCP server")
        var name: String

        @Option(name: .shortAndLong, help: "Environment variables (key=value)")
        var env: [String] = []

        @Option(name: .long, help: "HTTP headers for HTTP/SSE (Key=Value)", parsing: .upToNextOption)
        var header: [String] = []

        @Option(help: "Connection timeout in seconds")
        var timeout: Double = 10.0

        @Option(help: "Transport type (stdio, http, sse)")
        var transport: String = "stdio"

        @Option(help: "Description of the server")
        var description: String?

        @Flag(help: "Disable the server after adding")
        var disabled = false

        @Argument(help: "Command and arguments to run the MCP server")
        var command: [String] = []
        @RuntimeStorage private var runtime: CommandRuntime?
        private let stderrHandle = FileHandle.standardError

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }

        /// Validate the provided command, persist the new server configuration, and immediately probe connectivity.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            guard !self.command.isEmpty else {
                let message = "Command is required. Use -- to separate command from options."
                self.logger.error(message)
                self.emitUserFacingError(message)
                throw ExitCode.failure
            }

            // Parse environment variables
            var envDict: [String: String] = [:]
            for envVar in self.env {
                let parts = envVar.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    envDict[String(parts[0])] = String(parts[1])
                } else {
                    self.logger.error("Invalid environment variable format: \(envVar). Use key=value")
                    throw ExitCode.failure
                }
            }

            // Parse headers
            var headersDict: [String: String] = [:]
            for h in self.header {
                let parts = h.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    headersDict[String(parts[0])] = String(parts[1])
                } else {
                    self.logger.error("Invalid header format: \(h). Use Key=Value")
                    throw ExitCode.failure
                }
            }

            // Create Tachikoma MCP server config
            let config = TachikomaMCP.MCPServerConfig(
                transport: self.transport,
                command: self.command[0],
                args: Array(self.command.dropFirst()),
                env: envDict,
                enabled: !self.disabled,
                timeout: self.timeout,
                autoReconnect: true,
                description: self.description
            )

            // Register Chrome DevTools MCP as a default server
            let defaultChromeDevTools = TachikomaMCP.MCPServerConfig(
                transport: "stdio",
                command: "npx",
                args: ["-y", "chrome-devtools-mcp@latest"],
                env: [:],
                enabled: true,
                timeout: 15.0,
                autoReconnect: true,
                description: "Chrome DevTools automation"
            )
            TachikomaMCPClientManager.shared.registerDefaultServers(
                [MCPDefaults.serverName: defaultChromeDevTools])

            // Load existing profile configs, add server, persist, then probe
            await TachikomaMCPClientManager.shared.initializeFromProfile(connect: false)

            do {
                try await TachikomaMCPClientManager.shared.addServer(name: self.name, config: config)
                try TachikomaMCPClientManager.shared.persist()
                print("✓ Added MCP server '\(self.name)' and saved to profile")

                if !self.disabled {
                    print("Testing connection (\(Int(self.timeout))s timeout)...")
                    let probe = await TachikomaMCPClientManager.shared.probeServer(
                        name: self.name,
                        timeoutMs: Int(self.timeout * 1000)
                    )
                    if probe.isConnected {
                        print("✓ Connected in \(Int(probe.responseTime * 1000))ms (\(probe.toolCount) tools)")
                    } else {
                        print("✗ Failed: \(probe.error ?? "unknown error")")
                    }
                }
            } catch {
                self.logger.error("Failed to add MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        private func emitUserFacingError(_ message: String) {
            let data = Data((message + "\n").utf8)
            self.stderrHandle.write(data)
        }
    }

    /// Remove an MCP server
    @MainActor
    struct Remove {
        static let commandDescription = CommandDescription(
            commandName: "remove",
            abstract: "Remove an external MCP server",
            discussion: "Remove a configured MCP server and disconnect from it."
        )

        @Argument(help: "Name of the MCP server to remove")
        var name: String

        @Flag(help: "Skip confirmation prompt")
        var force = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }

        /// Disconnect and delete the specified server configuration, prompting unless forced.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let logger = self.logger
            let clientManager = MCPClientManager.shared

            // Check if server exists
            let serverInfo = await clientManager.getServerInfo(name: self.name)
            guard serverInfo != nil else {
                logger.error("MCP server '\(self.name)' not found")
                throw ExitCode.failure
            }

            // Confirm removal unless --force
            if !self.force {
                print("Remove MCP server '\(self.name)'? (y/N): ", terminator: "")
                let response = readLine() ?? ""
                if !["y", "yes"].contains(response.lowercased()) {
                    print("Cancelled.")
                    return
                }
            }

            do {
                try await clientManager.removeServer(name: self.name)
                print("✓ Removed MCP server '\(self.name)'")
            } catch {
                logger.error("Failed to remove MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }

    /// Test connection to an MCP server
    @MainActor
    struct Test {
        static let commandDescription = CommandDescription(
            commandName: "test",
            abstract: "Test connection to an MCP server",
            discussion: "Test connectivity and list available tools from an MCP server."
        )

        @Argument(help: "Name of the MCP server to test")
        var name: String

        @Option(help: "Connection timeout in seconds")
        var timeout: Double = 10.0

        @Flag(help: "Show available tools")
        var showTools = false
        @RuntimeStorage private var runtime: CommandRuntime?

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            let clientManager = MCPClientManager.shared

            print("Testing connection to MCP server '\(self.name)'...")

            let health = await clientManager.checkServerHealth(name: self.name, timeout: Int(self.timeout))

            print("\(health.symbol) \(health.statusText)")

            if health.isHealthy && self.showTools {
                let externalTools = await clientManager.getExternalTools()
                if let serverTools = externalTools[name] {
                    print("\nAvailable tools (\(serverTools.count)):")
                    for tool in serverTools.sorted(by: { $0.name < $1.name }) {
                        print("  \(tool.name) - \(tool.description ?? "")")
                    }
                }
            }
        }
    }

    /// Show detailed information about an MCP server
    @MainActor
    struct Info {
        static let commandDescription = CommandDescription(
            commandName: "info",
            abstract: "Show detailed information about an MCP server",
            discussion: "Display comprehensive information about a configured MCP server."
        )

        @Argument(help: "Name of the MCP server")
        var name: String
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }
        private var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Print configuration and live health details for the specified server in text or JSON form.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let clientManager = MCPClientManager.shared

            guard let serverInfo = await clientManager.getServerInfo(name: self.name) else {
                self.logger.error("MCP server '\(self.name)' not found")
                throw ExitCode.failure
            }

            if self.jsonOutput {
                var output: [String: Any] = [
                    "name": serverInfo.name,
                    "command": serverInfo.config.command,
                    "args": serverInfo.config.args,
                    "transport": serverInfo.config.transport,
                    "enabled": serverInfo.config.enabled,
                    "timeout": serverInfo.config.timeout,
                    "autoReconnect": serverInfo.config.autoReconnect,
                    "env": serverInfo.config.env,
                    "connected": serverInfo.health.isHealthy,
                ]

                if let description = serverInfo.config.description {
                    output["description"] = description
                }

                output["health"] = [
                    "status": serverInfo.health.isHealthy ? "connected" : "disconnected",
                    "details": serverInfo.health.statusText
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                print("Server: \(serverInfo.name)")
                print("Command: \(serverInfo.config.command) \(serverInfo.config.args.joined(separator: " "))")
                print("Transport: \(serverInfo.config.transport)")
                print("Enabled: \(serverInfo.config.enabled ? "Yes" : "No")")
                print("Timeout: \(serverInfo.config.timeout)s")
                print("Auto-reconnect: \(serverInfo.config.autoReconnect ? "Yes" : "No")")

                if !serverInfo.config.env.isEmpty {
                    print("Environment:")
                    for (key, value) in serverInfo.config.env.sorted(by: { $0.key < $1.key }) {
                        print("  \(key)=\(value)")
                    }
                }

                if let description = serverInfo.config.description {
                    print("Description: \(description)")
                }

                print("\nHealth: \(serverInfo.health.symbol) \(serverInfo.health.statusText)")
            }
        }
    }

    /// Enable an MCP server
    @MainActor
    struct Enable {
        static let commandDescription = CommandDescription(
            commandName: "enable",
            abstract: "Enable a disabled MCP server",
            discussion: "Enable a previously disabled MCP server and attempt to connect."
        )

        @Argument(help: "Name of the MCP server to enable")
        var name: String
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let clientManager = MCPClientManager.shared

            do {
                try await clientManager.enableServer(name: self.name)
                print("✓ Enabled MCP server '\(self.name)'")

                print("Testing connection...")
                let health = await clientManager.checkServerHealth(name: self.name)
                print("\(health.symbol) \(health.statusText)")
            } catch {
                self.logger.error("Failed to enable MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }

    /// Disable an MCP server
    @MainActor
    struct Disable {
        static let commandDescription = CommandDescription(
            commandName: "disable",
            abstract: "Disable an MCP server",
            discussion: "Disable an MCP server without removing its configuration."
        )

        @Argument(help: "Name of the MCP server to disable")
        var name: String
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let clientManager = MCPClientManager.shared

            do {
                try await clientManager.disableServer(name: self.name)
                print("✓ Disabled MCP server '\(self.name)'")
            } catch {
                self.logger.error("Failed to disable MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }

    /// Inspect MCP connection
    @MainActor
    struct Inspect {
        static let commandDescription = CommandDescription(
            commandName: "inspect",
            abstract: "Debug MCP connections",
            discussion: "Provides debugging information for MCP connections."
        )

        @Argument(help: "Server to inspect")
        var server: String?
        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger { self.resolvedRuntime.logger }

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.error("MCP inspection not yet implemented")
            throw ExitCode.failure
        }
    }
}

@MainActor
extension MCPCommand.List: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "list",
                abstract: "List configured MCP servers with health status",
                discussion: """
                Shows all configured external MCP servers along with their current health status.
                Health checking verifies connectivity and counts available tools.

                EXAMPLE OUTPUT:
                  Checking MCP server health...
                  
                  github: npx -y @modelcontextprotocol/server-github - ✓ Connected (12 tools)
                  files: npx -y @modelcontextprotocol/server-filesystem - ✗ Failed to connect
                """
            )
        }
    }
}

extension MCPCommand.List: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Add: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "add",
                abstract: "Add a new external MCP server",
                discussion: """
                Add a new external MCP server that Peekaboo can connect to and use tools from.

                EXAMPLES:
                  # Stdio servers (most common):
                  peekaboo mcp add github -- npx -y @modelcontextprotocol/server-github
                  peekaboo mcp add files -- npx -y @modelcontextprotocol/server-filesystem /Users/me/docs
                  peekaboo mcp add weather -e API_KEY=xyz123 -- /usr/local/bin/weather-server
                  
                  # HTTP/SSE servers (remote):
                  peekaboo mcp add context7 --transport sse -- https://mcp.context7.com/mcp
                  peekaboo mcp add myserver --transport http -- https://api.example.com/mcp
                """
            )
        }
    }
}

extension MCPCommand.Add: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Remove: ParsableCommand {}
extension MCPCommand.Remove: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Test: ParsableCommand {}
extension MCPCommand.Test: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Info: ParsableCommand {}
extension MCPCommand.Info: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Enable: ParsableCommand {}
extension MCPCommand.Enable: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Disable: ParsableCommand {}
extension MCPCommand.Disable: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Inspect: ParsableCommand {}
extension MCPCommand.Inspect: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Serve: ParsableCommand {}
extension MCPCommand.Serve: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Call: ParsableCommand {}
extension MCPCommand.Call: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Call: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.server = try values.requiredPositional(0, label: "server")
        self.tool = try values.requiredPositional(1, label: "tool")
        if let argsValue = values.singleOption("args") {
            self.args = argsValue
        }
    }
}
