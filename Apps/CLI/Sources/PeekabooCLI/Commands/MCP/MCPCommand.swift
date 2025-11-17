//
//  MCPCommand.swift
//  PeekabooCLI
//

import Commander
import Foundation
import PeekabooCore

/// Entry point for Model Context Protocol related subcommands.
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
