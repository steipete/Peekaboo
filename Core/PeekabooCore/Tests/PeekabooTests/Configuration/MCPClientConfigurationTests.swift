import Foundation
import Testing
@testable import PeekabooCore

/// Tests for MCP client configuration integration
@Suite("MCP Client Configuration Tests")
struct MCPClientConfigurationTests {
    @Test("MCPClientConfig initialization with defaults")
    func mCPClientConfigDefaults() {
        let config = Configuration.MCPClientConfig(command: "echo")

        #expect(config.transport == "stdio")
        #expect(config.command == "echo")
        #expect(config.args.isEmpty)
        #expect(config.env.isEmpty)
        #expect(config.enabled == true)
        #expect(config.timeout == 10.0)
        #expect(config.autoReconnect == true)
        #expect(config.description == nil)
    }

    @Test("MCPClientConfig initialization with custom values")
    func mCPClientConfigCustom() {
        let config = Configuration.MCPClientConfig(
            transport: "http",
            command: "node",
            args: ["server.js", "--port", "3000"],
            env: ["NODE_ENV": "production", "API_KEY": "secret"],
            enabled: false,
            timeout: 30.0,
            autoReconnect: false,
            description: "Node.js MCP server")

        #expect(config.transport == "http")
        #expect(config.command == "node")
        #expect(config.args == ["server.js", "--port", "3000"])
        #expect(config.env["NODE_ENV"] == "production")
        #expect(config.env["API_KEY"] == "secret")
        #expect(config.enabled == false)
        #expect(config.timeout == 30.0)
        #expect(config.autoReconnect == false)
        #expect(config.description == "Node.js MCP server")
    }

    @Test("ToolDisplayConfig initialization with defaults")
    func toolDisplayConfigDefaults() {
        let config = Configuration.ToolDisplayConfig()

        #expect(config.showMcpToolsByDefault == true)
        #expect(config.useServerPrefixes == true)
        #expect(config.groupByServer == false)
    }

    @Test("ToolDisplayConfig initialization with custom values")
    func toolDisplayConfigCustom() {
        let config = Configuration.ToolDisplayConfig(
            showMcpToolsByDefault: false,
            useServerPrefixes: false,
            groupByServer: true)

        #expect(config.showMcpToolsByDefault == false)
        #expect(config.useServerPrefixes == false)
        #expect(config.groupByServer == true)
    }

    @Test("Configuration with MCP clients and tool display")
    func configurationWithMCPFields() {
        let mcpClients = [
            "github": Configuration.MCPClientConfig(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                description: "GitHub MCP server"),
            "files": Configuration.MCPClientConfig(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
                enabled: false,
                description: "Filesystem MCP server"),
        ]

        let toolDisplay = Configuration.ToolDisplayConfig(
            showMcpToolsByDefault: false,
            useServerPrefixes: true,
            groupByServer: true)

        let config = Configuration(
            mcpClients: mcpClients,
            toolDisplay: toolDisplay)

        #expect(config.mcpClients?.count == 2)
        #expect(config.mcpClients?["github"]?.command == "npx")
        #expect(config.mcpClients?["github"]?.enabled == true)
        #expect(config.mcpClients?["files"]?.enabled == false)
        #expect(config.toolDisplay?.showMcpToolsByDefault == false)
        #expect(config.toolDisplay?.groupByServer == true)
    }

