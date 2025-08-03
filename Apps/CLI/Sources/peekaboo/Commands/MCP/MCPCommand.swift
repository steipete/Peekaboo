import ArgumentParser
import Foundation
import Logging
import MCP
import PeekabooCore

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
            Call.self,
            List.self,
            Inspect.self,
        ]
    )
}

// MARK: - Subcommands

extension MCPCommand {
    /// Start MCP server
    struct Serve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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

    /// List available MCP servers
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available MCP servers",
            discussion: "Shows configured MCP servers that can be connected to."
        )

        func run() async throws {
            Logger.shared.error("MCP server listing not yet implemented")
            throw ExitCode.failure
        }
    }

    /// Inspect MCP connection
    struct Inspect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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
