//
//  MCPCommand+Admin.swift
//  PeekabooCLI
//

import Commander
import Foundation
import Logging
import PeekabooCore
import TachikomaMCP

extension MCPCommand {
    /// Remove an MCP server
    @MainActor
    struct Remove {
        static let commandDescription = CommandDescription(
            commandName: "remove",
            abstract: "Remove an external MCP server",
            discussion: "Remove a configured MCP server and disconnect from it."
        )

        @Argument(help: "Name of the MCP server to remove")
        var name: String

        @Flag(help: "Skip confirmation prompt")
        var force = false
        var service: any MCPClientService = DefaultMCPClientService.shared

        /// Disconnect and delete the specified server configuration, prompting unless forced.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)
            await context.service.bootstrap(connect: false)

            guard await context.service.serverInfo(name: self.name) != nil else {
                context.logger.error("MCP server '\(self.name)' not found")
                throw ExitCode.failure
            }

            if !self.force {
                print("Remove MCP server '\(self.name)'? (y/N): ", terminator: "")
                let response = readLine() ?? ""
                if !["y", "yes"].contains(response.lowercased()) {
                    print("Cancelled.")
                    return
                }
            }

            await context.service.removeServer(name: self.name)
            print("✓ Removed MCP server '\(self.name)'")
        }
    }

    /// Test connection to an MCP server
    @MainActor
    struct Test {
        static let commandDescription = CommandDescription(
            commandName: "test",
            abstract: "Test connection to an MCP server",
            discussion: "Test connectivity and list available tools from an MCP server."
        )

        @Argument(help: "Name of the MCP server to test")
        var name: String

        @Option(help: "Connection timeout in seconds")
        var timeout: Double = 10.0

        @Flag(help: "Show available tools")
        var showTools = false
        var service: any MCPClientService = DefaultMCPClientService.shared

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)
            await context.service.bootstrap(connect: true)

            print("Testing connection to MCP server '\(self.name)'...")

            let health = await context.service.checkServerHealth(name: self.name, timeoutMs: Int(self.timeout * 1000))

            print("\(health.symbol) \(health.statusText)")

            if health.isHealthy && self.showTools {
                let externalTools = await context.service.externalToolsByServer()
                if let serverTools = externalTools[name] {
                    print("\nAvailable tools (\(serverTools.count)):")
                    for tool in serverTools.sorted(by: { $0.name < $1.name }) {
                        print("  \(tool.name) - \(tool.description ?? "")")
                    }
                }
            }
        }
    }

    /// Show detailed information about an MCP server
    @MainActor
    struct Info {
        static let commandDescription = CommandDescription(
            commandName: "info",
            abstract: "Show detailed information about an MCP server",
            discussion: "Display comprehensive information about a configured MCP server."
        )

        @Argument(help: "Name of the MCP server")
        var name: String
        var service: any MCPClientService = DefaultMCPClientService.shared

        /// Print configuration and live health details for the specified server in text or JSON form.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)
            await context.service.bootstrap(connect: false)

            guard let serverInfo = await context.service.serverInfo(name: self.name) else {
                context.logger.error("MCP server '\(self.name)' not found")
                throw ExitCode.failure
            }

            let health = await context.service.checkServerHealth(name: self.name, timeoutMs: 5000)

            if context.wantsJSON {
                var output: [String: Any] = [
                    "name": serverInfo.name,
                    "command": serverInfo.config.command,
                    "args": serverInfo.config.args,
                    "transport": serverInfo.config.transport,
                    "enabled": serverInfo.config.enabled,
                    "timeout": serverInfo.config.timeout,
                    "autoReconnect": serverInfo.config.autoReconnect,
                    "env": serverInfo.config.env,
                    "connected": serverInfo.connected,
                ]

                if let description = serverInfo.config.description {
                    output["description"] = description
                }

                output["health"] = [
                    "status": health.isHealthy ? "connected" : "disconnected",
                    "details": health.statusText
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                print("Server: \(serverInfo.name)")
                print("Command: \(serverInfo.config.command) \(serverInfo.config.args.joined(separator: " "))")
                print("Transport: \(serverInfo.config.transport)")
                print("Enabled: \(serverInfo.config.enabled ? "Yes" : "No")")
                print("Timeout: \(serverInfo.config.timeout)s")
                print("Auto-reconnect: \(serverInfo.config.autoReconnect ? "Yes" : "No")")

                if !serverInfo.config.env.isEmpty {
                    print("Environment:")
                    for (key, value) in serverInfo.config.env.sorted(by: { $0.key < $1.key }) {
                        print("  \(key)=\(value)")
                    }
                }

                if let description = serverInfo.config.description {
                    print("Description: \(description)")
                }

                print("\nHealth: \(health.symbol) \(health.statusText)")
            }
        }
    }

    /// Enable an MCP server
    @MainActor
    struct Enable {
        static let commandDescription = CommandDescription(
            commandName: "enable",
            abstract: "Enable a disabled MCP server",
            discussion: "Enable a previously disabled MCP server and attempt to connect."
        )

        @Argument(help: "Name of the MCP server to enable")
        var name: String
        var service: any MCPClientService = DefaultMCPClientService.shared

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)
            await context.service.bootstrap(connect: false)

            do {
                try await context.service.enableServer(name: self.name)
                print("✓ Enabled MCP server '\(self.name)'")

                print("Testing connection...")
                let health = await context.service.checkServerHealth(name: self.name, timeoutMs: 5000)
                print("\(health.symbol) \(health.statusText)")
            } catch {
                context.logger.error("Failed to enable MCP server: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }

    /// Disable an MCP server
    @MainActor
    struct Disable {
        static let commandDescription = CommandDescription(
            commandName: "disable",
            abstract: "Disable an MCP server",
            discussion: "Disable an MCP server without removing its configuration."
        )

        @Argument(help: "Name of the MCP server to disable")
        var name: String
        var service: any MCPClientService = DefaultMCPClientService.shared

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)
            await context.service.bootstrap(connect: false)

            await context.service.disableServer(name: self.name)
            print("✓ Disabled MCP server '\(self.name)'")
        }
    }

    /// Inspect MCP connection
    @MainActor
    struct Inspect {
        static let commandDescription = CommandDescription(
            commandName: "inspect",
            abstract: "Debug MCP connections",
            discussion: "Provides debugging information for MCP connections."
        )

        @Argument(help: "Server to inspect")
        var server: String?
        var service: any MCPClientService = DefaultMCPClientService.shared

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)
            context.logger.error("MCP inspection not yet implemented")
            throw ExitCode.failure
        }
    }
}

@MainActor
extension MCPCommand.Remove: ParsableCommand {}
extension MCPCommand.Remove: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Test: ParsableCommand {}
extension MCPCommand.Test: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Info: ParsableCommand {}
extension MCPCommand.Info: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Enable: ParsableCommand {}
extension MCPCommand.Enable: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Disable: ParsableCommand {}
extension MCPCommand.Disable: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Inspect: ParsableCommand {}
extension MCPCommand.Inspect: AsyncRuntimeCommand {}

extension MCPCommand.Inspect: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.server = try values.decodeOptionalPositional(0, label: "server")
    }
}
