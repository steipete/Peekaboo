import Foundation
import MCP
import OrderedCollections
import os.log
import PeekabooExternalDependencies
import TachikomaMCP

/// External MCP tool that proxies requests to an external MCP server
public struct ExternalMCPTool: MCPTool {
    public let serverName: String
    public let originalTool: Tool
    private let clientManager: TachikomaMCPClientManager
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp.client", category: "external-tool")

    public init(serverName: String, originalTool: Tool, clientManager: TachikomaMCPClientManager) {
        self.serverName = serverName
        self.originalTool = originalTool
        self.clientManager = clientManager
    }

    // MARK: - MCPTool Implementation

    public var name: String {
        "\(self.serverName):\(self.originalTool.name)"
    }

    public var description: String {
        let toolDescription = self.originalTool.description ?? ""
        return "[\(self.serverName)] \(toolDescription)"
    }

    public var inputSchema: Value {
        self.originalTool.inputSchema
    }

    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        self.logger.info("Executing external tool '\(self.name)' with arguments")

        do {
            let response = try await clientManager.executeTool(
                serverName: self.serverName,
                toolName: self.originalTool.name,
                arguments: arguments.rawDictionary)

            self.logger.info("External tool '\(self.name)' executed successfully")
            return response

        } catch {
            self.logger.error("External tool '\(self.name)' execution failed: \(error.localizedDescription)")
            throw error
        }
    }
}

/// Tool source enumeration for organizing tools
public enum ToolSource: Sendable {
    case native
    case external(serverName: String)

    public var displayName: String {
        switch self {
        case .native:
            "Native"
        case let .external(serverName):
            serverName
        }
    }
}

/// Categorized tools for display purposes
public struct CategorizedTools: Sendable {
    public typealias ToolList = [any MCPTool]

    public let native: ToolList
    public let external: OrderedDictionary<String, ToolList>

    public init(native: ToolList, external: OrderedDictionary<String, ToolList>) {
        self.native = native
        self.external = external
    }

    public init(native: ToolList, external: [String: ToolList]) {
        let ordered = OrderedDictionary(uniqueKeysWithValues: external.sorted { $0.key < $1.key })
        self.init(native: native, external: ordered)
    }

    /// Get total count of all tools
    public var totalCount: Int {
        self.native.count + self.external.values.reduce(0) { $0 + $1.count }
    }

    /// Get count of external tools
    public var externalCount: Int {
        self.external.values.reduce(0) { $0 + $1.count }
    }

    /// Get all external tools as a flat array
    public var allExternalTools: ToolList {
        self.external.values.flatMap(\.self)
    }

    /// Get tools from a specific server
    public func tools(from serverName: String) -> ToolList {
        // Get tools from a specific server
        self.external[serverName] ?? []
    }

    /// Check if a server has any tools
    public func hasTools(from serverName: String) -> Bool {
        // Check if a server has any tools
        !(self.external[serverName]?.isEmpty ?? true)
    }
}

/// Tool filtering options
public struct ToolFilter: Sendable {
    public let showNativeOnly: Bool
    public let showMcpOnly: Bool
    public let specificServer: String?
    public let includeDisabled: Bool

    public init(
        showNativeOnly: Bool = false,
        showMcpOnly: Bool = false,
        specificServer: String? = nil,
        includeDisabled: Bool = false)
    {
        self.showNativeOnly = showNativeOnly
        self.showMcpOnly = showMcpOnly
        self.specificServer = specificServer
        self.includeDisabled = includeDisabled
    }

    /// Default filter that shows all tools
    public static let all = ToolFilter()

    /// Filter that shows only native tools
    public static let nativeOnly = ToolFilter(showNativeOnly: true)

    /// Filter that shows only MCP tools
    public static let mcpOnly = ToolFilter(showMcpOnly: true)

    /// Create filter for specific MCP server
    public static func server(_ name: String) -> ToolFilter {
        // Create filter for specific MCP server
        ToolFilter(specificServer: name)
    }
}

/// Tool display configuration
public struct ToolDisplayOptions: Sendable {
    public let useServerPrefixes: Bool
    public let groupByServer: Bool
    public let showToolCount: Bool
    public let sortAlphabetically: Bool
    public let showDescription: Bool

    public init(
        useServerPrefixes: Bool = true,
        groupByServer: Bool = false,
        showToolCount: Bool = true,
        sortAlphabetically: Bool = true,
        showDescription: Bool = true)
    {
        self.useServerPrefixes = useServerPrefixes
        self.groupByServer = groupByServer
        self.showToolCount = showToolCount
        self.sortAlphabetically = sortAlphabetically
        self.showDescription = showDescription
    }

    /// Default display options
    public static let `default` = ToolDisplayOptions()

    /// Compact display for CLI usage
    public static let compact = ToolDisplayOptions(
        showToolCount: false,
        showDescription: false)

    /// Verbose display with all information
    public static let verbose = ToolDisplayOptions(
        groupByServer: true,
        showDescription: true)
}

/// Helper for tool organization and display
public struct ToolOrganizer: Sendable {
    /// Apply filter to categorized tools
    public static func filter(_ tools: CategorizedTools, with filter: ToolFilter) -> CategorizedTools {
        // Apply filter to categorized tools
        var filteredNative: CategorizedTools.ToolList = []
        var filteredExternal = OrderedDictionary<String, CategorizedTools.ToolList>()

        // Handle native tools
        let isServerScoped = filter.specificServer != nil

        if !filter.showMcpOnly, !isServerScoped {
            filteredNative = tools.native
        }

        // Handle external tools
        if !filter.showNativeOnly {
            if let specificServer = filter.specificServer {
                // Show only tools from specific server
                if let serverTools = tools.external[specificServer] {
                    filteredExternal[specificServer] = serverTools
                }
            } else {
                // Show all external tools
                filteredExternal = tools.external
            }
        }

        return CategorizedTools(native: filteredNative, external: filteredExternal)
    }

    /// Sort tools within categories
    public static func sort(_ tools: CategorizedTools, alphabetically: Bool = true) -> CategorizedTools {
        // Sort tools within categories
        guard alphabetically else { return tools }

        let sortedNative = tools.native.sorted { $0.name < $1.name }
        let sortedExternal = tools.external.mapValues { toolList in
            toolList.sorted { $0.name < $1.name }
        }

        return CategorizedTools(native: sortedNative, external: sortedExternal)
    }

    /// Get display name for a tool based on options
    public static func displayName(for tool: any MCPTool, options: ToolDisplayOptions) -> String {
        // Get display name for a tool based on options
        if let externalTool = tool as? ExternalMCPTool {
            if options.useServerPrefixes {
                return externalTool.name // Already includes server prefix
            } else {
                return externalTool.originalTool.name // Original name without prefix
            }
        }
        return tool.name
    }

    /// Format tool description for display
    public static func formatDescription(_ description: String, maxLength: Int = 80) -> String {
        // Format tool description for display
        if description.count <= maxLength {
            return description
        }

        let truncated = String(description.prefix(maxLength - 3))
        return "\(truncated)..."
    }
}
