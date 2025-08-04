import Foundation
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
    public let config: MCPServerConfig
    public let health: MCPServerHealth
    public let toolCount: Int
    public let lastConnected: Date?
    
    public init(name: String, config: MCPServerConfig, health: MCPServerHealth, toolCount: Int, lastConnected: Date?) {
        self.name = name
        self.config = config
        self.health = health
        self.toolCount = toolCount
        self.lastConnected = lastConnected
    }
}

/// Wrapper for MCP client with metadata
private actor MCPClientWrapper {
    let name: String
    let config: MCPServerConfig
    private var client: Client?
    private var tools: [Tool.Info] = []
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
        
        // Create client
        let client = Client(
            name: "peekaboo-mcp-client",
            version: "3.0.0-beta.2"
        )
        
        // Create transport based on config
        let transport: any Transport
        switch config.transport.lowercased() {
        case "stdio":
            transport = try StdioProcessTransport(
                executable: config.command,
                arguments: config.args,
                environment: config.env
            )
        default:
            throw MCPClientError.unsupportedTransport(config.transport)
        }
        
        // Connect with timeout
        try await withTimeout(config.timeout) {
            _ = try await client.connect(transport: transport)
        }
        
        // List tools to verify connection
        let toolsResult = try await withTimeout(config.timeout) {
            try await client.listTools()
        }
        
        self.client = client
        self.tools = toolsResult.tools
        self.lastConnected = Date()
        
        logger.info("Connected to MCP server '\(name)' with \(toolsResult.tools.count) tools")
    }
    
    func disconnect() async {
        client = nil
        tools = []
        logger.info("Disconnected from MCP server '\(name)'")
    }
    
    func getTools() -> [Tool.Info] {
        return tools
    }
    
    func executeTool(name toolName: String, arguments: [String: Any]) async throws -> CallTool.Result {
        guard let client = client else {
            throw MCPClientError.notConnected
        }
        
        return try await withTimeout(config.timeout) {
            try await client.callTool(name: toolName, arguments: arguments)
        }
    }
    
    func isConnected() -> Bool {
        return client != nil
    }
    
    func getLastConnected() -> Date? {
        return lastConnected
    }
}

/// Custom transport for stdio processes
private class StdioProcessTransport: Transport {
    private let process: Process
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp.client", category: "transport")
    
    init(executable: String, arguments: [String], environment: [String: String]) throws {
        self.process = Process()
        self.process.executableURL = URL(fileURLWithPath: executable)
        self.process.arguments = arguments
        
        // Set up environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        self.process.environment = env
        
        // Set up pipes
        self.process.standardInput = Pipe()
        self.process.standardOutput = Pipe()
        self.process.standardError = Pipe()
    }
    
    func send(_ message: JSONRPCMessage) async throws {
        guard let data = try? JSONSerialization.data(withJSONObject: message.toJSON()) else {
            throw MCPClientError.serializationFailed
        }
        
        let input = process.standardInput as! Pipe
        try input.fileHandleForWriting.write(contentsOf: data)
        try input.fileHandleForWriting.write(contentsOf: "\n".data(using: .utf8)!)
    }
    
    func receive() async throws -> JSONRPCMessage {
        let output = process.standardOutput as! Pipe
        let data = output.fileHandleForReading.availableData
        
        guard !data.isEmpty else {
            throw MCPClientError.connectionClosed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPClientError.deserializationFailed
        }
        
        return try JSONRPCMessage.fromJSON(json)
    }
    
    func start() async throws {
        try process.run()
        logger.info("Started MCP server process: \(process.executableURL?.path ?? "unknown")")
    }
    
    func close() async {
        process.terminate()
        logger.info("Terminated MCP server process")
    }
}

