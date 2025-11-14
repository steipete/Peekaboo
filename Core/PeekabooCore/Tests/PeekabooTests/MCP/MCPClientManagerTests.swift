import Foundation
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

/// Tests for MCPClientManager functionality
@Suite("MCP Client Manager Tests")
struct MCPClientManagerTests {
    @MainActor
    private func ensureAutoConnectDisabled() {
        MCPClientManager._setAutoConnectOverrideForTesting(false)
    }

    private func uniqueServerName(_ base: String) -> String {
        "\(base)-\(UUID().uuidString)"
    }

    @Test("MCPClientManager singleton initialization")
    @MainActor
    func singletonInitialization() async {
        self.ensureAutoConnectDisabled()
        let manager1 = MCPClientManager.shared
        let manager2 = MCPClientManager.shared

        // Should be the same instance
        #expect(manager1 === manager2)
    }

    @Test("Add MCP server configuration")
    @MainActor
    func testAddServer() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName = self.uniqueServerName("test-server")

        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: true,
            timeout: 5.0,
            description: "Test server")

        try await manager.addServer(name: serverName, config: config)

        let serverNames = await manager.getServerNames()
        #expect(serverNames.contains(serverName))

        let serverInfo = await manager.getServerInfo(name: serverName)
        #expect(serverInfo?.name == serverName)
        #expect(serverInfo?.config.command == "echo")
        #expect(serverInfo?.config.args == ["test"])
        #expect(serverInfo?.config.enabled == true)
        #expect(serverInfo?.config.description == "Test server")

        // Clean up
        try await manager.removeServer(name: serverName)
    }

    @Test("Remove MCP server")
    @MainActor
    func testRemoveServer() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName = self.uniqueServerName("test-remove")

        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"])

        try await manager.addServer(name: serverName, config: config)
        let namesAfterAdd = await manager.getServerNames()
        #expect(namesAfterAdd.contains(serverName))

        try await manager.removeServer(name: serverName)
        let namesAfterRemove = await manager.getServerNames()
        #expect(!namesAfterRemove.contains(serverName))
    }

    @Test("Enable and disable MCP server")
    @MainActor
    func enableDisableServer() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName = self.uniqueServerName("test-enable")

        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: true)

        try await manager.addServer(name: serverName, config: config)

        // Initial state should be enabled
        let initialInfo = await manager.getServerInfo(name: serverName)
        #expect(initialInfo?.config.enabled == true)

        // Disable server
        try await manager.disableServer(name: serverName)
        let disabledInfo = await manager.getServerInfo(name: serverName)
        #expect(disabledInfo?.config.enabled == false)

        // Enable server
        try await manager.enableServer(name: serverName)
        let enabledInfo = await manager.getServerInfo(name: serverName)
        #expect(enabledInfo?.config.enabled == true)

        // Clean up
        try await manager.removeServer(name: serverName)
    }

    @Test("Server health checking with invalid command")
    @MainActor
    func healthCheckInvalidCommand() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName = self.uniqueServerName("test-invalid")

        let config = Configuration.MCPClientConfig(
            command: "nonexistent-command-12345",
            args: ["test"],
            enabled: true,
            timeout: 1.0, // Short timeout for faster test
        )

        try await manager.addServer(name: serverName, config: config)

        let health = await manager.checkServerHealth(name: serverName, timeout: 1000)

        switch health {
        case .disconnected:
            // Expected result for invalid command
            break
        default:
            Issue.record("Expected disconnected health status for invalid command, got \(health)")
        }

        // Clean up
        try await manager.removeServer(name: serverName)
    }

    @Test("Server health checking with disabled server")
    @MainActor
    func healthCheckDisabledServer() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName = self.uniqueServerName("test-disabled")

        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: false, // Disabled server
        )

        try await manager.addServer(name: serverName, config: config)

        let health = await manager.checkServerHealth(name: serverName)

        switch health {
        case .disabled:
            // Expected result for disabled server
            break
        default:
            Issue.record("Expected disabled health status, got \(health)")
        }

        // Clean up
        try await manager.removeServer(name: serverName)
    }

    @Test("Get server configurations")
    @MainActor
    func getServerConfigs() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName1 = self.uniqueServerName("server1")
        let serverName2 = self.uniqueServerName("server2")

        let config1 = Configuration.MCPClientConfig(
            command: "echo",
            args: ["server1"],
            description: "First test server")

        let config2 = Configuration.MCPClientConfig(
            command: "cat",
            args: ["/dev/null"],
            description: "Second test server")

        try await manager.addServer(name: serverName1, config: config1)
        try await manager.addServer(name: serverName2, config: config2)

        let configs = await manager.getServerInfos()
        #expect(configs.count >= 2)

        let server1 = configs.first(where: { $0.name == serverName1 })
        let server2 = configs.first(where: { $0.name == serverName2 })
        #expect(server1?.config.command == "echo")
        #expect(server2?.config.command == "cat")

        // Clean up
        try await manager.removeServer(name: serverName1)
        try await manager.removeServer(name: serverName2)
    }

    @Test("Check all servers health")
    @MainActor
    func testCheckAllServersHealth() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let validName = self.uniqueServerName("test-valid")
        let invalidName = self.uniqueServerName("test-invalid")
        let disabledName = self.uniqueServerName("test-disabled")

        let validConfig = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: true,
            timeout: 2.0)

        let invalidConfig = Configuration.MCPClientConfig(
            command: "nonexistent-cmd-xyz",
            args: ["test"],
            enabled: true,
            timeout: 1.0)

        let disabledConfig = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: false)

        try await manager.addServer(name: validName, config: validConfig)
        try await manager.addServer(name: invalidName, config: invalidConfig)
        try await manager.addServer(name: disabledName, config: disabledConfig)

        let healthResults = await manager.checkAllServersHealth()

        #expect(healthResults.count >= 3)

        // Check that we got results for all servers
        #expect(healthResults[validName] != nil)
        #expect(healthResults[invalidName] != nil)
        #expect(healthResults[disabledName] != nil)

        // Check expected health states
        if case .disabled = healthResults[disabledName]! {
            // Expected
        } else {
            Issue.record("Expected disabled status for test-disabled server")
        }

        if case .disconnected = healthResults[invalidName]! {
            // Expected for invalid command
        } else {
            Issue.record("Expected disconnected status for test-invalid server")
        }

        // Clean up
        try await manager.removeServer(name: validName)
        try await manager.removeServer(name: invalidName)
        try await manager.removeServer(name: disabledName)
    }

    @Test("Error handling for non-existent server")
    @MainActor
    func nonExistentServerError() async {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared

        let serverInfo = await manager.getServerInfo(name: "non-existent-server")
        #expect(serverInfo == nil)

        let health = await manager.checkServerHealth(name: "non-existent-server")
        switch health {
        case .unknown:
            break // Expected
        default:
            Issue.record("Expected unknown health status, got \(health)")
        }

        // These should throw errors
        await #expect(throws: MCPClientError.self) {
            try await manager.removeServer(name: "non-existent-server")
        }

        await #expect(throws: MCPClientError.self) {
            try await manager.enableServer(name: "non-existent-server")
        }

        await #expect(throws: MCPClientError.self) {
            try await manager.disableServer(name: "non-existent-server")
        }
    }

    @Test("Server configuration validation")
    @MainActor
    func serverConfigValidation() async throws {
        self.ensureAutoConnectDisabled()
        let manager = MCPClientManager.shared
        let serverName = self.uniqueServerName("test-env")

        // Test with environment variables
        let configWithEnv = Configuration.MCPClientConfig(
            command: "env",
            args: [],
            env: ["TEST_VAR": "test_value", "ANOTHER_VAR": "another_value"],
            enabled: true)

        try await manager.addServer(name: serverName, config: configWithEnv)

        let serverInfo = await manager.getServerInfo(name: serverName)
        #expect(serverInfo?.config.env["TEST_VAR"] == "test_value")
        #expect(serverInfo?.config.env["ANOTHER_VAR"] == "another_value")

        // Clean up
        try await manager.removeServer(name: serverName)
    }
}