    @Test("MCPClientConfig Codable conformance")
    func mCPClientConfigCodable() throws {
        let originalConfig = Configuration.MCPClientConfig(
            transport: "stdio",
            command: "echo",
            args: ["hello", "world"],
            env: ["TEST": "value"],
            enabled: true,
            timeout: 15.0,
            autoReconnect: false,
            description: "Test server")

        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalConfig)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Configuration.MCPClientConfig.self, from: jsonData)

        #expect(decodedConfig.transport == originalConfig.transport)
        #expect(decodedConfig.command == originalConfig.command)
        #expect(decodedConfig.args == originalConfig.args)
        #expect(decodedConfig.env == originalConfig.env)
        #expect(decodedConfig.enabled == originalConfig.enabled)
        #expect(decodedConfig.timeout == originalConfig.timeout)
        #expect(decodedConfig.autoReconnect == originalConfig.autoReconnect)
        #expect(decodedConfig.description == originalConfig.description)
    }

    @Test("ToolDisplayConfig Codable conformance")
    func toolDisplayConfigCodable() throws {
        let originalConfig = Configuration.ToolDisplayConfig(
            showMcpToolsByDefault: false,
            useServerPrefixes: true,
            groupByServer: true)

        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalConfig)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Configuration.ToolDisplayConfig.self, from: jsonData)

        #expect(decodedConfig.showMcpToolsByDefault == originalConfig.showMcpToolsByDefault)
        #expect(decodedConfig.useServerPrefixes == originalConfig.useServerPrefixes)
        #expect(decodedConfig.groupByServer == originalConfig.groupByServer)
    }

    @Test("Complete Configuration with MCP fields Codable")
    func completeConfigurationCodable() throws {
        let mcpClients = [
            "test": Configuration.MCPClientConfig(
                command: "test-command",
                args: ["arg1", "arg2"],
                env: ["VAR": "value"]),
        ]

        let toolDisplay = Configuration.ToolDisplayConfig(
            showMcpToolsByDefault: true,
            useServerPrefixes: false)

        let originalConfig = Configuration(
            mcpClients: mcpClients,
            toolDisplay: toolDisplay)

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(originalConfig)

        // Verify JSON structure
        let jsonString = String(data: jsonData, encoding: .utf8)!
        #expect(jsonString.contains("mcpClients"))
        #expect(jsonString.contains("toolDisplay"))
        #expect(jsonString.contains("test-command"))
        #expect(jsonString.contains("showMcpToolsByDefault"))

        // Decode from JSON
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Configuration.self, from: jsonData)

        #expect(decodedConfig.mcpClients?.count == 1)
        #expect(decodedConfig.mcpClients?["test"]?.command == "test-command")
        #expect(decodedConfig.mcpClients?["test"]?.args == ["arg1", "arg2"])
        #expect(decodedConfig.mcpClients?["test"]?.env["VAR"] == "value")
        #expect(decodedConfig.toolDisplay?.showMcpToolsByDefault == true)
        #expect(decodedConfig.toolDisplay?.useServerPrefixes == false)
    }

    @Test("MCPServerConfig type alias works correctly")
    func mCPServerConfigTypeAlias() {
        // MCPServerConfig should be a type alias for Configuration.MCPClientConfig
        let serverConfig: MCPServerConfig = Configuration.MCPClientConfig(
            command: "echo",
            args: ["test"],
            description: "Test server")

        #expect(serverConfig.command == "echo")
        #expect(serverConfig.args == ["test"])
        #expect(serverConfig.description == "Test server")

        // Should be able to use as Configuration.MCPClientConfig
        let clientConfig: Configuration.MCPClientConfig = serverConfig
        #expect(clientConfig.command == "echo")
    }

    @Test("Configuration JSON structure for MCP clients")
    func configurationJSONStructure() throws {
        let config = Configuration(
            mcpClients: [
                "github": Configuration.MCPClientConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-github"],
                    env: ["GITHUB_TOKEN": "${GITHUB_TOKEN}"],
                    description: "GitHub server"),
                "files": Configuration.MCPClientConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/docs"],
                    enabled: false,
                    timeout: 5.0,
                    description: "Filesystem server"),
            ],
            toolDisplay: Configuration.ToolDisplayConfig(
                showMcpToolsByDefault: true,
                useServerPrefixes: true,
                groupByServer: false))

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(config)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Verify the JSON contains expected structure
        #expect(jsonString.contains("\"mcpClients\""))
        #expect(jsonString.contains("\"github\""))
        #expect(jsonString.contains("\"files\""))
        #expect(jsonString.contains("\"toolDisplay\""))
        #expect(jsonString.contains("\"showMcpToolsByDefault\""))
        #expect(jsonString.contains("\"@modelcontextprotocol/server-github\""))
        #expect(jsonString.contains("\"${GITHUB_TOKEN}\""))
        #expect(jsonString.contains("\"enabled\" : false"))
        #expect(jsonString.contains("\"timeout\" : 5"))

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Configuration.self, from: jsonData)

        #expect(decodedConfig.mcpClients?.count == 2)
        #expect(decodedConfig.toolDisplay?.showMcpToolsByDefault == true)
    }
}
