import Commander
import PeekabooCore

extension ListCommand {
    @MainActor
    struct AppsSubcommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            // Tests read jsonOutput on parsed values before the runtime is injected.
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await requireScreenRecordingPermission(services: self.services)
                let output = try await self.services.applications.listApplications()

                if self.jsonOutput {
                    outputSuccessCodable(data: output.data, logger: self.outputLogger)
                } else {
                    print(CLIFormatter.format(output))
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }
    }
}

@MainActor
extension ListCommand.AppsSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "apps",
                abstract: "List all running applications with details",
                discussion: """
                Lists all running applications using the ApplicationService from PeekabooCore.
                Applications are sorted by name and include process IDs, bundle identifiers,
                and activation status.
                """
            )
        }
    }
}

extension ListCommand.AppsSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.AppsSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        // Apps has no parameters today; binding exists to keep Commander parity.
        _ = values
    }
}