/// Errors that can occur in MCP client operations
public enum MCPClientError: LocalizedError, Sendable {
    case serverNotFound(String)
    case serverDisabled
    case notConnected
    case connectionTimeout
    case connectionClosed
    case unsupportedTransport(String)
    case serializationFailed
    case deserializationFailed
    case toolNotFound(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case let .serverNotFound(name):
            "MCP server '\(name)' not found"
        case .serverDisabled:
            "MCP server is disabled"
        case .notConnected:
            "Not connected to MCP server"
        case .connectionTimeout:
            "Connection timeout"
        case .connectionClosed:
            "Connection closed"
        case let .unsupportedTransport(transport):
            "Unsupported transport: \(transport)"
        case .serializationFailed:
            "Failed to serialize message"
        case .deserializationFailed:
            "Failed to deserialize message"
        case let .toolNotFound(tool):
            "Tool '\(tool)' not found"
        case let .executionFailed(message):
            "Tool execution failed: \(message)"
        }
    }
}

/// Timeout error
private struct TimeoutError: Error {}

/// Utility function to add timeout to async operations
private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

/// Manager for external MCP server clients
public actor MCPClientManager {
    public static let shared = MCPClientManager()
    
    private var clients: [String: MCPClientWrapper] = [:]
    private var serverConfigs: [String: MCPServerConfig] = [:]
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp.client", category: "manager")
    
    private init() {}
    
    // MARK: - Server Management
    
    /// Add a new MCP server
    public func addServer(name: String, config: MCPServerConfig) async throws {
        guard !serverConfigs.keys.contains(name) else {
            throw MCPClientError.executionFailed("Server '\(name)' already exists")
        }
        
        serverConfigs[name] = config
        clients[name] = MCPClientWrapper(name: name, config: config)
        
        logger.info("Added MCP server '\(name)'")
        
        // Try to connect if enabled
        if config.enabled {
            try? await connectServer(name: name)
        }
    }
    
    /// Remove an MCP server
    public func removeServer(name: String) async throws {
        guard serverConfigs.keys.contains(name) else {
            throw MCPClientError.serverNotFound(name)
        }
        
        // Disconnect if connected
        if let client = clients[name] {
            await client.disconnect()
        }
        
        clients.removeValue(forKey: name)
        serverConfigs.removeValue(forKey: name)
        
        logger.info("Removed MCP server '\(name)'")
    }
    
    /// Enable an MCP server
    public func enableServer(name: String) async throws {
        guard var config = serverConfigs[name] else {
            throw MCPClientError.serverNotFound(name)
        }
        
        config = MCPServerConfig(
            transport: config.transport,
            command: config.command,
            args: config.args,
            env: config.env,
            enabled: true,
            timeout: config.timeout,
            autoReconnect: config.autoReconnect,
            description: config.description
        )
        
        serverConfigs[name] = config
        clients[name] = MCPClientWrapper(name: name, config: config)
        
        try await connectServer(name: name)
        logger.info("Enabled MCP server '\(name)'")
    }
    
    /// Disable an MCP server
    public func disableServer(name: String) async throws {
        guard var config = serverConfigs[name] else {
            throw MCPClientError.serverNotFound(name)
        }
        
        // Disconnect if connected
        if let client = clients[name] {
            await client.disconnect()
        }
        
        config = MCPServerConfig(
            transport: config.transport,
            command: config.command,
            args: config.args,
            env: config.env,
            enabled: false,
            timeout: config.timeout,
            autoReconnect: config.autoReconnect,
            description: config.description
        )
        
        serverConfigs[name] = config
        logger.info("Disabled MCP server '\(name)'")
    }
    
    /// Get information about a specific server
    public func getServerInfo(name: String) async -> MCPServerInfo? {
        guard let config = serverConfigs[name] else {
            return nil
        }
        
        let health = await checkServerHealth(name: name)
        let toolCount = clients[name]?.getTools().count ?? 0
        let lastConnected = await clients[name]?.getLastConnected()
        
        return MCPServerInfo(
            name: name,
            config: config,
            health: health,
            toolCount: toolCount,
            lastConnected: lastConnected
        )
    }
    
    /// Get all server names
    public func getServerNames() -> [String] {
        return Array(serverConfigs.keys).sorted()
    }
    
    /// Get all server configurations
    public func getServerConfigs() -> [String: MCPServerConfig] {
        return serverConfigs
    }
    
    // MARK: - Connection Management
    
    /// Connect to a specific server
    private func connectServer(name: String) async throws {
        guard let client = clients[name] else {
            throw MCPClientError.serverNotFound(name)
        }
        
        try await client.connect()
    }
    
    /// Disconnect from a specific server
    public func disconnectServer(name: String) async throws {
        guard let client = clients[name] else {
            throw MCPClientError.serverNotFound(name)
        }
        
        await client.disconnect()
    }
    
    // MARK: - Health Checking
    
    /// Check health of a specific server
    public func checkServerHealth(name: String, timeout: TimeInterval = 5.0) async -> MCPServerHealth {
        guard let config = serverConfigs[name] else {
            return .unknown
        }
        
        guard config.enabled else {
            return .disabled
        }
        
        guard let client = clients[name] else {
            return .disconnected(error: "Client not initialized")
        }
        
        let startTime = Date()
        
        do {
            // If not connected, try to connect
            if !await client.isConnected() {
                try await client.connect()
            }
            
            let tools = await client.getTools()
            let responseTime = Date().timeIntervalSince(startTime)
            return .connected(toolCount: tools.count, responseTime: responseTime)
            
        } catch is TimeoutError {
            return .disconnected(error: "Connection timeout")
        } catch {
            return .disconnected(error: error.localizedDescription)
        }
    }
    
    /// Check health of all servers
    public func checkAllServersHealth() async -> [String: MCPServerHealth] {
        var results: [String: MCPServerHealth] = [:]
        
        await withTaskGroup(of: (String, MCPServerHealth).self) { group in
            for serverName in serverConfigs.keys {
                group.addTask {
                    let health = await self.checkServerHealth(name: serverName)
                    return (serverName, health)
                }
            }
            
            for await (name, health) in group {
                results[name] = health
            }
        }
        
        return results
    }
    
    // MARK: - Tool Management
    
    /// Get all external tools organized by server
    public func getExternalTools() async -> [String: [Tool.Info]] {
        var tools: [String: [Tool.Info]] = [:]
        
        for (serverName, client) in clients {
            let serverTools = await client.getTools()
            if !serverTools.isEmpty {
                tools[serverName] = serverTools
            }
        }
        
        return tools
    }
    
    /// Execute a tool on an external server
    public func executeExternalTool(serverName: String, toolName: String, arguments: ToolArguments) async throws -> ToolResponse {
        guard let client = clients[serverName] else {
            throw MCPClientError.serverNotFound(serverName)
        }
        
        // Convert ToolArguments to [String: Any]
        let argumentsDict: [String: Any]
        if case let .object(dict) = arguments.rawValue {
            argumentsDict = dict.mapValues { value in
                switch value {
                case let .string(str): return str
                case let .int(num): return num
                case let .double(num): return num
                case let .bool(bool): return bool
                case .null: return NSNull()
                case let .array(arr): return arr
                case let .object(obj): return obj
                }
            }
        } else {
            argumentsDict = [:]
        }
        
        do {
            let result = try await client.executeTool(name: toolName, arguments: argumentsDict)
            
            // Convert result to ToolResponse
            let content = result.content.map { contentItem in
                switch contentItem {
                case let .text(text):
                    return MCP.Tool.Content.text(text)
                case let .image(data, mimeType, _):
                    return MCP.Tool.Content.image(data: data, mimeType: mimeType, metadata: nil)
                case let .resource(resource):
                    return MCP.Tool.Content.resource(resource)
                }
            }
            
            return ToolResponse(
                content: content,
                isError: result.isError ?? false
            )
            
        } catch {
            throw MCPClientError.executionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Extensions

extension ToolArguments {
    /// Access the internal raw value for external tool execution
    internal var rawValue: Value {
        // Use reflection to access the private raw property
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "raw", let value = child.value as? Value {
                return value
            }
        }
        return .object([:]) // Fallback to empty object
    }
}