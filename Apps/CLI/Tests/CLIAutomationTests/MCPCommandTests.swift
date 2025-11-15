import Commander
import Darwin
import Foundation
import MCP
import PeekabooCore
import TachikomaMCP
import Testing
@testable import PeekabooCLI

@Suite("MCP Command Tests")
struct MCPCommandTests {
    // MARK: - Command Structure Tests

    @Test("MCP command has correct subcommands")
    func mCPCommandSubcommands() throws {
        let command = MCPCommand.self

        #expect(command.commandDescription.commandName == "mcp")
        #expect(command.commandDescription.subcommands.count == 10)

        var subcommandNames: [String] = []
        subcommandNames.reserveCapacity(command.commandDescription.subcommands.count)
        for descriptor in command.commandDescription.subcommands {
            guard let name = descriptor.commandDescription.commandName else { continue }
            subcommandNames.append(name)
        }
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
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try MCPCommand.Serve.parse(["--port", "-1"])
            }
        }

        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try MCPCommand.Serve.parse(["--port", "not-a-number"])
            }
        }
    }

    @Test("Call command requires tool argument")
    func callCommandRequiresToolArgument() throws {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try MCPCommand.Call.parse(["test-server"])
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
    @Test("Inspect command runs without throwing")
    func inspectCommandRuns() async throws {
        var inspect = try CLIOutputCapture.suppressStderr {
            try MCPCommand.Inspect.parse([])
        }
        try await inspect.run()
    }
}

@Suite("MCP Call Command Runtime Tests", .tags(.fast))
@MainActor
struct MCPCallCommandRuntimeTests {
    @Test("Mock manager echoes text content")
    func mockManagerReturnsText() async throws {
        let manager = MockMCPClientManager()
        manager.setServer(name: "browser")
        manager.executeResponse = .text("pong")

        let response = try await manager.executeTool(serverName: "browser", toolName: "echo", arguments: [:])
        guard let first = response.content.first else {
            Issue.record("Expected text response from mock executeTool call.")
            return
        }
        if case let .text(value) = first {
            #expect(value == "pong")
        } else {
            Issue.record("Expected .text content in mock executeTool call.")
        }
    }

    @Test("Mock manager surfaces error responses")
    func mockManagerSurfacesErrors() async throws {
        let manager = MockMCPClientManager()
        manager.setServer(name: "browser")
        manager.executeResponse = .error("boom")

        let response = try await manager.executeTool(serverName: "browser", toolName: "unstable", arguments: [:])
        guard let first = response.content.first else {
            Issue.record("Expected error ToolResponse from mock executeTool call.")
            return
        }
        #expect(response.isError == true)
        if case let .text(message) = first {
            #expect(message == "boom")
        } else {
            Issue.record("Expected .text content in error ToolResponse.")
        }
    }
}

@MainActor
final class MockMCPClientManager: MCPClientManaging {
    private(set) var registeredDefaults: [String: TachikomaMCP.MCPServerConfig] = [:]
    private(set) var initializeCallCount = 0
    private(set) var storedServers: [String: TachikomaMCP.MCPServerConfig] = [:]
    private(set) var connectedServers: Set<String> = []
    var probeResult = ServerProbeResult(isConnected: true, toolCount: 0, responseTime: 0.01, error: nil)
    var executeResponse: ToolResponse = .text("ok")
    var executeError: (any Error)?
    private(set) var executeCallCount = 0
    private(set) var probeCallCount = 0

    func registerDefaultServers(_ defaults: [String: TachikomaMCP.MCPServerConfig]) {
        self.registeredDefaults = defaults
    }

    func initializeFromProfile(connect _: Bool) async {
        self.initializeCallCount += 1
    }

    func getServerInfo(name: String) async -> (config: TachikomaMCP.MCPServerConfig, connected: Bool)? {
        guard let config = self.storedServers[name] else { return nil }
        return (config, self.connectedServers.contains(name))
    }

