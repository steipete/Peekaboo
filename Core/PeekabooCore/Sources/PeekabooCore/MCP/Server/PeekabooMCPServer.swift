import Foundation
import MCP
import os.log

/// Transport types supported by the MCP server
public enum TransportType: CustomStringConvertible {
    case stdio
    case http
    case sse

    public var description: String {
        switch self {
        case .stdio: "stdio"
        case .http: "http"
        case .sse: "sse"
        }
    }
}

/// Peekaboo MCP Server implementation
public actor PeekabooMCPServer {
    private let server: Server
    private let toolRegistry: MCPToolRegistry
    private let logger: os.Logger
    private let serverName = "peekaboo-mcp"
    private let serverVersion = "3.0.0-beta.2"

    public init() async throws {
        self.logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "server")
        self.toolRegistry = await MCPToolRegistry()

        // Initialize the official MCP Server
        self.server = Server(
            name: self.serverName,
            version: self.serverVersion,
            capabilities: Server.Capabilities(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: true)))

        await self.setupHandlers()
        await self.registerAllTools()
    }

    private func setupHandlers() async {
        // Tool list handler
        await self.server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self else { return ListTools.Result(tools: []) }

            let tools = await self.toolRegistry.toolInfos()
            return ListTools.Result(tools: tools)
        }

        // Tool call handler
        await self.server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else {
                throw MCP.MCPError.methodNotFound("Server deallocated")
            }

            guard let tool = await self.toolRegistry.tool(named: params.name) else {
                throw MCP.MCPError.invalidParams("Tool '\(params.name)' not found")
            }

            let arguments = ToolArguments(value: .object(params.arguments ?? [:]))

            // Execute tool on main thread
            let response = try await tool.execute(arguments: arguments)

            return CallTool.Result(
                content: response.content,
                isError: response.isError)
        }

        // Resources list handler (empty for now, but prevents inspector errors)
        await self.server.withMethodHandler(ListResources.self) { _ in
            // Return empty resources list
            ListResources.Result(resources: [], nextCursor: nil)
        }

        // Resources read handler (returns error for now)
        await self.server.withMethodHandler(ReadResource.self) { params in
            throw MCP.MCPError.invalidParams("Resource '\(params.uri)' not found")
        }

        // Initialize handler
        await self.server.withMethodHandler(Initialize.self) { [weak self] request in
            guard let self else {
                throw MCP.MCPError.methodNotFound("Server deallocated")
            }

            self.logger
                .info(
                    "Client connected: \(request.clientInfo.name) \(request.clientInfo.version), protocol: \(request.protocolVersion)")

            // Create a response struct that matches Initialize.Result
            struct InitializeResult: Codable {
                let protocolVersion: String
                let capabilities: Server.Capabilities
                let serverInfo: Server.Info
                let instructions: String?
            }

            let result = await InitializeResult(
                protocolVersion: "2024-11-05",
                capabilities: self.server.capabilities,
                serverInfo: Server.Info(
                    name: self.serverName,
                    version: self.serverVersion),
                instructions: nil)

            // Convert to Initialize.Result via JSON
            let data = try JSONEncoder().encode(result)
            return try JSONDecoder().decode(Initialize.Result.self, from: data)
        }
    }

    private func registerAllTools() async {
        // Register all Peekaboo tools
        await self.toolRegistry.register([
            // Core tools
            ImageTool(),
            AnalyzeTool(),
            ListTool(),
            PermissionsTool(),
            SleepTool(),

            // UI automation tools
            SeeTool(),
            ClickTool(),
            TypeTool(),
            ScrollTool(),
            HotkeyTool(),
            SwipeTool(),
            DragTool(),
            MoveTool(),

            // App management tools
            AppTool(),
            WindowTool(),
            MenuTool(),

            // System tools
            // RunTool(), // Removed: Security risk - allows arbitrary script execution
            // CleanTool(), // Removed: Internal maintenance tool, not for external use

            // Advanced tools
            AgentTool(),
            DockTool(),
            DialogTool(),
            SpaceTool(),
        ])

        let toolCount = await self.toolRegistry.allTools().count
        self.logger.info("Registered \(toolCount) tools")
    }

    public func serve(transport: TransportType, port: Int = 8080) async throws {
        self.logger.info("Starting Peekaboo MCP server on \(transport) transport, version: \(self.serverVersion)")

        let serverTransport: any Transport

        switch transport {
        case .stdio:
            serverTransport = StdioTransport()

        case .http:
            // Note: HTTP transport would need custom implementation
            // as the SDK only provides HTTPClientTransport
            throw MCPError.notImplemented("HTTP server transport not yet implemented")

        case .sse:
            throw MCPError.notImplemented("SSE server transport not yet implemented")
        }

        try await self.server.start(transport: serverTransport)

        // Keep the server running
        await self.server.waitUntilCompleted()
    }
}

// MARK: - Supporting Types

public enum MCPError: LocalizedError {
    case notImplemented(String)
    case toolNotFound(String)
    case invalidArguments(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .notImplemented(feature):
            "\(feature) is not yet implemented"
        case let .toolNotFound(tool):
            "Tool '\(tool)' not found"
        case let .invalidArguments(details):
            "Invalid arguments: \(details)"
        case let .executionFailed(message):
            "Execution failed: \(message)"
        }
    }
}