/// Tests for MCPServerHealth enum
@Suite("MCP Server Health Tests")
struct MCPServerHealthTests {
    @Test("Health status symbols")
    func healthSymbols() {
        #expect(MCPServerHealth.connected(toolCount: 5, responseTime: 0.1).symbol == "✓")
        #expect(MCPServerHealth.disconnected(error: "Error").symbol == "✗")
        #expect(MCPServerHealth.connecting.symbol == "⏳")
        #expect(MCPServerHealth.disabled.symbol == "⏸")
        #expect(MCPServerHealth.unknown.symbol == "?")
    }

    @Test("Health status text")
    func healthStatusText() {
        let connected = MCPServerHealth.connected(toolCount: 10, responseTime: 0.123)
        #expect(connected.statusText == "Connected (10 tools, 123ms)")

        let disconnected = MCPServerHealth.disconnected(error: "Connection failed")
        #expect(disconnected.statusText == "Failed to connect (Connection failed)")

        #expect(MCPServerHealth.connecting.statusText == "Connecting...")
        #expect(MCPServerHealth.disabled.statusText == "Disabled")
        #expect(MCPServerHealth.unknown.statusText == "Unknown")
    }

    @Test("Health status isHealthy property")
    func testIsHealthy() {
        #expect(MCPServerHealth.connected(toolCount: 5, responseTime: 0.1).isHealthy == true)
        #expect(MCPServerHealth.disconnected(error: "Error").isHealthy == false)
        #expect(MCPServerHealth.connecting.isHealthy == false)
        #expect(MCPServerHealth.disabled.isHealthy == false)
        #expect(MCPServerHealth.unknown.isHealthy == false)
    }
}

/// Tests for MCPClientError enum
@Suite("MCP Client Error Tests")
struct MCPClientErrorTests {
    @Test("Error descriptions")
    func errorDescriptions() {
        let serverDisabled = MCPClientError.serverDisabled
        #expect(serverDisabled.errorDescription == "MCP server is disabled")

        let notConnected = MCPClientError.notConnected
        #expect(notConnected.errorDescription == "Not connected to MCP server")

        let connectionFailed = MCPClientError.connectionFailed("Network error")
        #expect(connectionFailed.errorDescription == "Failed to connect: Network error")

        let invalidResponse = MCPClientError.invalidResponse
        #expect(invalidResponse.errorDescription == "Invalid response from MCP server")

        let executionFailed = MCPClientError.executionFailed("Custom error")
        #expect(executionFailed.errorDescription == "Execution failed: Custom error")
    }
}
