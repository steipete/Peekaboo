import Foundation
import MCP
import TachikomaMCP

@MainActor
final class BrowserMCPSessionManager: @unchecked Sendable {
    private let serverName: String
    private var manager: TachikomaMCPClientManager
    private var connectedChannel: BrowserMCPChannel?

    init(serverName: String, manager: TachikomaMCPClientManager = TachikomaMCPClientManager()) {
        self.serverName = serverName
        self.manager = manager
    }

    func status(channel: BrowserMCPChannel?) async -> BrowserMCPStatus {
        let browserChannel = self.resolvedChannel(channel)
        let isConnected = await self.manager.isServerConnected(name: self.serverName)
        let tools = await self.manager.getServerTools(name: self.serverName)
        return BrowserMCPStatus(
            isConnected: isConnected,
            toolCount: tools.count,
            detectedBrowsers: BrowserMCPService.detectRunningBrowsers(channel: browserChannel),
            error: nil)
    }

    func connect(channel: BrowserMCPChannel?) async throws -> BrowserMCPStatus {
        let browserChannel = self.resolvedChannel(channel)
        let isConnected = await self.manager.isServerConnected(name: self.serverName)
        if isConnected, self.connectedChannel == browserChannel {
            return await self.status(channel: browserChannel)
        }

        let config = BrowserMCPService.chromeDevToolsConfig(channel: browserChannel)
        if self.manager.getServerConfig(name: self.serverName) != nil {
            await self.manager.removeServer(name: self.serverName)
        }
        try await self.manager.addServer(name: self.serverName, config: config)
        self.connectedChannel = browserChannel
        return await self.status(channel: browserChannel)
    }

    func disconnect() async {
        await self.manager.disableServer(name: self.serverName)
        self.connectedChannel = nil
    }

    func execute(
        toolName: String,
        arguments: [String: Any],
        channel: BrowserMCPChannel?) async throws -> ToolResponse
    {
        if await !self.manager.isServerConnected(name: self.serverName) ||
            (channel != nil && channel != self.connectedChannel)
        {
            _ = try await self.connect(channel: channel)
        }

        return try await self.manager.executeTool(
            serverName: self.serverName,
            toolName: toolName,
            arguments: arguments)
    }

    private func resolvedChannel(_ requestedChannel: BrowserMCPChannel?) -> BrowserMCPChannel {
        requestedChannel ?? self.connectedChannel ?? BrowserMCPService.preferredChannel()
    }
}
