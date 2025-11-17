//
//  MCPCommand+List.swift
//  PeekabooCLI
//

import Commander
import Darwin
import Foundation
import Logging
import PeekabooCore
import TachikomaMCP

extension MCPCommand {
    /// List available MCP servers with health checking
    struct List {
        @Flag(name: .long, help: "Skip health checks (faster)")
        var skipHealthCheck = false
        var service: any MCPClientService = DefaultMCPClientService.shared

        /// Initialize the MCP client manager, optionally probe server health, and render the chosen output format.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)

            // Suppress os_log output unless verbose
            let originalStderr = dup(STDERR_FILENO)
            let devNull = open("/dev/null", O_WRONLY)
            if !context.isVerbose && devNull != -1 {
                // Redirect stderr to /dev/null to suppress os_log output
                dup2(devNull, STDERR_FILENO)
            }

            await context.service.bootstrap(connect: false)
            let serverNames = context.service.serverNames()

            // Restore stderr after initialization
            if !context.isVerbose && devNull != -1 {
                dup2(originalStderr, STDERR_FILENO)
                close(devNull)
                close(originalStderr)
            }

            if serverNames.isEmpty {
                if context.wantsJSON {
                    let output = ["servers": [String: Any](), "summary": ["total": 0, "healthy": 0]] as [String: Any]
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

            if !self.skipHealthCheck && !context.wantsJSON {
                print("Checking MCP server health...")
                print()
            }

            // Suppress os_log output during health checks unless verbose
            let originalStderr2 = dup(STDERR_FILENO)
            let devNull2 = open("/dev/null", O_WRONLY)
            if !context.isVerbose && devNull2 != -1 {
                dup2(devNull2, STDERR_FILENO)
            }

            // Get health status for all servers (5 second timeout should be sufficient)
            let healthResults = await context.service.probeAll(timeoutMs: 5000)

            // Restore stderr after health checks
            if !context.isVerbose && devNull2 != -1 {
                dup2(originalStderr2, STDERR_FILENO)
                close(devNull2)
                close(originalStderr2)
            }

            if context.wantsJSON {
                try await self.outputJSON(serverNames: serverNames, healthResults: healthResults, context: context)
            } else {
                await self.outputFormatted(serverNames: serverNames, healthResults: healthResults, context: context)
            }
        }

        /// Render the MCP server inventory and health probes as a JSON payload compatible with scripting use.
        private func outputJSON(
            serverNames: [String],
            healthResults: [String: MCPServerHealth],
            context: MCPCommandContext
        ) async throws {
            var servers: [String: Any] = [:]
            var healthyCount = 0

            for serverName in serverNames {
                let info = await context.service.serverInfo(name: serverName)
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
        private func outputFormatted(
            serverNames: [String],
            healthResults: [String: MCPServerHealth],
            context: MCPCommandContext
        ) async {
            var healthyCount = 0

            for serverName in serverNames.sorted() {
                let serverInfo = await context.service.serverInfo(name: serverName)
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
            let externalTools = await context.service.externalToolsByServer()
            let totalExternalTools = externalTools.values.reduce(0) { $0 + $1.count }
            if totalExternalTools > 0 {
                print("External tools available: \(totalExternalTools)")
            }
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
