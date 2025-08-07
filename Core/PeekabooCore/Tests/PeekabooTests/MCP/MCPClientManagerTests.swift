import Testing
import Foundation
@testable import PeekabooCore

/// Tests for MCPClientManager functionality
@Suite("MCP Client Manager Tests")
struct MCPClientManagerTests {
    
    @Test("MCPClientManager singleton initialization")
    @MainActor
    func testSingletonInitialization() async {
        let manager1 = MCPClientManager.shared
        let manager2 = MCPClientManager.shared
        
        // Should be the same instance
        #expect(manager1 === manager2)
    }
    
    @Test("Add MCP server configuration")
    @MainActor
    func testAddServer() async throws {
        let manager = MCPClientManager.shared
        
        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: true,
            timeout: 5.0,
            description: "Test server"
        )
        
        try await manager.addServer(name: "test-server", config: config)
        
        let serverNames = await manager.getServerNames()
        #expect(serverNames.contains("test-server"))
        
        let serverInfo = await manager.getServerInfo(name: "test-server")
        #expect(serverInfo?.name == "test-server")
        #expect(serverInfo?.config.command == "echo")
        #expect(serverInfo?.config.args == ["test"])
        #expect(serverInfo?.config.enabled == true)
        #expect(serverInfo?.config.description == "Test server")
        
