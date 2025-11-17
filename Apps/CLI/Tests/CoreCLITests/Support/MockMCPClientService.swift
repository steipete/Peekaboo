//
//  MockMCPClientService.swift
//  PeekabooCLITests
//

import Foundation
import MCP
import PeekabooCore
import TachikomaMCP
@testable import PeekabooCLI

@MainActor
final class MockMCPClientService: MCPClientService {
    var bootstrapCount = 0
    var bootstrapConnectFlags: [Bool] = []

    var serverNamesValue: [String] = []
    var serverInfos: [String: PeekabooCLI.MCPServerInfo] = [:]
    var healthByServer: [String: MCPServerHealth] = [:]
    var externalTools: [String: [MCP.Tool]] = [:]
    var executeResponses: [String: ToolResponse] = [:] // key: server|tool
    var persistCount = 0

    var addShouldThrow: (any Error)?
    var enableShouldThrow: (any Error)?
    var disableShouldThrow: (any Error)?

    var addCalls: [(String, TachikomaMCP.MCPServerConfig)] = []
    var removeCalls: [String] = []
    var enableCalls: [String] = []
    var disableCalls: [String] = []
    var probes: [String] = []
    var probeAllCount = 0
    var executeCalls: [(server: String, tool: String, args: [String: Any])] = []

    func bootstrap(connect: Bool) async {
        self.bootstrapCount += 1
        self.bootstrapConnectFlags.append(connect)
    }

    func serverNames() -> [String] { self.serverNamesValue }

    func serverInfo(name: String) async -> PeekabooCLI.MCPServerInfo? { self.serverInfos[name] }

    func probeAll(timeoutMs: Int) async -> [String: MCPServerHealth] {
        self.probeAllCount += 1
        return self.healthByServer
    }

    func probe(name: String, timeoutMs: Int) async -> MCPServerHealth {
        self.probes.append(name)
        return self.healthByServer[name] ?? .unknown
    }

    func execute(server: String, tool: String, args: [String: Any]) async throws -> ToolResponse {
        self.executeCalls.append((server, tool, args))
        let key = "\(server)|\(tool)"
        return self.executeResponses[key] ?? ToolResponse(content: [.text("ok")], isError: false)
    }

    func addServer(name: String, config: TachikomaMCP.MCPServerConfig) async throws {
        if let error = self.addShouldThrow { throw error }
        self.addCalls.append((name, config))
        self.serverInfos[name] = PeekabooCLI.MCPServerInfo(name: name, config: config, connected: false)
    }

    func removeServer(name: String) async {
        self.removeCalls.append(name)
        self.serverInfos.removeValue(forKey: name)
    }

    func enableServer(name: String) async throws {
        if let error = self.enableShouldThrow { throw error }
        self.enableCalls.append(name)
    }

    func disableServer(name: String) async {
        if let error = self.disableShouldThrow { fatalError(error.localizedDescription) }
        self.disableCalls.append(name)
    }

    func persist() throws { self.persistCount += 1 }

    func checkServerHealth(name: String, timeoutMs: Int) async -> MCPServerHealth {
        self.probes.append(name)
        return self.healthByServer[name] ?? .unknown
    }

    func externalToolsByServer() async -> [String: [MCP.Tool]] { self.externalTools }
}
