//
//  MCPCommand+Call.swift
//  PeekabooCLI
//

import Algorithms
import Commander
import Foundation
import Logging
import MCP
import PeekabooCore
import TachikomaMCP

extension MCPCommand {
    /// Call tool on MCP server
    @MainActor
    struct Call {
        static let commandDescription = CommandDescription(
            commandName: "call",
            abstract: "Call a tool on another MCP server",
            discussion: """
            Connect to another MCP server and execute a tool. This allows
            Peekaboo to consume services from other MCP servers.

            EXAMPLE:
              peekaboo mcp call claude-code edit_file --args '{"path": "main.swift"}'
            """
        )

        private static let connectionTimeoutSeconds: TimeInterval = 15

        @Argument(help: "MCP server to connect to")
        var server: String?

        @Argument(help: "Tool to call")
        var tool: String?

        @Option(help: "Tool arguments as JSON")
        var args: String = "{}"

        var service: any MCPClientService = DefaultMCPClientService.shared

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            let context = MCPCommandContext(runtime: runtime, service: self.service)

            do {
                guard let server = self.server, !server.isEmpty else {
                    throw MCPCommandError.invalidArguments("Specify the target MCP server via --server.")
                }
                guard let tool = self.tool, !tool.isEmpty else {
                    throw MCPCommandError.invalidArguments("Specify the MCP tool to call using --tool.")
                }

                let arguments = try MCPArgumentParsing.parseJSONObject(self.args)
                try await self.ensureServerReady(serverName: server, context: context)

                let response = try await context.service.execute(server: server, tool: tool, args: arguments)
                AutomationEventLogger.log(
                    .mcp,
                    "call server=\(server) tool=\(tool) error=\(response.isError)"
                )

                if context.wantsJSON {
                    MCPCallFormatter.outputJSON(
                        response: response,
                        serverName: server,
                        toolName: tool,
                        logger: context.logger
                    )
                } else {
                    MCPCallFormatter.outputHumanReadable(response: response, server: server, toolName: tool)
                }

                if response.isError {
                    throw ExitCode.failure
                }
            } catch let error as MCPCommandError {
                MCPCallFormatter.emitError(
                    message: error.localizedDescription,
                    code: error.errorCode,
                    wantsJSON: context.wantsJSON,
                    logger: context.logger
                )
                throw ExitCode.failure
            } catch let exit as ExitCode {
                throw exit
            } catch {
                MCPCallFormatter.emitError(
                    message: "Failed to call MCP tool: \(error.localizedDescription)",
                    code: .UNKNOWN_ERROR,
                    wantsJSON: context.wantsJSON,
                    logger: context.logger
                )
                throw ExitCode.failure
            }
        }

        private func ensureServerReady(serverName: String, context: MCPCommandContext) async throws {
            await context.service.bootstrap(connect: false)

            guard let info = await context.service.serverInfo(name: serverName) else {
                throw MCPCommandError.serverNotConfigured(serverName)
            }

            guard info.config.enabled else {
                throw MCPCommandError.serverDisabled(serverName)
            }

            let probe = await context.service.probe(
                name: serverName,
                timeoutMs: Int(Self.connectionTimeoutSeconds * 1000)
            )

            guard case .connected = probe else {
                let reason: String? = {
                    if case let .disconnected(error) = probe { return error }
                    return nil
                }()
                throw MCPCommandError.connectionFailed(server: serverName, reason: reason)
            }
        }
    }
}

@MainActor
extension MCPCommand.Call: ParsableCommand {}
extension MCPCommand.Call: AsyncRuntimeCommand {}

@MainActor
extension MCPCommand.Call: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.server = try values.requiredPositional(0, label: "server")
        self.tool = try values.requiredPositional(1, label: "tool")
        if let argsValue = values.singleOption("args") {
            self.args = argsValue
        }
    }
}
