import Foundation
import MCP
import OrderedCollections
import os.log
import PeekabooExternalDependencies
import TachikomaMCP

/// Registry for managing MCP tools
@MainActor
public final class MCPToolRegistry {
    private let logger = Logger(subsystem: "boo.peekaboo.mcp", category: "registry")
    private var tools: [String: any MCPTool] = [:]
    private var externalTools: [String: any MCPTool] = [:]
    private var clientManager: TachikomaMCPClientManager?

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

    // MARK: - External Tool Management

    /// Set the client manager for external tools
    public func setClientManager(_ clientManager: TachikomaMCPClientManager) {
        // Set the client manager for external tools
        self.clientManager = clientManager
    }

    /// Register external tools from the client manager
    public func registerExternalTools(from clientManager: TachikomaMCPClientManager) async {
        // Register external tools from the client manager
        self.clientManager = clientManager

        // Clear existing external tools
        self.externalTools.removeAll()

        // Get external tools from all servers
        let externalToolsByServer = await clientManager.getExternalToolsByServer()

        for (serverName, serverTools) in externalToolsByServer {
            for toolInfo in serverTools {
                let externalTool = ExternalMCPTool(
                    serverName: serverName,
                    originalTool: toolInfo,
                    clientManager: clientManager)
                self.externalTools[externalTool.name] = externalTool
                self.logger.debug("Registered external tool: \(externalTool.name)")
            }
        }

        self.logger
            .info("Registered \(self.externalTools.count) external tools from \(externalToolsByServer.count) servers")
    }

    /// Refresh external tools from servers
    public func refreshExternalTools() async throws {
        // Refresh external tools from servers
        guard let clientManager else {
            throw MCPError.executionFailed("Client manager not set")
        }

        await self.registerExternalTools(from: clientManager)
    }

    /// Get tools organized by source (native vs external)
    public func getToolsBySource() async -> CategorizedTools {
        // Get tools organized by source (native vs external)
        let nativeTools = Array(tools.values)

        // Organize external tools by server
        let groupedByServer = Dictionary(grouping: self.externalTools.values.compactMap { $0 as? ExternalMCPTool }) {
            $0.serverName
        }

        var externalByServer = OrderedDictionary<String, [any MCPTool]>()
        for serverName in groupedByServer.keys.sorted() {
            let toolsForServer = groupedByServer[serverName]?.sorted { $0.name < $1.name } ?? []
            externalByServer[serverName] = toolsForServer.map { $0 as any MCPTool }
        }

        return CategorizedTools(native: nativeTools, external: externalByServer)
    }

    /// Get a tool with prefix support (e.g., "github:create_issue")
    public func getToolWithPrefix(name: String) -> (any MCPTool)? {
        // First try exact match (handles both native and external tools)
        if let tool = tools[name] ?? externalTools[name] {
            return tool
        }

        // If not found and no prefix, try searching external tools
        if !name.contains(":") {
            // Look for external tools that match the unprefixed name
            for (_, tool) in self.externalTools {
                if let externalTool = tool as? ExternalMCPTool {
                    if externalTool.originalTool.name == name {
                        return tool
                    }
                }
            }
        }

        return nil
    }

    /// Get all tools (native + external)
    public func getAllTools() -> [any MCPTool] {
        // Get all tools (native + external)
        Array(self.tools.values) + Array(self.externalTools.values)
    }

    /// Get external tools only
    public func getExternalTools() -> [any MCPTool] {
        // Get external tools only
        Array(self.externalTools.values)
    }

    /// Get native tools only
    public func getNativeTools() -> [any MCPTool] {
        // Get native tools only
        Array(self.tools.values)
    }

    /// Check if an external tool exists
    public func hasExternalTool(_ name: String) -> Bool {
        // Check if an external tool exists
        self.externalTools[name] != nil
    }

    /// Get tool count by type
    public func getToolCounts() -> (native: Int, external: Int, total: Int) {
        // Get tool count by type
        let nativeCount = self.tools.count
        let externalCount = self.externalTools.count
        return (native: nativeCount, external: externalCount, total: nativeCount + externalCount)
    }

    // MARK: - Updated Methods for Combined Tools

    /// Get a tool by name (checks both native and external)
    public func toolCombined(named name: String) -> (any MCPTool)? {
        // Get a tool by name (checks both native and external)
        self.tools[name] ?? self.externalTools[name]
    }

    /// Get tool information for MCP (includes external tools)
    public func allToolInfos() -> [MCP.Tool] {
        // Get tool information for MCP (includes external tools)
        let allTools = Array(tools.values) + Array(self.externalTools.values)
        return allTools.map { tool in
            MCP.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema)
        }
    }

    /// Check if any tool is registered with the given name
    public func hasAnyToolNamed(_ name: String) -> Bool {
        // Check if any tool is registered with the given name
        self.tools[name] != nil || self.externalTools[name] != nil
    }
}
