//
//  MCPClientService.swift
//  PeekabooCLI
//

import MCP
import PeekabooCore
import TachikomaMCP

struct MCPServerInfo {
    let name: String
    let config: TachikomaMCP.MCPServerConfig
    let connected: Bool
}

protocol MCPClientService: AnyObject {
    func bootstrap(connect: Bool) async
    func serverNames() -> [String]
    func serverInfo(name: String) async -> MCPServerInfo?
    func probeAll(timeoutMs: Int) async -> [String: MCPServerHealth]
    func probe(name: String, timeoutMs: Int) async -> MCPServerHealth
    func execute(server: String, tool: String, args: [String: Any]) async throws -> ToolResponse
    func addServer(name: String, config: TachikomaMCP.MCPServerConfig) async throws
    func removeServer(name: String) async
    func enableServer(name: String) async throws
    func disableServer(name: String) async
    func persist() throws
    func checkServerHealth(name: String, timeoutMs: Int) async -> MCPServerHealth
    func externalToolsByServer() async -> [String: [MCP.Tool]]
}

/// Main implementation backed by TachikomaMCPClientManager.
@MainActor
final class DefaultMCPClientService: MCPClientService {
    static let shared = DefaultMCPClientService(manager: TachikomaMCPClientManager.shared)

    private let manager: TachikomaMCPClientManager
    private var defaultsRegistered = false

    init(manager: TachikomaMCPClientManager) {
        self.manager = manager
    }

    func bootstrap(connect: Bool) async {
        self.registerDefaultsIfNeeded()
        await self.manager.initializeFromProfile(connect: connect)
    }

    func serverNames() -> [String] {
        self.manager.getServerNames()
    }

    func serverInfo(name: String) async -> MCPServerInfo? {
        guard let info = await self.manager.getServerInfo(name: name) else { return nil }
        return MCPServerInfo(name: name, config: info.config, connected: info.connected)
    }

    func probeAll(timeoutMs: Int) async -> [String: MCPServerHealth] {
        let probes = await self.manager.probeAllServers(timeoutMs: timeoutMs)
        var healthResults: [String: MCPServerHealth] = [:]
        for (name, probe) in probes {
            healthResults[name] = probe.isConnected ? .connected(
                toolCount: probe.toolCount,
                responseTime: probe.responseTime
            ) : .disconnected(error: probe.error ?? "unknown error")
        }
        return healthResults
    }

    func probe(name: String, timeoutMs: Int) async -> MCPServerHealth {
        let probe = await self.manager.probeServer(name: name, timeoutMs: timeoutMs)
        return probe.isConnected ? .connected(toolCount: probe.toolCount, responseTime: probe.responseTime) :
            .disconnected(error: probe.error ?? "unknown error")
    }

    func execute(server: String, tool: String, args: [String: Any]) async throws -> ToolResponse {
        try await self.manager.executeTool(serverName: server, toolName: tool, arguments: args)
    }

    func addServer(name: String, config: TachikomaMCP.MCPServerConfig) async throws {
        try await self.manager.addServer(name: name, config: config)
    }

    func removeServer(name: String) async {
        await self.manager.removeServer(name: name)
    }

    func enableServer(name: String) async throws {
        try await self.manager.enableServer(name: name)
    }

    func disableServer(name: String) async {
        await self.manager.disableServer(name: name)
    }

    func persist() throws {
        try self.manager.persist()
    }

    func checkServerHealth(name: String, timeoutMs: Int = 5000) async -> MCPServerHealth {
        await self.probe(name: name, timeoutMs: timeoutMs)
    }

    func externalToolsByServer() async -> [String: [MCP.Tool]] {
        await self.manager.getExternalToolsByServer()
    }

    private func registerDefaultsIfNeeded() {
        guard !self.defaultsRegistered else { return }
        let defaultChromeDevTools = ChromeDevToolsServerFactory.tachikomaConfig(timeout: 15.0, autoReconnect: true)
        self.manager.registerDefaultServers([MCPDefaults.serverName: defaultChromeDevTools])
        self.defaultsRegistered = true
    }
}
