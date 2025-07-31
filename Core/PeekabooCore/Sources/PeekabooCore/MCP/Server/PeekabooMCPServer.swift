import Foundation
import MCP
import os.log

/// Peekaboo MCP Server implementation
public actor PeekabooMCPServer {
    private let server: Server
    private let toolRegistry: MCPToolRegistry
    private let logger: Logger
    
    public init(logLevel: LogLevel = .info) throws {
        self.logger = Logger(subsystem: "boo.peekaboo.mcp", category: "server")
        self.toolRegistry = MCPToolRegistry()
        
        // Initialize the official MCP Server
        self.server = Server(
            name: "peekaboo-mcp",
            version: Version.current.string,
            capabilities: Server.Capabilities(
                tools: .init(listChanged: true),
                resources: .init(subscribe: false, listChanged: false),
                prompts: .init(listChanged: false)
            )
        )
        
        setupHandlers()
        Task { await registerAllTools() }
    }
    
    private func setupHandlers() {
        // Tool list handler
        server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else { return ListTools.Response(tools: []) }
            
            let tools = await self.toolRegistry.toolInfos()
            return ListTools.Response(tools: tools)
        }
        
        // Tool call handler
        server.withMethodHandler(CallTool.self) { [weak self] request in
            guard let self = self else {
                throw ServerError(code: ErrorCode.internalError, message: "Server deallocated")
            }
            
            guard let tool = await self.toolRegistry.tool(named: request.name) else {
                throw ServerError(code: ErrorCode.invalidParams, message: "Tool '\(request.name)' not found")
            }
            
            let arguments = ToolArguments(raw: request.arguments ?? [:])
            let response = try await tool.execute(arguments: arguments)
            
            return CallTool.Response(
                content: response.content,
                isError: response.isError,
                meta: response.meta
            )
        }
        
        // Initialize handler
        server.withMethodHandler(Initialize.self) { [weak self] request in
            guard let self = self else {
                throw ServerError(code: ErrorCode.internalError, message: "Server deallocated")
            }
            
            await self.logger.info("Client connected", metadata: [
                "clientInfo": "\(request.clientInfo.name) \(request.clientInfo.version)",
                "protocolVersion": "\(request.protocolVersion)"
            ])
            
            return Initialize.Response(
                protocolVersion: "2024-11-05",
                capabilities: self.server.capabilities,
                serverInfo: Server.Info(
                    name: self.server.name,
                    version: self.server.version
                )
            )
        }
    }
    
    private func registerAllTools() async {
        // Register all Peekaboo tools
        await toolRegistry.register([
            // Core tools
            ImageTool(),
            AnalyzeTool(),
            ListTool(),
            PermissionsTool(),
            
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
            RunTool(),
            SleepTool(),
            CleanTool(),
            
            // Advanced tools
            AgentTool(),
            DockTool(),
            DialogTool(),
            SpaceTool(),
        ])
        
        logger.info("Registered \(await toolRegistry.allTools().count) tools")
    }
    
    public func serve(transport: TransportType, port: Int = 8080) async throws {
        logger.info("Starting Peekaboo MCP server", metadata: [
            "transport": "\(transport)",
            "version": "\(Version.current.string)"
        ])
        
        let serverTransport: any Transport
        
        switch transport {
        case .stdio:
            serverTransport = StdioTransport(logger: logger)
            
        case .http:
            // Note: HTTP transport would need custom implementation
            // as the SDK only provides HTTPClientTransport
            throw MCPError.notImplemented("HTTP server transport not yet implemented")
            
        case .sse:
            throw MCPError.notImplemented("SSE server transport not yet implemented")
        }
        
        try await server.start(transport: serverTransport)
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
        case .notImplemented(let feature):
            return "\(feature) is not yet implemented"
        case .toolNotFound(let tool):
            return "Tool '\(tool)' not found"
        case .invalidArguments(let details):
            return "Invalid arguments: \(details)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}