        // Clean up
        try await manager.removeServer(name: "test-server")
    }
    
    @Test("Remove MCP server")
    @MainActor
    func testRemoveServer() async throws {
        let manager = MCPClientManager.shared
        
        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"]
        )
        
        try await manager.addServer(name: "test-remove", config: config)
        let namesAfterAdd = await manager.getServerNames()
        #expect(namesAfterAdd.contains("test-remove"))
        
        try await manager.removeServer(name: "test-remove")
        let namesAfterRemove = await manager.getServerNames()
        #expect(!namesAfterRemove.contains("test-remove"))
    }
    
    @Test("Enable and disable MCP server")
    @MainActor
    func testEnableDisableServer() async throws {
        let manager = MCPClientManager.shared
        
        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: true
        )
        
        try await manager.addServer(name: "test-enable", config: config)
        
        // Initial state should be enabled
        let initialInfo = await manager.getServerInfo(name: "test-enable")
        #expect(initialInfo?.config.enabled == true)
        
        // Disable server
        try await manager.disableServer(name: "test-enable")
        let disabledInfo = await manager.getServerInfo(name: "test-enable")
        #expect(disabledInfo?.config.enabled == false)
        
        // Enable server
        try await manager.enableServer(name: "test-enable")
        let enabledInfo = await manager.getServerInfo(name: "test-enable")
        #expect(enabledInfo?.config.enabled == true)
        
        // Clean up
        try await manager.removeServer(name: "test-enable")
    }
    
    @Test("Server health checking with invalid command")
    @MainActor
    func testHealthCheckInvalidCommand() async throws {
        let manager = MCPClientManager.shared
        
        let config = Configuration.MCPClientConfig(
            command: "nonexistent-command-12345",
            args: ["test"],
            enabled: true,
            timeout: 1.0 // Short timeout for faster test
        )
        
        try await manager.addServer(name: "test-invalid", config: config)
        
        let health = await manager.checkServerHealth(name: "test-invalid", timeout: 1000)
        
        switch health {
        case .disconnected:
            // Expected result for invalid command
            break
        default:
            Issue.record("Expected disconnected health status for invalid command, got \(health)")
        }
        
        // Clean up
        try await manager.removeServer(name: "test-invalid")
    }
    
    @Test("Server health checking with disabled server")
    @MainActor
    func testHealthCheckDisabledServer() async throws {
        let manager = MCPClientManager.shared
        
        let config = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: false // Disabled server
        )
        
        try await manager.addServer(name: "test-disabled", config: config)
        
        let health = await manager.checkServerHealth(name: "test-disabled")
        
        switch health {
        case .disabled:
            // Expected result for disabled server
            break
        default:
            Issue.record("Expected disabled health status, got \(health)")
        }
        
        // Clean up
        try await manager.removeServer(name: "test-disabled")
    }
    
    @Test("Get server configurations")
    @MainActor
    func testGetServerConfigs() async throws {
        let manager = MCPClientManager.shared
        
        let config1 = Configuration.MCPClientConfig(
            command: "echo",
            args: ["server1"],
            description: "First test server"
        )
        
        let config2 = Configuration.MCPClientConfig(
            command: "cat",
            args: ["/dev/null"],
            description: "Second test server"
        )
        
        try await manager.addServer(name: "server1", config: config1)
        try await manager.addServer(name: "server2", config: config2)
        
        let configs = await manager.getServerInfos()
        #expect(configs.count >= 2)
        
        let server1 = configs.first(where: { $0.name == "server1" })
        let server2 = configs.first(where: { $0.name == "server2" })
        #expect(server1?.config.command == "echo")
        #expect(server2?.config.command == "cat")
        
        // Clean up
        try await manager.removeServer(name: "server1")
        try await manager.removeServer(name: "server2")
    }
    
    @Test("Check all servers health")
    @MainActor
    func testCheckAllServersHealth() async throws {
        let manager = MCPClientManager.shared
        
        let validConfig = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: true,
            timeout: 2.0
        )
        
        let invalidConfig = Configuration.MCPClientConfig(
            command: "nonexistent-cmd-xyz",
            args: ["test"],
            enabled: true,
            timeout: 1.0
        )
        
        let disabledConfig = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            enabled: false
        )
        
        try await manager.addServer(name: "test-valid", config: validConfig)
        try await manager.addServer(name: "test-invalid", config: invalidConfig)
        try await manager.addServer(name: "test-disabled", config: disabledConfig)
        
        let healthResults = await manager.checkAllServersHealth()
        
        #expect(healthResults.count >= 3)
        
        // Check that we got results for all servers
        #expect(healthResults["test-valid"] != nil)
        #expect(healthResults["test-invalid"] != nil)
        #expect(healthResults["test-disabled"] != nil)
        
        // Check expected health states
        if case .disabled = healthResults["test-disabled"]! {
            // Expected
        } else {
            Issue.record("Expected disabled status for test-disabled server")
        }
        
        if case .disconnected = healthResults["test-invalid"]! {
            // Expected for invalid command
        } else {
            Issue.record("Expected disconnected status for test-invalid server")
        }
        
        // Clean up
        try await manager.removeServer(name: "test-valid")
        try await manager.removeServer(name: "test-invalid")
        try await manager.removeServer(name: "test-disabled")
    }
    
    @Test("Error handling for non-existent server")
    @MainActor
    func testNonExistentServerError() async {
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
    func testServerConfigValidation() async throws {
        let manager = MCPClientManager.shared
        
        // Test with environment variables
        let configWithEnv = Configuration.MCPClientConfig(
            command: "env",
            args: [],
            env: ["TEST_VAR": "test_value", "ANOTHER_VAR": "another_value"],
            enabled: true
        )
        
        try await manager.addServer(name: "test-env", config: configWithEnv)
        
        let serverInfo = await manager.getServerInfo(name: "test-env")
        #expect(serverInfo?.config.env["TEST_VAR"] == "test_value")
        #expect(serverInfo?.config.env["ANOTHER_VAR"] == "another_value")
        
        // Clean up
        try await manager.removeServer(name: "test-env")
    }
}

/// Tests for MCPServerHealth enum
@Suite("MCP Server Health Tests")
struct MCPServerHealthTests {
    
    @Test("Health status symbols")
    func testHealthSymbols() {
        #expect(MCPServerHealth.connected(toolCount: 5, responseTime: 0.1).symbol == "✓")
        #expect(MCPServerHealth.disconnected(error: "Error").symbol == "✗")
        #expect(MCPServerHealth.connecting.symbol == "⏳")
        #expect(MCPServerHealth.disabled.symbol == "⏸")
        #expect(MCPServerHealth.unknown.symbol == "?")
    }
    
    @Test("Health status text")
    func testHealthStatusText() {
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
    func testErrorDescriptions() {
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