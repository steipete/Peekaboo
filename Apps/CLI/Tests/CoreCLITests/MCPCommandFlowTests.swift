//
//  MCPCommandFlowTests.swift
//  PeekabooCLITests
//

import Commander
import Foundation
import PeekabooCore
import TachikomaMCP
import Testing
@testable import PeekabooCLI

@Suite("MCP command flows", .tags(.safe))
@MainActor
struct MCPCommandFlowTests {
    private func makeRuntime(json: Bool = true) -> CommandRuntime {
        CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: json, logLevel: nil),
            services: PeekabooServices()
        )
    }

    @Test func callUsesServiceSequence() async throws {
        let mock = MockMCPClientService()
        mock.serverInfos["alpha"] = MCPServerInfo(
            name: "alpha",
            config: MCPServerConfig(
                transport: "stdio",
                command: "server-alpha",
                args: [],
                env: [:],
                enabled: true,
                timeout: 5,
                autoReconnect: true,
                description: nil
            ),
            connected: true
        )
        mock.healthByServer["alpha"] = .connected(toolCount: 1, responseTime: 0.01)
        mock.executeResponses["alpha|ping"] = .text("pong")

        var command = MCPCommand.Call()
        command.server = "alpha"
        command.tool = "ping"
        command.args = #"{"x":1}"#
        command.service = mock

        try await command.run(using: self.makeRuntime())

        #expect(mock.bootstrapCount == 1)
        #expect(mock.probes == ["alpha"])
        let call = try #require(mock.executeCalls.first)
        #expect(call.server == "alpha")
        #expect(call.tool == "ping")
        #expect((call.args["x"] as? Int) == 1)
    }

    @Test func listFetchesHealthAndExternalTools() async throws {
        let mock = MockMCPClientService()
        mock.serverNamesValue = ["beta"]
        mock.serverInfos["beta"] = MCPServerInfo(
            name: "beta",
            config: MCPServerConfig(
                transport: "stdio",
                command: "beta-cmd",
                args: [],
                env: [:],
                enabled: true,
                timeout: 5,
                autoReconnect: true,
                description: "desc"
            ),
            connected: true
        )
        mock.healthByServer["beta"] = .connected(toolCount: 2, responseTime: 0.02)
        mock.externalTools["beta"] = []

        var command = MCPCommand.List()
        command.skipHealthCheck = false
        command.service = mock

        try await command.run(using: self.makeRuntime())

        #expect(mock.bootstrapCount == 1)
        #expect(mock.probeAllCount == 1)
        #expect(mock.serverNamesValue == ["beta"])
    }

    @Test func infoIncludesHealthCheck() async throws {
        let mock = MockMCPClientService()
        mock.serverInfos["gamma"] = MCPServerInfo(
            name: "gamma",
            config: MCPServerConfig(
                transport: "stdio",
                command: "cmd",
                args: ["--flag"],
                env: ["A": "B"],
                enabled: true,
                timeout: 3,
                autoReconnect: false,
                description: "test server"
            ),
            connected: false
        )
        mock.healthByServer["gamma"] = .disconnected(error: "boom")

        var command = MCPCommand.Info()
        command.name = "gamma"
        command.service = mock

        try await command.run(using: self.makeRuntime())

        #expect(mock.bootstrapCount == 1)
        #expect(mock.probes.contains("gamma"))
    }

    @Test func addPersistsAndProbesWhenEnabled() async throws {
        let mock = MockMCPClientService()
        mock.healthByServer["delta"] = .connected(toolCount: 1, responseTime: 0.01)

        var command = MCPCommand.Add()
        command.name = "delta"
        command.command = ["delta-cmd"]
        command.service = mock

        try await command.run(using: self.makeRuntime(json: false))

        #expect(mock.bootstrapCount == 1)
        #expect(mock.addCalls.count == 1)
        #expect(mock.persistCount == 1)
        #expect(mock.probes.contains("delta"))
    }

    @Test func addSkipsProbeWhenDisabled() async throws {
        let mock = MockMCPClientService()
        var command = MCPCommand.Add()
        command.name = "epsilon"
        command.command = ["epsilon-cmd"]
        command.disabled = true
        command.service = mock

        try await command.run(using: self.makeRuntime(json: false))

        #expect(!mock.probes.contains("epsilon"))
        #expect(mock.addCalls.count == 1)
    }

    @Test func enableCallsServiceAndHealthCheck() async throws {
        let mock = MockMCPClientService()
        mock.healthByServer["zeta"] = .connected(toolCount: 2, responseTime: 0.02)

        var command = MCPCommand.Enable()
        command.name = "zeta"
        command.service = mock

        try await command.run(using: self.makeRuntime(json: false))

        #expect(mock.enableCalls == ["zeta"])
        #expect(mock.probes.contains("zeta"))
    }

    @Test func disableCallsService() async throws {
        let mock = MockMCPClientService()
        var command = MCPCommand.Disable()
        command.name = "eta"
        command.service = mock

        try await command.run(using: self.makeRuntime(json: false))

        #expect(mock.disableCalls == ["eta"])
    }

    @Test func removeFailsWhenMissingServer() async throws {
        let mock = MockMCPClientService()
        var command = MCPCommand.Remove()
        command.name = "missing"
        command.force = true
        command.service = mock

        let error = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime(json: false))
        }
        #expect(error == .failure)
        #expect(mock.removeCalls.isEmpty)
    }

    @Test func addSurfacedServiceError() async throws {
        let mock = MockMCPClientService()
        mock.addShouldThrow = MCPCommandError.invalidArguments("boom")

        var command = MCPCommand.Add()
        command.name = "err"
        command.command = ["err-cmd"]
        command.service = mock

        let error = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime(json: false))
        }
        #expect(error == .failure)
        #expect(mock.addCalls.isEmpty)
        #expect(mock.persistCount == 0)
    }

    @Test func enableSurfacedServiceError() async throws {
        let mock = MockMCPClientService()
        mock.enableShouldThrow = MCPCommandError.invalidArguments("nope")

        var command = MCPCommand.Enable()
        command.name = "err-enable"
        command.service = mock

        let error = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime(json: false))
        }
        #expect(error == .failure)
        #expect(mock.enableCalls.isEmpty)
    }
}
