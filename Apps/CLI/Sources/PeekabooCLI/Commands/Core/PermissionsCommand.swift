import Commander
import Foundation
import PeekabooCore

@MainActor

struct PermissionsCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "permissions",
        abstract: "Check Peekaboo permissions",
        subcommands: [
            StatusSubcommand.self,
            GrantSubcommand.self,
        ],
        defaultSubcommand: StatusSubcommand.self
    )

    @MainActor

    struct StatusSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        var outputLogger: Logger { self.resolvedRuntime.logger }
        var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let permissions = await PermissionHelpers.getCurrentPermissions(services: runtime.services)
            if self.jsonOutput {
                outputSuccessCodable(data: permissions, logger: self.outputLogger)
            } else {
                permissions.forEach { print(PermissionHelpers.formatPermissionStatus($0)) }
            }
        }
    }

    @MainActor

    struct GrantSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        var outputLogger: Logger { self.resolvedRuntime.logger }
        var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            let permissions = await PermissionHelpers.getCurrentPermissions(services: runtime.services)
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
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
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
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
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
