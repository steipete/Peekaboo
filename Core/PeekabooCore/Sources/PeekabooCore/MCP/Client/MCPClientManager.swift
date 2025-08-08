import Foundation
import TachikomaMCP
import MCP
import os.log

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
        config: MCPServerConfig? = nil
    ) {
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
            description: description
        )
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
    
    func connect() async throws {
        guard config.enabled else {
            throw MCPClientError.serverDisabled
        }
        
        logger.info("Connecting to MCP server '\(self.name)'")
        
        // Create MCP server config for TachikomaMCP
        let mcpServerConfig = TachikomaMCP.MCPServerConfig(
            transport: "stdio",
            command: config.command,
            args: config.args,
            env: config.env,
            description: config.description
        )
        
        // Create client and provider
        let client = MCPClient(name: name, config: mcpServerConfig)
        let provider = MCPToolProvider(client: client)
        
        // Connect
        try await provider.connect()
        
        // Store references
        self.client = client
        self.provider = provider
        
        // Get available tools
        self.tools = await client.tools
        self.lastConnected = Date()
        
        logger.info("Connected to MCP server '\(self.name)' with \(self.tools.count) tools")
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
        return client != nil
    }
    
    func getTools() -> [Tool] {
        return tools
    }
    
    func executeTool(name: String, arguments: ToolArguments) async throws -> ToolResponse {
        guard let client = self.client else {
            throw MCPClientError.notConnected
        }
        
        // Convert ToolArguments to dictionary for MCP client
        let args: [String: Any] = [:]
        // Note: This is a simplified conversion - may need to be expanded based on actual usage
        
        return try await client.executeTool(name: name, arguments: args)
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
            return "MCP server is disabled"
        case .connectionFailed(let message):
            return "Failed to connect: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .notConnected:
            return "Not connected to MCP server"
        case .invalidResponse:
            return "Invalid response from MCP server"
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
        self.configs = configs
        
        // Create connections for each config
        for (name, config) in configs {
            let connection = MCPClientConnection(name: name, config: config)
            self.connections[name] = connection
        }
        
        logger.info("Configured \(configs.count) MCP servers")
    }
    
    /// Add a single server
    public func addServer(name: String, config: MCPServerConfig) async throws {
        self.configs[name] = config
        let connection = MCPClientConnection(name: name, config: config)
        self.connections[name] = connection
        
        if config.enabled {
            try await connection.connect()
        }
        
        logger.info("Added MCP server '\(name)'")
    }
    
    /// Initialize default servers
    public func initializeDefaultServers(userConfigs: [String: MCPServerConfig]) async {
        logger.info("Initializing default MCP servers...")
        
        // Define default browser server configuration
        let defaultBrowserConfig = MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: ["-y", "@agent-infra/mcp-server-browser@latest"],
            env: [:],
            enabled: true,
            timeout: 15.0,
            autoReconnect: true,
            description: "Browser automation via BrowserMCP"
        )
        
        // Load user configs from ConfigurationManager if not provided
        let actualUserConfigs = userConfigs.isEmpty ? 
            (ConfigurationManager.shared.getConfiguration()?.mcpClients ?? [:]) : userConfigs
        
        // Check if user has explicitly configured the browser server
        if let userBrowserConfig = actualUserConfigs["browser"] {
            // User has configured it - respect their settings (including if disabled)
            self.configs["browser"] = userBrowserConfig
            let connection = MCPClientConnection(name: "browser", config: userBrowserConfig)
            self.connections["browser"] = connection
            
            if userBrowserConfig.enabled {
                do {
                    try await connection.connect()
                    logger.info("Initialized user-configured browser MCP server")
                } catch {
                    logger.error("Failed to connect to browser MCP server: \(error.localizedDescription)")
                }
            } else {
                logger.info("Browser MCP server is disabled by user configuration")
            }
        } else {
            // User hasn't configured it - add as default
            self.configs["browser"] = defaultBrowserConfig
            let connection = MCPClientConnection(name: "browser", config: defaultBrowserConfig)
            self.connections["browser"] = connection
            
            do {
                try await connection.connect()
                logger.info("Initialized default browser MCP server")
            } catch {
                logger.error("Failed to connect to default browser MCP server: \(error.localizedDescription)")
            }
        }
        
        // Also add any other user-configured servers
        for (serverName, serverConfig) in actualUserConfigs {
            // Skip browser since we already handled it
            if serverName == "browser" {
                continue
            }
            
            self.configs[serverName] = serverConfig
            let connection = MCPClientConnection(name: serverName, config: serverConfig)
            self.connections[serverName] = connection
            
            if serverConfig.enabled {
                do {
                    try await connection.connect()
                    logger.info("Initialized user-configured server '\(serverName)'")
                } catch {
                    logger.error("Failed to connect to '\(serverName)': \(error.localizedDescription)")
                }
            }
        }
        
        logger.info("Default servers initialization completed with \(self.connections.count) servers")
    }
    
    /// Connect to all enabled servers
    public func connectAll() async {
        await withTaskGroup(of: (String, Result<Void, TachikomaMCP.MCPError>).self) { group in
            for (name, connection) in connections {
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
                    logger.info("Successfully connected to '\(name)'")
                case .failure(let error):
                    logger.error("Failed to connect to '\(name)': \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Disconnect from all servers
    public func disconnectAll() async {
        for connection in connections.values {
            await connection.disconnect()
        }
    }
    
    /// Get information about all configured servers
    public func getServerInfos() async -> [MCPServerInfo] {
        var infos: [MCPServerInfo] = []
        
        for (name, connection) in connections {
            let config = configs[name] ?? MCPServerConfig(
                command: "",
                args: [],
                env: [:],
                enabled: false,
                description: ""
            )
            
            let isConnected = await connection.isConnected()
            let tools = await connection.getTools()
            
            let health: MCPServerHealth
            if !config.enabled {
                health = .disabled
            } else if isConnected {
                health = .connected(toolCount: tools.count, responseTime: 0)
            } else {
                health = .disconnected(error: "Not connected")
            }
            
            let info = MCPServerInfo(
                name: name,
                description: config.description ?? "",
                enabled: config.enabled,
                health: health,
                tools: tools,
                config: config
            )
            
            infos.append(info)
        }
        
        return infos
    }
    
    /// Get all available tools from all connected servers
    public func getAllTools() async -> [Tool] {
        var allTools: [Tool] = []
        
        for connection in connections.values {
            let tools = await connection.getTools()
            allTools.append(contentsOf: tools)
        }
        
        return allTools
    }
    
    /// Execute an external tool
    public func executeExternalTool(
        serverName: String,
        toolName: String,
        arguments: ToolArguments
    ) async throws -> ToolResponse {
        guard let connection = connections[serverName] else {
            throw MCPClientError.executionFailed("Server '\(serverName)' not found")
        }
        
        return try await connection.executeTool(name: toolName, arguments: arguments)
    }
    
    /// Get external tools from all connected servers
    public func getExternalTools() async -> [String: [Tool]] {
        var toolsByServer: [String: [Tool]] = [:]
        
        for (name, connection) in connections {
            let tools = await connection.getTools()
            if !tools.isEmpty {
                toolsByServer[name] = tools
            }
        }
        
        return toolsByServer
    }
    
    /// Convert MCP response to ToolResponse
    private func convertResponse(_ content: [MCP.Tool.Content]) -> ToolResponse {
        ToolResponse(content: content)
    }
    
    // MARK: - Additional Methods for CLI Compatibility
    
    /// Get all server names
    public func getServerNames() async -> [String] {
        let names = Array(connections.keys).sorted()
        logger.info("Returning \(names.count) server names: \(names)")
        return names
    }
    
    /// Check health status for all servers
    public func checkAllServersHealth() async -> [String: MCPServerHealth] {
        var healthResults: [String: MCPServerHealth] = [:]
        
        await withTaskGroup(of: (String, MCPServerHealth).self) { group in
            for (name, connection) in connections {
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
        guard let connection = connections[name] else {
            return nil
        }
        
        let config = configs[name] ?? MCPServerConfig(
            command: "",
            args: [],
            env: [:],
            enabled: false,
            description: ""
        )
        
        let isConnected = await connection.isConnected()
        let tools = await connection.getTools()
        
        let health: MCPServerHealth
        if !config.enabled {
            health = .disabled
        } else if isConnected {
            health = .connected(toolCount: tools.count, responseTime: 0)
        } else {
            health = .disconnected(error: "Not connected")
        }
        
        return MCPServerInfo(
            name: name,
            description: config.description ?? "",
            enabled: config.enabled,
            health: health,
            tools: tools,
            config: config
        )
    }
    
    /// Check if a server is a default server
    public func isDefaultServer(name: String) -> Bool {
        // Browser server is the default server shipped with Peekaboo
        return name == "browser"
    }
    
    /// Remove a server
    public func removeServer(name: String) async throws {
        guard let connection = connections[name] else {
            throw MCPClientError.executionFailed("Server '\(name)' not found")
        }
        
        await connection.disconnect()
        connections.removeValue(forKey: name)
        configs.removeValue(forKey: name)
        
        logger.info("Removed MCP server '\(name)'")
    }
    
    /// Enable a server
    public func enableServer(name: String) async throws {
        guard var config = configs[name] else {
            throw MCPClientError.executionFailed("Server '\(name)' not found")
        }
        
        config.enabled = true
        configs[name] = config
        
        if let connection = connections[name] {
            try await connection.connect()
        }
        
        logger.info("Enabled MCP server '\(name)'")
    }
    
    /// Disable a server
    public func disableServer(name: String) async throws {
        guard var config = configs[name] else {
            throw MCPClientError.executionFailed("Server '\(name)' not found")
        }
        
        config.enabled = false
        configs[name] = config
        
        if let connection = connections[name] {
            await connection.disconnect()
        }
        
        logger.info("Disabled MCP server '\(name)'")
    }
}