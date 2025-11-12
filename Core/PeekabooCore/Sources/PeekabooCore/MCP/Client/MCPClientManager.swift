import Foundation
import MCP
import os.log
import TachikomaMCP

private enum MCPAutoConnectPolicy {
    private static let overrideLock = OSAllocatedUnfairLock(initialState: Bool?.none)
    private static let forceEnable =
        ProcessInfo.processInfo.environment["PEEKABOO_FORCE_MCP_AUTOCONNECT"] == "true"
    private static let forceDisable =
        ProcessInfo.processInfo.environment["PEEKABOO_DISABLE_MCP_AUTOCONNECT"] == "true"
    private static let isTestEnvironment: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["PEEKABOO_DISABLE_MCP_AUTOCONNECT"] == "true" { return true }
        if env["SWIFT_PACKAGE_TESTING"] == "1" { return true }
        if env["XCTestConfigurationFilePath"] != nil { return true }
        let processName = ProcessInfo.processInfo.processName.lowercased()
        let argv0 = CommandLine.arguments.first?.lowercased() ?? ""
        return processName.contains("xctest")
            || processName.contains("swiftpm-test")
            || processName.contains("swiftpm-testing-helper")
            || argv0.contains(".xctest")
    }()

    static var shouldConnect: Bool {
        if let override = overrideLock.withLock({ $0 }) {
            return override
        }
        if forceEnable { return true }
        if forceDisable { return false }
        return !isTestEnvironment
    }

    static func setOverride(_ value: Bool?) {
        overrideLock.withLock { $0 = value }
    }
}

// Use MCPClientConfig from Configuration.swift
public typealias MCPServerConfig = Configuration.MCPClientConfig

/// Health status of an MCP server
public enum MCPServerHealth: Sendable {
    case connected(toolCount: Int, responseTime: TimeInterval)
    case disconnected(error: String)
    case connecting
    case disabled
    case unknown

    public var symbol: String {
        switch self {
        case .connected: "✓"
        case .disconnected: "✗"
        case .connecting: "⏳"
        case .disabled: "⏸"
        case .unknown: "?"
        }
    }

    public var statusText: String {
        switch self {
        case let .connected(toolCount, responseTime):
            "Connected (\(toolCount) tools, \(Int(responseTime * 1000))ms)"
        case let .disconnected(error):
            "Failed to connect (\(error))"
        case .connecting:
            "Connecting..."
        case .disabled:
            "Disabled"
        case .unknown:
            "Unknown"
        }
    }

    public var isHealthy: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

/// Information about an MCP server
public struct MCPServerInfo: Sendable {
    public let name: String
    public let description: String
    public let enabled: Bool
    public let health: MCPServerHealth
    public let tools: [Tool]
    public let config: MCPServerConfig

    public init(
        name: String,
        description: String,
        enabled: Bool,
        health: MCPServerHealth,
        tools: [Tool],
        config: MCPServerConfig? = nil)
    {
        self.name = name
        self.description = description
        self.enabled = enabled
        self.health = health
        self.tools = tools
        self.config = config ?? MCPServerConfig(
            command: "",
            args: [],
            env: [:],
            enabled: enabled,
            description: description)
    }
}

/// Internal structure to manage MCP clients
private actor MCPClientConnection {
    let name: String
    let config: MCPServerConfig
    private var client: MCPClient?
    private var provider: MCPToolProvider?
    private var tools: [Tool] = []
    private var lastConnected: Date?
    private let logger: os.Logger

    init(name: String, config: MCPServerConfig) {
        self.name = name
        self.config = config
        self.logger = os.Logger(subsystem: "boo.peekaboo.mcp.client", category: name)
    }

    /// Establish a fresh connection to the configured MCP server and cache its tools.
    func connect() async throws {
        guard self.config.enabled else {
            throw MCPClientError.serverDisabled
        }

        self.logger.info("Connecting to MCP server '\(self.name)'")

        if !self.commandExists(self.config.command) {
            self.logger.error("Command '\(self.config.command)' not found on PATH")
            throw MCPClientError.connectionFailed("Command '\(self.config.command)' not found")
        }

        // Create MCP server config for TachikomaMCP
        let mcpServerConfig = TachikomaMCP.MCPServerConfig(
            transport: "stdio",
            command: self.config.command,
            args: self.config.args,
            env: self.config.env,
            description: self.config.description)

        // Create client and provider
        let client = MCPClient(name: name, config: mcpServerConfig)
        let provider = MCPToolProvider(client: client)

        do {
            try await provider.connect()
        } catch {
            self.logger.error("Failed to start MCP server '\(self.name)': \(error.localizedDescription)")
            throw MCPClientError.connectionFailed(error.localizedDescription)
        }

        // Store references
        self.client = client
        self.provider = provider

        // Get available tools
        self.tools = await client.tools
        self.lastConnected = Date()

        self.logger.info("Connected to MCP server '\(self.name)' with \(self.tools.count) tools")
    }

    func disconnect() async {
        if let client = self.client {
            await client.disconnect()
        }
        self.client = nil
        self.provider = nil
        self.tools = []
    }

    func isConnected() -> Bool {
        self.client != nil
    }

    func getTools() -> [Tool] {
        self.tools
    }

    /// Execute a tool against the active MCP client after validating connectivity.
    func executeTool(name: String, arguments: ToolArguments) async throws -> ToolResponse {
        guard let client = self.client else {
            throw MCPClientError.notConnected
        }

        // Convert ToolArguments to dictionary for MCP client
        let args = arguments.rawDictionary

        return try await client.executeTool(name: name, arguments: args)
    }

    /// Determine whether the configured command can be resolved in the current execution environment.
    private func commandExists(_ command: String) -> Bool {
        if command.contains("/") {
            let resolved = NSString(string: command).expandingTildeInPath
            return FileManager.default.isExecutableFile(atPath: resolved)
        }

        let paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":") ?? []
        for path in paths {
            let candidate = "\(path)/\(command)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return true
            }
        }

