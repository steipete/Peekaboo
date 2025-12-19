import Foundation
import MCP
import os.log
import TachikomaMCP

/// Registry for managing MCP tools
@MainActor
public final class MCPToolRegistry {
    private let logger = Logger(subsystem: "boo.peekaboo.mcp", category: "registry")
    private var tools: [String: any MCPTool] = [:]

    public init() {}

    /// Register a tool
    public func register(_ tool: any MCPTool) {
        // Register a tool
        self.tools[tool.name] = tool
        self.logger.debug("Registered tool: \(tool.name)")
    }

    /// Register multiple tools
    public func register(_ tools: [any MCPTool]) {
        // Register multiple tools
        for tool in tools {
            self.register(tool)
        }
    }

    /// Get a tool by name
    public func tool(named name: String) -> (any MCPTool)? {
        // Get a tool by name
        self.tools[name]
    }

    /// Get all registered tools
    public func allTools() -> [any MCPTool] {
        // Get all registered tools
        Array(self.tools.values)
    }

    /// Get tool information for MCP
    public func toolInfos() -> [MCP.Tool] {
        // Get tool information for MCP
        self.allTools().map { tool in
            MCP.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema)
        }
    }

    /// Check if a tool is registered
    public func hasToolNamed(_ name: String) -> Bool {
        // Check if a tool is registered
        self.tools[name] != nil
    }

    /// Remove a tool
    public func unregister(_ name: String) {
        // Remove a tool
        self.tools.removeValue(forKey: name)
        self.logger.debug("Unregistered tool: \(name)")
    }

    /// Remove all tools
    public func unregisterAll() {
        // Remove all tools
        self.tools.removeAll()
        self.logger.debug("Unregistered all tools")
    }
}
