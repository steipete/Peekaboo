import Commander
import Foundation
import PeekabooCore

/// Check Peekaboo permissions.
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

    func run() async throws {
        // Root command doesn’t do anything; subcommands handle the work.
    }
}

extension PermissionsCommand {
    @MainActor
    struct StatusSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        @Flag(name: .customLong("no-remote"), help: "Skip remote hosts and query permissions locally")
        var noRemote = false

        @Option(
            name: .customLong("bridge-socket"),
            help: "Override the Peekaboo Bridge socket path for permission checks"
        )
        var bridgeSocket: String?

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

            let response = await PermissionHelpers.getCurrentPermissionsWithSource(
                services: runtime.services,
                allowRemote: !self.noRemote,
                socketPath: self.bridgeSocket
            )

            if self.jsonOutput {
                outputSuccessCodable(data: response, logger: self.outputLogger)
            } else {
                let sourceLabel = response.source == "bridge" ? "Peekaboo Bridge" : "local runtime"
                print("Source: \(sourceLabel)")
                response.permissions.forEach { print(PermissionHelpers.formatPermissionStatus($0)) }
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

// MARK: - Subcommand Conformances

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
        self.noRemote = values.flag("no-remote")
        self.bridgeSocket = values.singleOption("bridge-socket")
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
