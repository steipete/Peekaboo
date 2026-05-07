import Commander
import PeekabooCore

extension DockCommand {
    // MARK: - Right-Click Dock Item

    @MainActor
    struct RightClickSubcommand: OutputFormattable {
        @Option(help: "Application name in the Dock")
        var app: String

        @Option(help: "Menu item to select after right-clicking")
        var select: String?
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
                let dockItem = try await DockServiceBridge.findDockItem(dock: self.services.dock, name: self.app)
                try await DockServiceBridge.rightClickDockItem(
                    dock: self.services.dock,
                    appName: self.app,
                    menuItem: self.select
                )
                let selectionDescription = self.select ?? "context-only"
                AutomationEventLogger.log(.dock, "right_click app=\(dockItem.title) selection=\(selectionDescription)")

                if self.jsonOutput {
                    struct DockRightClickResult: Codable {
                        let action: String
                        let app: String
                        let selectedItem: String
                    }

                    let outputData = DockRightClickResult(
                        action: "dock_right_click",
                        app: dockItem.title,
                        selectedItem: self.select ?? ""
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else if let selected = self.select {
                    print("✓ Right-clicked \(dockItem.title) and selected '\(selected)'")
                } else {
                    print("✓ Right-clicked \(dockItem.title) in Dock")
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
