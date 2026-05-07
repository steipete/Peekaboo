import Commander
import PeekabooCore

extension DockCommand {
    // MARK: - Hide Dock

    @MainActor
    struct HideSubcommand: ErrorHandlingCommand, OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

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
            self.resolvedRuntime.configuration.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await DockServiceBridge.hideDock(dock: self.services.dock)
                AutomationEventLogger.log(.dock, "hide")

                if self.jsonOutput {
                    struct DockHideResult: Codable { let action: String }
                    outputSuccessCodable(data: DockHideResult(action: "dock_hide"), logger: self.outputLogger)
                } else {
                    print("✓ Dock hidden")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Show Dock

    @MainActor
    struct ShowSubcommand: ErrorHandlingCommand, OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

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
            self.resolvedRuntime.configuration.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await DockServiceBridge.showDock(dock: self.services.dock)
                AutomationEventLogger.log(.dock, "show")

                if self.jsonOutput {
                    struct DockShowResult: Codable { let action: String }
                    outputSuccessCodable(data: DockShowResult(action: "dock_show"), logger: self.outputLogger)
                } else {
                    print("✓ Dock shown")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }
}
