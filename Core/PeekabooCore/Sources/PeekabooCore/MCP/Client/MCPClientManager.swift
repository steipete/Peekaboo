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
    
    public init(
        name: String,
        description: String,
        enabled: Bool,
        health: MCPServerHealth,
        tools: [Tool]
    ) {
        self.name = name
        self.description = description
        self.enabled = enabled
        self.health = health
        self.tools = tools
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
        var args: [String: Any] = [:]
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
    
    /// Connect to all enabled servers
    public func connectAll() async {
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for (name, connection) in connections {
                guard let config = configs[name], config.enabled else { continue }
                
                group.addTask {
                    do {
                        try await connection.connect()
                        return (name, .success(()))
                    } catch {
                        return (name, .failure(error))
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
                description: config.description,
                enabled: config.enabled,
                health: health,
                tools: tools
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
}