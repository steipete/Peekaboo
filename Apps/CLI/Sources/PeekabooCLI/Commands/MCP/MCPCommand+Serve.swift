//
//  MCPCommand+Serve.swift
//  PeekabooCLI
//

import Commander
import Logging
import PeekabooCore

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
              claude mcp add peekaboo -- peekaboo mcp

            USAGE WITH MCP INSPECTOR:
              npx @modelcontextprotocol/inspector peekaboo mcp serve
            """
        )

        @Option(help: "Transport type (stdio, http, sse)")
        var transport: String = "stdio"

        @Option(help: "Port for HTTP/SSE transport")
        var port: Int = 8080

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            do {
                // Convert string transport to PeekabooCore.TransportType
                let transportType: PeekabooCore.TransportType = switch self.transport.lowercased() {
                case "stdio": .stdio
                case "http": .http
                case "sse": .sse
                default: .stdio
                }

                if runtime.services is RemotePeekabooServices {
                    runtime.logger.debug("MCP: using remote Bridge host; skipping local daemon startup")
                } else {
                    let daemon = PeekabooDaemon(configuration: .mcp())
                    await daemon.start()
                }

                let server = try await PeekabooMCPServer()
                try await server.serve(transport: transportType, port: self.port)
            } catch {
                runtime.logger.error("Failed to start MCP server: \(error)")
                throw ExitCode.failure
            }
        }
    }
}

@MainActor
extension MCPCommand.Serve: ParsableCommand {}
extension MCPCommand.Serve: AsyncRuntimeCommand {}

extension MCPCommand.Serve: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        if let transportOption = values.singleOption("transport") {
            self.transport = transportOption
        }
        if let portOption = try values.decodeOption("port", as: Int.self) {
            self.port = portOption
        }
    }
}