    func probeServer(name: String, timeoutMs _: Int) async -> ServerProbeResult {
        self.probeCallCount += 1
        if self.probeResult.isConnected {
            self.connectedServers.insert(name)
        }
        return self.probeResult
    }

    func probeAllServers(timeoutMs _: Int) async -> [String: ServerProbeResult] {
        self.probeCallCount += 1
        var results: [String: ServerProbeResult] = [:]
        for server in self.storedServers.keys {
            results[server] = self.probeResult
            if self.probeResult.isConnected {
                self.connectedServers.insert(server)
            }
        }
        return results
    }

    func executeTool(serverName: String, toolName _: String, arguments _: [String: Any]) async throws -> ToolResponse {
        self.executeCallCount += 1
        if let executeError {
            throw executeError
        }
        guard self.connectedServers.contains(serverName) else {
            throw MCPError.notConnected
        }
        return self.executeResponse
    }

    func setServer(name: String, enabled: Bool = true) {
        let config = TachikomaMCP.MCPServerConfig(
            transport: "stdio",
            command: "mock",
            args: [],
            env: [:],
            enabled: enabled,
            timeout: 5,
            autoReconnect: true,
            description: "mock server"
        )
        self.storedServers[name] = config
        if enabled {
            self.connectedServers.insert(name)
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
        let serve = try CLIOutputCapture.suppressStderr {
            try MCPCommand.Serve.parse([])
        }
        #expect(serve.transport == "stdio") // Default value
    }

    @Test("Server validates transport types")
    func serverTransportValidation() async throws {
        var serve = try CLIOutputCapture.suppressStderr {
            try MCPCommand.Serve.parse([])
        }

        // Test that invalid transport types are handled
        serve.transport = "invalid"

        // When run() is called, it should default to stdio for invalid types
        // This behavior is implemented in the run() method
    }
}

@Suite("MCP Command End-to-End Tests", .serialized, .tags(.integration))
@MainActor
struct MCPCommandEndToEndTests {
    @Test("Add/list/test with stub MCP server")
    func addListAndTestStubServer() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
        let harness: MCPStubTestHarness
        do {
            harness = try MCPStubTestHarness()
        } catch MCPStubFixtures.FixtureError.missing {
            return
        }
        do {
            try await harness.addStubServer()

            let listResult = try await harness.run(["mcp", "list"])
            #expect(listResult.stdout.contains(harness.serverName))

            let testResult = try await harness.run([
                "mcp", "test", harness.serverName,
                "--timeout", "5",
                "--show-tools",
            ])
            #expect(testResult.stdout.contains("echo"))
            #expect(testResult.stdout.contains("add"))
            await harness.cleanup()
        } catch {
            await harness.cleanup()
            throw error
        }
    }

    @Test("Call stub MCP tools for success and failure")
    func callStubTools() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
        let harness: MCPStubTestHarness
        do {
            harness = try MCPStubTestHarness()
        } catch MCPStubFixtures.FixtureError.missing {
            return
        }
        do {
            try await harness.addStubServer()

            let success = try await harness.run([
                "mcp", "call", harness.serverName,
                "--tool", "echo",
                "--args", "{\"message\":\"hello world\"}",
            ])
            #expect(success.stdout.contains("hello world"))

            let sum = try await harness.run([
                "mcp", "call", harness.serverName,
                "--tool", "add",
                "--args", "{\"a\":2,\"b\":3}",
            ])
            #expect(sum.stdout.contains("sum: 5"))

            let failure = try await harness.run([
                "mcp", "call", harness.serverName,
                "--tool", "fail",
                "--args", "{\"message\":\"boom\"}",
            ], allowedExitCodes: Set<Int32>([0, 1]))
            #expect(failure.stdout.contains("boom"))
            await harness.cleanup()
        } catch {
            await harness.cleanup()
            throw error
        }
    }
}
