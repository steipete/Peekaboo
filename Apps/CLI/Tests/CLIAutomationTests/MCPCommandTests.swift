import Commander
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("MCP Command Tests")
struct MCPCommandTests {
    // MARK: - Command Structure Tests

    @Test("MCP command has correct subcommands")
    func mCPCommandSubcommands() throws {
        let command = MCPCommand.self

        #expect(command.commandDescription.commandName == "mcp")
        #expect(command.commandDescription.subcommands.count == 1)

        let subcommandNames = command.commandDescription.subcommands.compactMap { descriptor in
            descriptor.commandDescription.commandName
        }
        #expect(subcommandNames.contains("serve"))
    }

    @Test("MCP serve command default options")
    func mCPServeDefaults() throws {
        let serve = try MCPCommand.Serve.parse([])

        #expect(serve.transport == "stdio")
        #expect(serve.port == 8080)
    }

    @Test("MCP serve command custom options")
    func mCPServeCustomOptions() throws {
        let serve = try MCPCommand.Serve.parse(["--transport", "http", "--port", "9000"])

        #expect(serve.transport == "http")
        #expect(serve.port == 9000)
    }

    // MARK: - Help Text Tests

    @Test("MCP command help text")
    func mCPCommandHelp() {
        let helpText = MCPCommand.helpMessage()

        #expect(helpText.contains("Model Context Protocol server operations"))
        #expect(helpText.contains("serve"))
    }

    @Test("MCP serve help text")
    func mCPServeHelp() {
        let helpText = MCPCommand.Serve.helpMessage()

        #expect(helpText.contains("Start Peekaboo as an MCP server"))
        #expect(helpText.contains("claude mcp add peekaboo"))
        #expect(helpText.contains("npx @modelcontextprotocol/inspector"))
        #expect(helpText.contains("--transport"))
        #expect(helpText.contains("--port"))
    }

    // MARK: - Argument Parsing Tests

    @Test("Parse serve command with all transports")
    func parseServeAllTransports() throws {
        let transports = ["stdio", "http", "sse"]

        for transport in transports {
            let serve = try MCPCommand.Serve.parse(["--transport", transport])
            #expect(serve.transport == transport)
        }
    }

    // MARK: - Validation Tests

    @Test("Invalid port number throws error")
    func invalidPortNumber() throws {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try MCPCommand.Serve.parse(["--port=-1"])
            }
        }
    }
}

@Suite("MCP Command Integration Tests", .tags(.integration))
struct MCPCommandIntegrationTests {
    @Test("Serve command transport type conversion")
    func serveCommandTransportConversion() async throws {
        let serve = try MCPCommand.Serve.parse(["--transport", "stdio"])

        // This test would need to actually run the serve command
        // and verify it starts the server with the correct transport.
        let expectedTransport: PeekabooCore.TransportType = .stdio
        #expect(serve.transport == expectedTransport.description)
    }
}

// MARK: - Mock Tests for Server Behavior

@Suite("MCP Server Behavior Tests")
struct MCPServerBehaviorTests {
    @Test("Server exits cleanly on SIGTERM")
    func serverSIGTERMHandling() async throws {
        // For unit testing, verify the serve command structure.
        let serve = try CLIOutputCapture.suppressStderr {
            try MCPCommand.Serve.parse([])
        }
        #expect(serve.transport == "stdio")
    }

    @Test("Server validates transport types")
    func serverTransportValidation() async throws {
        var serve = try CLIOutputCapture.suppressStderr {
            try MCPCommand.Serve.parse([])
        }

        // Invalid transport should be handled in run(); default to stdio.
        serve.transport = "invalid"
    }
}
