import Commander
import Foundation
import PeekabooCore

@MainActor

struct PermissionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check Peekaboo permissions",
        subcommands: [
            StatusSubcommand.self,
            GrantSubcommand.self,
        ],
        defaultSubcommand: StatusSubcommand.self
    )

    @MainActor

    struct StatusSubcommand: OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        var outputLogger: Logger { self.resolvedRuntime.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let permissions = await PermissionHelpers.getCurrentPermissions()
            if self.jsonOutput {
                outputSuccessCodable(data: permissions, logger: self.outputLogger)
            } else {
                permissions.forEach { print(PermissionHelpers.formatPermissionStatus($0)) }
            }
        }
    }

    @MainActor

    struct GrantSubcommand: OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        var outputLogger: Logger { self.resolvedRuntime.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            let permissions = await PermissionHelpers.getCurrentPermissions()
            if self.jsonOutput {
                outputSuccessCodable(data: permissions, logger: self.outputLogger)
            } else {
                print("Grant the following permissions in System Settings:")
                for permission in permissions {
                    print("• \(permission.name): \(permission.grantInstructions)")
                }
            }
        }
    }
}

@MainActor
extension PermissionsCommand.StatusSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "status",
                abstract: "Show current permissions"
            )
        }
    }
}

extension PermissionsCommand.StatusSubcommand: AsyncRuntimeCommand {}

@MainActor
extension PermissionsCommand.StatusSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

@MainActor
extension PermissionsCommand.GrantSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "grant",
                abstract: "Show grant instructions"
            )
        }
    }
}

extension PermissionsCommand.GrantSubcommand: AsyncRuntimeCommand {}

@MainActor
extension PermissionsCommand.GrantSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}
