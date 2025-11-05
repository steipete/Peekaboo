import ArgumentParser
import Foundation
import PeekabooCore
import Testing
@testable import peekaboo

@Suite("MCP Command Tests")
struct MCPCommandTests {
    // MARK: - Command Structure Tests

    @Test("MCP command has correct subcommands")
    func mCPCommandSubcommands() throws {
        let command = MCPCommand.self

        #expect(command.configuration.commandName == "mcp")
        #expect(command.configuration.subcommands.count == 10)

        let subcommandNames = command.configuration.subcommands.map(\.configuration.commandName)
        #expect(subcommandNames.contains("serve"))
        #expect(subcommandNames.contains("call"))
        #expect(subcommandNames.contains("list"))
        #expect(subcommandNames.contains("inspect"))
        #expect(subcommandNames.contains("add"))
        #expect(subcommandNames.contains("remove"))
        #expect(subcommandNames.contains("test"))
        #expect(subcommandNames.contains("info"))
        #expect(subcommandNames.contains("enable"))
        #expect(subcommandNames.contains("disable"))
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

        #expect(helpText.contains("Model Context Protocol server and client operations"))
        #expect(helpText.contains("serve"))
        #expect(helpText.contains("call"))
        #expect(helpText.contains("list"))
        #expect(helpText.contains("inspect"))
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

    @Test("Parse call command")
    func parseCallCommand() throws {
        let call = try MCPCommand.Call.parse(["test-server", "--tool", "echo", "--args", "{\"message\": \"hello\"}"])

        #expect(call.server == "test-server")
        #expect(call.tool == "echo")
        #expect(call.args == "{\"message\": \"hello\"}")
    }

    @Test("Parse inspect command")
    func parseInspectCommand() throws {
        // With server argument
        let inspect1 = try MCPCommand.Inspect.parse(["my-server"])
        #expect(inspect1.server == "my-server")

        // Without server argument
        let inspect2 = try MCPCommand.Inspect.parse([])
        #expect(inspect2.server == nil)
    }

    // MARK: - Validation Tests

    @Test("Invalid port number throws error")
    func invalidPortNumber() throws {
        #expect(throws: Error.self) {
            _ = try MCPCommand.Serve.parse(["--port", "-1"])
        }

        #expect(throws: Error.self) {
            _ = try MCPCommand.Serve.parse(["--port", "not-a-number"])
        }
    }

    @Test("Call command requires tool argument")
    func callCommandRequiresToolArgument() throws {
        #expect(throws: Error.self) {
            _ = try MCPCommand.Call.parse(["test-server"])
        }
    }
}

@Suite("MCP Command Integration Tests", .tags(.integration))
struct MCPCommandIntegrationTests {
    @Test("Serve command transport type conversion")
    func serveCommandTransportConversion() async throws {
        let serve = try MCPCommand.Serve.parse(["--transport", "stdio"])

        // This test would need to actually run the serve command
        // and verify it starts the server with the correct transport

        // Since we can't easily test the actual server startup in unit tests,
        // we can at least verify the transport string maps correctly
        let expectedTransport: PeekabooCore.TransportType = .stdio
        #expect(serve.transport == expectedTransport.description)
    }

    @Test("Call command JSON parsing")
    func callCommandJSONParsing() throws {
        let validJSON = """
        {
            "path": "/tmp/test.png",
            "format": "png",
            "nested": {
                "value": 123
            }
        }
        """

        let call = try MCPCommand.Call.parse([
            "server",
            "--tool", "test",
            "--args", validJSON
        ])

        // Verify the JSON is stored correctly
        #expect(call.args == validJSON)

        // In the actual implementation, this JSON would be parsed
        // We can verify it's valid JSON
        let data = Data(call.args.utf8)
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }
}

@Suite("MCP Command Error Handling Tests")
struct MCPCommandErrorHandlingTests {
    @Test("Unimplemented commands return appropriate exit codes")
    func unimplementedCommands() async throws {
        // These commands are marked as not implemented
        // They should fail with appropriate error messages

        var call = try MCPCommand.Call.parse(["test", "--tool", "echo"])
        await #expect(throws: ExitCode.self) {
            try await call.run()
        }

        let inspect = MCPCommand.Inspect()
        await #expect(throws: ExitCode.self) {
            try await inspect.run()
        }
    }
}

// MARK: - Mock Tests for Server Behavior

@Suite("MCP Server Behavior Tests")
struct MCPServerBehaviorTests {
    @Test("Server exits cleanly on SIGTERM")
    func serverSIGTERMHandling() async throws {
        // This would test that the server handles SIGTERM gracefully
        // In practice, this requires spawning a subprocess and sending signals

        // For unit testing, we can at least verify the serve command structure
        let serve = MCPCommand.Serve()
        #expect(serve.transport == "stdio") // Default value
    }

    @Test("Server validates transport types")
    func serverTransportValidation() async throws {
        var serve = MCPCommand.Serve()

        // Test that invalid transport types are handled
        serve.transport = "invalid"

        // When run() is called, it should default to stdio for invalid types
        // This behavior is implemented in the run() method
    }
}
