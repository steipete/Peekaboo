import ArgumentParser
import Foundation
import Logging
import MCP
import PeekabooCore
import TachikomaMCP

/// Command for Model Context Protocol server operations
struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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
        ]
    )
}

// MARK: - Subcommands

extension MCPCommand {
    /// Start MCP server
    struct Serve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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

        func run() async throws {
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
                Logger.shared.error("Failed to start MCP server: \(error)")
                throw ExitCode.failure
            }
        }
    }

    /// Call tool on MCP server
    struct Call: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "call",
            abstract: "Call a tool on another MCP server",
            discussion: """
            Connect to another MCP server and execute a tool. This allows
            Peekaboo to consume services from other MCP servers.

            EXAMPLE:
              peekaboo mcp call claude-code edit_file --args '{"path": "main.swift"}'
            """
        )

        @Argument(help: "MCP server to connect to")
        var server: String

        @Option(help: "Tool to call")
        var tool: String

        @Option(help: "Tool arguments as JSON")
        var args: String = "{}"

        func run() async throws {
            Logger.shared.error("MCP client functionality not yet implemented")
            throw ExitCode.failure
        }
    }

    /// List available MCP servers with health checking
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        @Flag(name: .long, help: "Skip health checks (faster)")
        var skipHealthCheck = false
        
        @Flag(name: .long, help: "Show verbose output including connection logs")
        var verbose = false

        func run() async throws {
                // Set verbose mode if requested
                if verbose {
                    Logger.shared.setVerboseMode(true)
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
                await TachikomaMCPClientManager.shared.registerDefaultServers(["browser": defaultBrowser])
                
                // Suppress os_log output unless verbose
                let originalStderr = dup(STDERR_FILENO)
                let devNull = open("/dev/null", O_WRONLY)
                if !verbose && devNull != -1 {
                    // Redirect stderr to /dev/null to suppress os_log output
                    dup2(devNull, STDERR_FILENO)
                }
                
                // Initialize Tachikoma MCP manager (don't connect yet - let health check measure timing)
                await TachikomaMCPClientManager.shared.initializeFromProfile(connect: false)
                let serverNames = await TachikomaMCPClientManager.shared.getServerNames()
                
                // Restore stderr after initialization
                if !verbose && devNull != -1 {
                    dup2(originalStderr, STDERR_FILENO)
                    close(devNull)
                    close(originalStderr)
                }
            
            if serverNames.isEmpty {
                if jsonOutput {
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
            
            if !skipHealthCheck && !jsonOutput {
                print("Checking MCP server health...")
                print()
            }
            
            // Suppress os_log output during health checks unless verbose
            let originalStderr2 = dup(STDERR_FILENO)
            let devNull2 = open("/dev/null", O_WRONLY)
            if !verbose && devNull2 != -1 {
                dup2(devNull2, STDERR_FILENO)
            }
            
            // Get health status for all servers (5 second timeout should be sufficient)
            let probes = await TachikomaMCPClientManager.shared.probeAllServers(timeoutMs: 5000)
            var healthResults: [String: MCPServerHealth] = [:]
            for (name, (ok, count, rt, err)) in probes {
                healthResults[name] = ok ? .connected(toolCount: count, responseTime: rt) : .disconnected(error: err ?? "unknown error")
            }
            
            // Restore stderr after health checks
            if !verbose && devNull2 != -1 {
                dup2(originalStderr2, STDERR_FILENO)
                close(devNull2)
                close(originalStderr2)
            }
            
            if jsonOutput {
                try await outputJSON(serverNames: serverNames, healthResults: healthResults)
            } else {
                await outputFormatted(serverNames: serverNames, healthResults: healthResults)
            }
        }
        
        private func outputJSON(serverNames: [String], healthResults: [String: MCPServerHealth]) async throws {
            var servers: [String: Any] = [:]
            var healthyCount = 0
            
            for serverName in serverNames {
                let info = await TachikomaMCPClientManager.shared.getServerInfo(name: serverName)
                let isEnabled = info?.config.enabled ?? false
                let command = info?.config.command ?? ""
                let args = info?.config.args ?? []
                let isConnected = info?.connected ?? false
                let health: MCPServerHealth = healthResults[serverName] ?? (isConnected ? .connected(toolCount: 0, responseTime: 0) : .unknown)

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
                                    // Scoped package like @playwright/mcp
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
        
        private func outputFormatted(serverNames: [String], healthResults: [String: MCPServerHealth]) async {
            var healthyCount = 0
            
            for serverName in serverNames.sorted() {
                let serverInfo = await TachikomaMCPClientManager.shared.getServerInfo(name: serverName)
                let health = healthResults[serverName] ?? (serverInfo?.connected == true ? .connected(toolCount: 0, responseTime: 0) : .unknown)
                
                if health.isHealthy {
                    healthyCount += 1
                }
                
                let command = serverInfo?.config.command ?? "unknown"
                let args = serverInfo?.config.args ?? []
                let simplifiedCommand = simplifyCommandPath(command: command, args: args)
                
                let healthSymbol = health.symbol
                let healthText = health.statusText
                
                // Show if this is a default server
                let isDefault = (serverName == "browser")
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
    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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
        
        @Argument(help: "Name for the MCP server")
        var name: String
        
        @Option(name: .shortAndLong, help: "Environment variables (key=value)")
        var env: [String] = []
        
        @Option(name: .long, parsing: .upToNextOption, help: "HTTP headers for HTTP/SSE (Key=Value)")
        var header: [String] = []
        
        @Option(help: "Connection timeout in seconds")
        var timeout: Double = 10.0
        
        @Option(help: "Transport type (stdio, http, sse)")
        var transport: String = "stdio"
        
        @Option(help: "Description of the server")
        var description: String?
        
        @Flag(help: "Disable the server after adding")
        var disabled = false
        
        @Argument(parsing: .remaining, help: "Command and arguments to run the MCP server")
        var command: [String] = []
        
        func run() async throws {
            guard !command.isEmpty else {
                Logger.shared.error("Command is required. Use -- to separate command from options.")
                throw ExitCode.failure
            }

            // Parse environment variables
            var envDict: [String: String] = [:]
            for envVar in env {
                let parts = envVar.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    envDict[String(parts[0])] = String(parts[1])
                } else {
                    Logger.shared.error("Invalid environment variable format: \(envVar). Use key=value")
                    throw ExitCode.failure
                }
            }

            // Parse headers
            var headersDict: [String: String] = [:]
            for h in header {
                let parts = h.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    headersDict[String(parts[0])] = String(parts[1])
                } else {
                    Logger.shared.error("Invalid header format: \(h). Use Key=Value")
                    throw ExitCode.failure
                }
            }

            // Create Tachikoma MCP server config
            let config = TachikomaMCP.MCPServerConfig(
                transport: transport,
                command: command[0],
                args: Array(command.dropFirst()),
                env: envDict,
                enabled: !disabled,
                timeout: timeout,
                autoReconnect: true,
                description: description
            )

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
            await TachikomaMCPClientManager.shared.registerDefaultServers(["browser": defaultBrowser])
            
            // Load existing profile configs, add server, persist, then probe
            await TachikomaMCPClientManager.shared.initializeFromProfile(connect: false)

            do {
                try await TachikomaMCPClientManager.shared.addServer(name: name, config: config)
                try await TachikomaMCPClientManager.shared.persist()
                print("✓ Added MCP server '\(name)' and saved to profile")

                if !disabled {
                    print("Testing connection (\(Int(timeout))s timeout)...")
                    let (ok, count, rt, err) = await TachikomaMCPClientManager.shared.probeServer(name: name, timeoutMs: Int(timeout * 1000))
                    if ok {
                        print("✓ Connected in \(Int(rt * 1000))ms (\(count) tools)")
                    } else {
                        print("✗ Failed: \(err ?? "unknown error")")
                    }
                }
            } catch {
                Logger.shared.error("Failed to add MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    /// Remove an MCP server
    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove an external MCP server",
            discussion: "Remove a configured MCP server and disconnect from it."
        )
        
        @Argument(help: "Name of the MCP server to remove")
        var name: String
        
        @Flag(help: "Skip confirmation prompt")
        var force = false
        
        func run() async throws {
            let clientManager = await MCPClientManager.shared
            
            // Check if server exists
            let serverInfo = await clientManager.getServerInfo(name: name)
            guard serverInfo != nil else {
                Logger.shared.error("MCP server '\(name)' not found")
                throw ExitCode.failure
            }
            
            // Confirm removal unless --force
            if !force {
                print("Remove MCP server '\(name)'? (y/N): ", terminator: "")
                let response = readLine() ?? ""
                if !["y", "yes"].contains(response.lowercased()) {
                    print("Cancelled.")
                    return
                }
            }
            
            do {
                try await clientManager.removeServer(name: name)
                print("✓ Removed MCP server '\(name)'")
            } catch {
                Logger.shared.error("Failed to remove MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    /// Test connection to an MCP server
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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
        
        func run() async throws {
            let clientManager = await MCPClientManager.shared
            
            print("Testing connection to MCP server '\(name)'...")
            
            let health = await clientManager.checkServerHealth(name: name, timeout: Int(timeout))
            
            print("\(health.symbol) \(health.statusText)")
            
            if health.isHealthy && showTools {
                let externalTools = await clientManager.getExternalTools()
                if let serverTools = externalTools[name] {
                    print("\nAvailable tools (\(serverTools.count)):")
                    for tool in serverTools.sorted(by: { $0.name < $1.name }) {
                        print("  \(tool.name) - \(tool.description)")
                    }
                }
            }
        }
    }
    
    /// Show detailed information about an MCP server
    struct Info: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Show detailed information about an MCP server",
            discussion: "Display comprehensive information about a configured MCP server."
        )
        
        @Argument(help: "Name of the MCP server")
        var name: String
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        func run() async throws {
            let clientManager = await MCPClientManager.shared
            
            guard let serverInfo = await clientManager.getServerInfo(name: name) else {
                Logger.shared.error("MCP server '\(name)' not found")
                throw ExitCode.failure
            }
            
            if jsonOutput {
                let output: [String: Any] = [
                    "name": serverInfo.name,
                    "config": [
                        "command": serverInfo.config.command,
                        "args": serverInfo.config.args,
                        "transport": serverInfo.config.transport,
                        "enabled": serverInfo.config.enabled,
                        "timeout": serverInfo.config.timeout,
                        "autoReconnect": serverInfo.config.autoReconnect,
                        "env": serverInfo.config.env
                    ],
                    "health": [
                        "status": serverInfo.health.isHealthy ? "connected" : "disconnected",
                        "details": serverInfo.health.statusText
                    ],
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
    struct Enable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable a disabled MCP server",
            discussion: "Enable a previously disabled MCP server and attempt to connect."
        )
        
        @Argument(help: "Name of the MCP server to enable")
        var name: String
        
        func run() async throws {
            let clientManager = await MCPClientManager.shared
            
            do {
                try await clientManager.enableServer(name: name)
                print("✓ Enabled MCP server '\(name)'")
                
                // Test connection
                print("Testing connection...")
                let health = await clientManager.checkServerHealth(name: name)
                print("\(health.symbol) \(health.statusText)")
            } catch {
                Logger.shared.error("Failed to enable MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    /// Disable an MCP server
    struct Disable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable an MCP server",
            discussion: "Disable an MCP server without removing its configuration."
        )
        
        @Argument(help: "Name of the MCP server to disable")
        var name: String
        
        func run() async throws {
            let clientManager = await MCPClientManager.shared
            
            do {
                try await clientManager.disableServer(name: name)
                print("✓ Disabled MCP server '\(name)'")
            } catch {
                Logger.shared.error("Failed to disable MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }

    /// Inspect MCP connection
    struct Inspect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Debug MCP connections",
            discussion: "Provides debugging information for MCP connections."
        )

        @Argument(help: "Server to inspect", completion: .default)
        var server: String?

        func run() async throws {
            Logger.shared.error("MCP inspection not yet implemented")
            throw ExitCode.failure
        }
    }
}
