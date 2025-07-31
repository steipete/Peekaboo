import Foundation
import MCP
import os.log

/// Registry for managing MCP tools
@MainActor
public final class MCPToolRegistry: Sendable {
    private let logger = Logger(subsystem: "boo.peekaboo.mcp", category: "registry")
    private var tools: [String: MCPTool] = [:]
    
    public init() {}
    
    /// Register a tool
    public func register(_ tool: MCPTool) {
        tools[tool.name] = tool
        logger.debug("Registered tool: \(tool.name)")
    }
    
    /// Register multiple tools
    public func register(_ tools: [MCPTool]) {
        for tool in tools {
            register(tool)
        }
    }
    
    /// Get a tool by name
    public func tool(named name: String) -> MCPTool? {
        tools[name]
    }
    
    /// Get all registered tools
    public func allTools() -> [MCPTool] {
        Array(tools.values)
    }
    
    /// Get tool information for MCP
    public func toolInfos() -> [Tool] {
        allTools().map { tool in
            Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema
            )
        }
    }
    
    /// Check if a tool is registered
    public func hasToolNamed(_ name: String) -> Bool {
        tools[name] != nil
    }
    
    /// Remove a tool
    public func unregister(_ name: String) {
        tools.removeValue(forKey: name)
        logger.debug("Unregistered tool: \(name)")
    }
    
    /// Remove all tools
    public func unregisterAll() {
        tools.removeAll()
        logger.debug("Unregistered all tools")
    }
}