        return false
    }
}

/// Error types for MCP client operations
public enum MCPClientError: LocalizedError {
    case serverDisabled
    case connectionFailed(String)
    case executionFailed(String)
    case notConnected
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .serverDisabled:
            "MCP server is disabled"
        case let .connectionFailed(message):
            "Failed to connect: \(message)"
        case let .executionFailed(message):
            "Execution failed: \(message)"
        case .notConnected:
            "Not connected to MCP server"
        case .invalidResponse:
            "Invalid response from MCP server"
        }
    }

}

/// Manager for MCP client connections
@MainActor
public final class MCPClientManager {
    /// Shared instance
    public static let shared = MCPClientManager()

    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "client-manager")
    private var connections: [String: MCPClientConnection] = [:]
    private var configs: [String: MCPServerConfig] = [:]

    public init() {}

    /// Configure MCP servers
    public func configure(_ configs: [String: MCPServerConfig]) {
        // Configure MCP servers
        self.configs = configs

        // Create connections for each config
        for (name, config) in configs {
            let connection = MCPClientConnection(name: name, config: config)
            self.connections[name] = connection
        }

        self.logger.info("Configured \(configs.count) MCP servers")
    }

    /// Add a single server
    public func addServer(name: String, config: MCPServerConfig) async throws {
        // Add a single server
        self.configs[name] = config
        let connection = MCPClientConnection(name: name, config: config)
        self.connections[name] = connection

        if config.enabled, MCPAutoConnectPolicy.shouldConnect {
            do {
                try await connection.connect()
            } catch {
                self.logger.error("Initial connect for '\(name)' failed: \(error.localizedDescription)")
            }
        }

        self.logger.info("Added MCP server '\(name)'")
    }

    /// Initialize default servers
    public func initializeDefaultServers(userConfigs: [String: MCPServerConfig]) async {
        self.logger.info("Initializing default MCP servers...")

        let defaultBrowserConfig = MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["-y", "@agent-infra/mcp-server-browser@latest"],
            env: [:],
            enabled: true,
            timeout: 15.0,
            autoReconnect: true,
            description: "Browser automation via BrowserMCP")

        let actualUserConfigs = userConfigs.isEmpty ?
            (ConfigurationManager.shared.getConfiguration()?.mcpClients ?? [:]) : userConfigs

        await self.initializeBrowserServer(
            userConfigs: actualUserConfigs,
            defaultConfig: defaultBrowserConfig)
        await self.initializeAdditionalServers(actualUserConfigs)
    }

    private func initializeBrowserServer(
        userConfigs: [String: MCPServerConfig],
        defaultConfig: MCPServerConfig) async
    {
        if let userBrowserConfig = userConfigs["browser"] {
            await self.configureBrowserFromUserConfig(userBrowserConfig)
            return
        }

        self.configs["browser"] = defaultConfig
        let connection = MCPClientConnection(name: "browser", config: defaultConfig)
        self.connections["browser"] = connection

        do {
            try await connection.connect()
            self.logger.info("Initialized default browser MCP server")
        } catch {
            self.logger.error("Failed to connect to default browser MCP server: \\(error.localizedDescription)")
        }
    }

    private func configureBrowserFromUserConfig(_ config: MCPServerConfig) async {
        self.configs["browser"] = config
        let connection = MCPClientConnection(name: "browser", config: config)
        self.connections["browser"] = connection

        guard config.enabled else {
            self.logger.info("Browser MCP server is disabled by user configuration")
            return
        }

        do {
            try await connection.connect()
            self.logger.info("Initialized user-configured browser MCP server")
        } catch {
            self.logger.error("Failed to connect to browser MCP server: \\(error.localizedDescription)")
        }
    }

    private func initializeAdditionalServers(_ userConfigs: [String: MCPServerConfig]) async {
        for (serverName, serverConfig) in userConfigs where serverName != "browser" {
            self.configs[serverName] = serverConfig
            let connection = MCPClientConnection(name: serverName, config: serverConfig)
            self.connections[serverName] = connection

            guard serverConfig.enabled else { continue }

            do {
                try await connection.connect()
                self.logger.info("Initialized user-configured server '\(serverName)'")
            } catch {
                self.logger.error("Failed to connect to '\(serverName)': \\(error.localizedDescription)")
            }
        }
    }

    /// Connect to all enabled servers
    public func connectAll() async {
        // Connect to all enabled servers
        await withTaskGroup(of: (String, Result<Void, TachikomaMCP.MCPError>).self) { group in
            for (name, connection) in self.connections {
                guard let config = configs[name], config.enabled else { continue }

                group.addTask {
                    do {
                        try await connection.connect()
                        return (name, .success(()))
                    } catch let mcpError as TachikomaMCP.MCPError {
                        return (name, .failure(mcpError))
                    } catch {
                        return (name, .failure(.connectionFailed(error.localizedDescription)))
                    }
                }
            }

            for await (name, result) in group {
                switch result {
                case .success:
                    self.logger.info("Successfully connected to '\(name)'")
                case let .failure(error):
                    self.logger.error("Failed to connect to '\(name)': \(error.localizedDescription)")
                }
            }
        }
    }

    /// Disconnect from all servers
    public func disconnectAll() async {
        // Disconnect from all servers
        for connection in self.connections.values {
            await connection.disconnect()
        }
    }

    /// Get information about all configured servers
    public func getServerInfos() async -> [MCPServerInfo] {
        // Get information about all configured servers
        var infos: [MCPServerInfo] = []

        for (name, connection) in self.connections {
            let config = self.configs[name] ?? MCPServerConfig(
                command: "",
                args: [],
                env: [:],
                enabled: false,
                description: "")

            let isConnected = await connection.isConnected()
            let tools = await connection.getTools()

            let health: MCPServerHealth = if !config.enabled {
                .disabled
            } else if isConnected {
                .connected(toolCount: tools.count, responseTime: 0)
            } else {
                .disconnected(error: "Not connected")
            }

            let info = MCPServerInfo(
                name: name,
                description: config.description ?? "",
                enabled: config.enabled,
                health: health,
                tools: tools,
                config: config)

            infos.append(info)
        }

        return infos
    }

    /// Get all available tools from all connected servers
    public func getAllTools() async -> [Tool] {
        // Get all available tools from all connected servers
        var allTools: [Tool] = []

        for connection in self.connections.values {
            let tools = await connection.getTools()
            allTools.append(contentsOf: tools)
        }

        return allTools
    }

    /// Execute an external tool
    public func executeExternalTool(
        serverName: String,
        toolName: String,
        arguments: ToolArguments) async throws -> ToolResponse
    {
        // Execute an external tool
        guard let connection = connections[serverName] else {
            throw MCPClientError.executionFailed("Server '\(serverName)' not found")
        }

        return try await connection.executeTool(name: toolName, arguments: arguments)
    }

    /// Get external tools from all connected servers
    public func getExternalTools() async -> [String: [Tool]] {
        // Get external tools from all connected servers
        var toolsByServer: [String: [Tool]] = [:]

        for (name, connection) in self.connections {
            let tools = await connection.getTools()
            if !tools.isEmpty {
                toolsByServer[name] = tools
            }
        }

        return toolsByServer
    }

    /// Convert MCP response to ToolResponse
    private func convertResponse(_ content: [MCP.Tool.Content]) -> ToolResponse {
        // Convert MCP response to ToolResponse
        ToolResponse(content: content)
    }

    // MARK: - Additional Methods for CLI Compatibility

    /// Get all server names
    public func getServerNames() async -> [String] {
        // Get all server names
        let names = Array(connections.keys).sorted()
        self.logger.info("Returning \(names.count) server names: \(names)")
        return names
    }

    /// Check health status for all servers
    public func checkAllServersHealth() async -> [String: MCPServerHealth] {
        // Check health status for all servers
        var healthResults: [String: MCPServerHealth] = [:]

        await withTaskGroup(of: (String, MCPServerHealth).self) { group in
            for (name, _) in self.connections {
                group.addTask {
                    let health = await self.checkServerHealth(name: name)
                    return (name, health)
                }
            }

            for await (name, health) in group {
                healthResults[name] = health
            }
        }

        return healthResults
    }

    /// Check health status for a specific server
    public func checkServerHealth(name: String, timeout: Int = 5000) async -> MCPServerHealth {
        // Check health status for a specific server
        guard let connection = connections[name] else {
            return .unknown
        }

        guard let config = configs[name], config.enabled else {
            return .disabled
        }

        let startTime = Date()
        let isConnected = await connection.isConnected()
        let responseTime = Date().timeIntervalSince(startTime)

        if isConnected {
            let tools = await connection.getTools()
            return .connected(toolCount: tools.count, responseTime: responseTime)
        } else {
            guard MCPAutoConnectPolicy.shouldConnect else {
                return .disconnected(error: "Auto-connect disabled")
            }

            // Try to connect
            do {
                try await connection.connect()
                let tools = await connection.getTools()
                return .connected(toolCount: tools.count, responseTime: Date().timeIntervalSince(startTime))
            } catch {
                return .disconnected(error: error.localizedDescription)
            }
        }
    }

    /// Get information about a specific server
    public func getServerInfo(name: String) async -> MCPServerInfo? {
        // Get information about a specific server
        guard let connection = connections[name] else {
            return nil
        }

        let config = self.configs[name] ?? MCPServerConfig(
            command: "",
            args: [],
            env: [:],
            enabled: false,
            description: "")

        let isConnected = await connection.isConnected()
        let tools = await connection.getTools()

        let health: MCPServerHealth = if !config.enabled {
            .disabled
        } else if isConnected {
            .connected(toolCount: tools.count, responseTime: 0)
        } else {
            .disconnected(error: "Not connected")
        }

        return MCPServerInfo(
            name: name,
            description: config.description ?? "",
            enabled: config.enabled,
            health: health,
            tools: tools,
            config: config)
    }

    /// Check if a server is a default server
    public func isDefaultServer(name: String) -> Bool {
        // Browser server is the default server shipped with Peekaboo
        name == "browser"
    }

    /// Remove a server
    public func removeServer(name: String) async throws {
        // Remove a server
        guard let connection = connections[name] else {
            throw MCPClientError.executionFailed("Server '\(name)' not found")
        }

        await connection.disconnect()
        self.connections.removeValue(forKey: name)
        self.configs.removeValue(forKey: name)

        self.logger.info("Removed MCP server '\(name)'")
    }

    /// Enable a server
    public func enableServer(name: String) async throws {
        // Enable a server
        guard var config = configs[name] else {
            throw MCPClientError.executionFailed("Server '\(name)' not found")
        }

        config.enabled = true
        self.configs[name] = config

        if let connection = connections[name] {
            guard MCPAutoConnectPolicy.shouldConnect else {
                self.logger.info("Auto-connect disabled; skipping immediate connect for '\(name)'")
                return
            }

            try await connection.connect()
        }

        self.logger.info("Enabled MCP server '\(name)'")
    }

    /// Disable a server
    public func disableServer(name: String) async throws {
        // Disable a server
        guard var config = configs[name] else {
            throw MCPClientError.executionFailed("Server '\(name)' not found")
        }

        config.enabled = false
        self.configs[name] = config

        if let connection = connections[name] {
            await connection.disconnect()
        }

        self.logger.info("Disabled MCP server '\(name)'")
    }
}

extension MCPClientManager {
    @MainActor
    static func _setAutoConnectOverrideForTesting(_ value: Bool?) {
        MCPAutoConnectPolicy.setOverride(value)
    }
}
