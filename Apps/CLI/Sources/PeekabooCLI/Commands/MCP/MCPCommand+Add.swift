//
//  MCPCommand+Add.swift
//  PeekabooCLI
//

import Commander
import Foundation
import Logging
import PeekabooCore
import TachikomaMCP

extension MCPCommand {
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
        private let stderrHandle = FileHandle.standardError
        var service: any MCPClientService = DefaultMCPClientService.shared

        /// Validate the provided command, persist the new server configuration, and immediately probe connectivity.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)

            guard !self.command.isEmpty else {
                let message = "Command is required. Use -- to separate command from options."
                context.logger.error(message)
                self.emitUserFacingError(message)
                throw ExitCode.failure
            }

            let envDict: [String: String]
            do {
                envDict = try MCPArgumentParsing.parseKeyValueList(self.env, label: "environment variable")
                _ = try MCPArgumentParsing.parseKeyValueList(self.header, label: "header")
            } catch let error as MCPCommandError {
                context.logger.error(error.localizedDescription)
                throw ExitCode.failure
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

            await context.service.bootstrap(connect: false)

            do {
                try await context.service.addServer(name: self.name, config: config)
                try context.service.persist()
                print("✓ Added MCP server '\(self.name)' and saved to profile")

                if !self.disabled {
                    print("Testing connection (\(Int(self.timeout))s timeout)...")
                    let probe = await context.service.probe(name: self.name, timeoutMs: Int(self.timeout * 1000))
                    switch probe {
                    case let .connected(toolCount, responseTime):
                        print("✓ Connected in \(Int(responseTime * 1000))ms (\(toolCount) tools)")
                    case let .disconnected(error):
                        print("✗ Failed: \(error)")
                    case .disabled:
                        print("✗ Failed: server disabled")
                    case .connecting:
                        print("⏳ Connecting...")
                    case .unknown:
                        print("✗ Failed: unknown status")
                    }
                }
            } catch {
                context.logger.error("Failed to add MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        private func emitUserFacingError(_ message: String) {
            let data = Data((message + "\n").utf8)
            self.stderrHandle.write(data)
        }
    }
}

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
