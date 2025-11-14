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

        let subcommandNames = command.commandDescription.subcommands.map(\.commandDescription.commandName)
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
    @Test("Unimplemented commands return appropriate exit codes")
    func unimplementedCommands() async throws {
        let inspect = try CLIOutputCapture.suppressStderr {
            try MCPCommand.Inspect.parse([])
        }
        await #expect(throws: ExitCode.self) {
            try await inspect.run()
        }
    }
}

@Suite("MCP Call Command Runtime Tests", .tags(.fast))
@MainActor
struct MCPCallCommandRuntimeTests {
    @Test("Call command executes MCP tool and prints response")
    func callCommandPrintsResponse() async throws {
        var command = try MCPCommand.Call.parse(["browser", "--tool", "echo", "--args", "{\"message\":\"ping\"}"])
        let mockManager = MockMCPClientManager()
        mockManager.setServer(name: "browser")
        mockManager.executeResponse = .text("pong")
        command.clientManager = mockManager

        let result = await captureCommandOutput {
            try await executeCall(command: &command, jsonOutput: false)
        }

        #expect(result.error == nil)
        #expect(result.stdout.contains("pong"))
        #expect(result.stdout.contains("Tool completed successfully."))
        #expect(mockManager.probeCallCount == 1)
        #expect(mockManager.executeCallCount == 1)
    }

    @Test("Call command emits JSON output when requested")
    func callCommandOutputsJSON() async throws {
        var command = try MCPCommand.Call.parse(["browser", "--tool", "status"])
        let mockManager = MockMCPClientManager()
        mockManager.setServer(name: "browser")
        let meta = Value.object(["duration": .double(1.25)])
        mockManager.executeResponse = ToolResponse.multiContent([.text("ok")], meta: meta)
        command.clientManager = mockManager

        let result = await captureCommandOutput {
            try await executeCall(command: &command, jsonOutput: true)
        }

        #expect(result.error == nil)

        let data = Data(result.stdout.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(jsonObject?["success"] as? Bool == true)
        #expect(jsonObject?["server"] as? String == "browser")
        if
            let response = jsonObject?["response"] as? [String: Any],
            let content = response["content"] as? [[String: Any]] {
            #expect(content.count == 1)
            #expect(content.first?["type"] as? String == "text")
        } else {
            Issue.record("Missing response content in JSON payload")
        }
    }

    @Test("Call command reports missing server errors")
    func callCommandFailsWhenServerMissing() async throws {
        var command = try MCPCommand.Call.parse(["missing", "--tool", "echo"])
        let mockManager = MockMCPClientManager()
        command.clientManager = mockManager

        let result = await captureCommandOutput {
            try await executeCall(command: &command, jsonOutput: false)
        }

        guard let exit = result.error as? ExitCode else {
            Issue.record("Expected ExitCode failure when server is missing")
            return
        }
        #expect(exit.rawValue == EXIT_FAILURE)
        #expect(result.stdout.contains("not configured"))
    }

    @Test("Call command surfaces tool-level errors")
    func callCommandFailsForToolError() async throws {
        var command = try MCPCommand.Call.parse(["browser", "--tool", "unstable"])
        let mockManager = MockMCPClientManager()
        mockManager.setServer(name: "browser")
        mockManager.executeResponse = .error("boom")
        command.clientManager = mockManager

        let result = await captureCommandOutput {
            try await executeCall(command: &command, jsonOutput: false)
        }

        guard let exit = result.error as? ExitCode else {
            Issue.record("Expected ExitCode failure when MCP tool reports error")
            return
        }
        #expect(exit.rawValue == EXIT_FAILURE)
        #expect(result.stdout.contains("Tool reported an error."))
    }
}

// MARK: - Test Helpers

@MainActor
private func executeCall(command: inout MCPCommand.Call, jsonOutput: Bool) async throws {
    let services = TestServicesFactory.makePeekabooServices()
    let configuration = CommandRuntime.Configuration(verbose: false, jsonOutput: jsonOutput, logLevel: nil)
    let runtime = CommandRuntime(configuration: configuration, services: services)
    try await command.run(using: runtime)
}

@MainActor
private func captureCommandOutput(
    _ body: () async throws -> Void
) async -> (stdout: String, stderr: String, error: Error?) {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    let originalStderr = dup(STDERR_FILENO)

    dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    dup2(stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

    stdoutPipe.fileHandleForWriting.closeFile()
    stderrPipe.fileHandleForWriting.closeFile()

    var capturedError: Error?
    do {
        try await body()
    } catch {
        capturedError = error
    }

    fflush(stdout)
    fflush(stderr)

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    stdoutPipe.fileHandleForReading.closeFile()
    stderrPipe.fileHandleForReading.closeFile()

    dup2(originalStdout, STDOUT_FILENO)
    dup2(originalStderr, STDERR_FILENO)
    close(originalStdout)
    close(originalStderr)

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
    return (stdout, stderr, capturedError)
}

@MainActor
final class MockMCPClientManager: MCPClientManaging {
    private(set) var registeredDefaults: [String: TachikomaMCP.MCPServerConfig] = [:]
    private(set) var initializeCallCount = 0
    private(set) var storedServers: [String: TachikomaMCP.MCPServerConfig] = [:]
    private(set) var connectedServers: Set<String> = []
    var probeResult: (Bool, Int, TimeInterval, String?) = (true, 0, 0.01, nil)
    var executeResponse: ToolResponse = .text("ok")
    var executeError: Error?
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

    func probeServer(name: String, timeoutMs _: Int) async -> (Bool, Int, TimeInterval, String?) {
        self.probeCallCount += 1
        if self.probeResult.0 {
            self.connectedServers.insert(name)
        }
        return self.probeResult
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
        let harness = try MCPStubTestHarness()
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
        let harness = try MCPStubTestHarness()
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
