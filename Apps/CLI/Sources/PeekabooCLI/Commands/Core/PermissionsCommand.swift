@preconcurrency import ArgumentParser
import Foundation
import PeekabooCore

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

    struct StatusSubcommand: OutputFormattable {
        @OptionGroup var runtimeOptions: CommandRuntimeOptions
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

    struct GrantSubcommand: OutputFormattable {
        @OptionGroup var runtimeOptions: CommandRuntimeOptions
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

extension PermissionsCommand.StatusSubcommand: @MainActor AsyncParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "status",
                abstract: "Show current permissions"
            )
        }
    }
}

extension PermissionsCommand.StatusSubcommand: @MainActor AsyncRuntimeCommand {}

extension PermissionsCommand.GrantSubcommand: @MainActor AsyncParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "grant",
                abstract: "Show grant instructions"
            )
        }
    }
}

extension PermissionsCommand.GrantSubcommand: @MainActor AsyncRuntimeCommand {}
