import Foundation
import MCP
import os.log

/// Registry for managing MCP tools
@MainActor
public final class MCPToolRegistry {
    private let logger = Logger(subsystem: "boo.peekaboo.mcp", category: "registry")
    private var tools: [String: MCPTool] = [:]

    public init() {}

    /// Register a tool
    public func register(_ tool: MCPTool) {
        self.tools[tool.name] = tool
        self.logger.debug("Registered tool: \(tool.name)")
    }

    /// Register multiple tools
    public func register(_ tools: [MCPTool]) {
        for tool in tools {
            self.register(tool)
        }
    }

    /// Get a tool by name
    public func tool(named name: String) -> MCPTool? {
        self.tools[name]
    }

    /// Get all registered tools
    public func allTools() -> [MCPTool] {
        Array(self.tools.values)
    }

    /// Get tool information for MCP
    public func toolInfos() -> [MCP.Tool] {
        self.allTools().map { tool in
            MCP.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema)
        }
    }

    /// Check if a tool is registered
    public func hasToolNamed(_ name: String) -> Bool {
        self.tools[name] != nil
    }

    /// Remove a tool
    public func unregister(_ name: String) {
        self.tools.removeValue(forKey: name)
        self.logger.debug("Unregistered tool: \(name)")
    }

    /// Remove all tools
    public func unregisterAll() {
        self.tools.removeAll()
        self.logger.debug("Unregistered all tools")
    }
}
