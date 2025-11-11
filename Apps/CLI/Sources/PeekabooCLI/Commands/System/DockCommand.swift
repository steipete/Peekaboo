import AppKit
import ApplicationServices
import AXorcist
import Commander
import Foundation
import PeekabooCore

/// Interact with the macOS Dock
@MainActor
struct DockCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "dock",
                abstract: "Interact with the macOS Dock",
                discussion: """

                EXAMPLES:
                  # Launch an app from the Dock
                  peekaboo dock launch Safari

                  # Right-click a Dock item
                  peekaboo dock right-click --app Finder --select "New Window"

                  # Show/hide the Dock
                  peekaboo dock hide
                  peekaboo dock show

                  # List all Dock items
                  peekaboo dock list
                """,
                subcommands: [
                    LaunchSubcommand.self,
                    RightClickSubcommand.self,
                    HideSubcommand.self,
                    ShowSubcommand.self,
                    ListSubcommand.self,
                ]
            )
        }
    }
}

extension DockCommand {
    // MARK: - Launch from Dock

    @MainActor

    struct LaunchSubcommand: OutputFormattable {
        @Argument(help: "Application name in the Dock")
        var app: String
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await DockServiceBridge.launchFromDock(services: self.services, appName: self.app)
                let dockItem = try await DockServiceBridge.findDockItem(services: self.services, name: self.app)

                if self.jsonOutput {
                    struct DockLaunchResult: Codable {
                        let action: String
                        let app: String
                    }

                    let outputData = DockLaunchResult(action: "dock_launch", app: dockItem.title)
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("✓ Launched \(dockItem.title) from Dock")
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

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let dockItem = try await DockServiceBridge.findDockItem(services: self.services, name: self.app)
                try await DockServiceBridge.rightClickDockItem(
                    services: self.services,
                    appName: self.app,
                    menuItem: self.select
                )

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

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await DockServiceBridge.hideDock(services: self.services)

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

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await DockServiceBridge.showDock(services: self.services)

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

    // MARK: - List Dock Items

    @MainActor

    struct ListSubcommand: ErrorHandlingCommand, OutputFormattable {
        @Flag(help: "Include separators and spacers")
        var includeAll = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let dockItems = try await DockServiceBridge.listDockItems(
                    services: self.services,
                    includeAll: self.includeAll
                )

                if self.jsonOutput {
                    struct DockListResult: Codable {
                        let dockItems: [DockItemInfo]
                        let count: Int

                        struct DockItemInfo: Codable {
                            let index: Int
                            let title: String
                            let type: String
                            let running: Bool?
                            let bundleId: String?
                        }
                    }

                    let items = dockItems.map { item in
                        DockListResult.DockItemInfo(
                            index: item.index,
                            title: item.title,
                            type: item.itemType.rawValue,
                            running: item.isRunning,
                            bundleId: item.bundleIdentifier
                        )
                    }

                    let outputData = DockListResult(dockItems: items, count: items.count)
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("Dock items:")
                    for item in dockItems {
                        let runningIndicator = (item.isRunning == true) ? " •" : ""
                        let typeIndicator = item.itemType != .application ? " (\(item.itemType.rawValue))" : ""
                        print("  [\(item.index)] \(item.title)\(typeIndicator)\(runningIndicator)")
                    }
                    print("\nTotal: \(dockItems.count) items")
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

// MARK: - Subcommand Conformances

@MainActor
extension DockCommand.LaunchSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(commandName: "launch", abstract: "Launch an application from the Dock")
        }
    }
}

extension DockCommand.LaunchSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DockCommand.LaunchSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.decodePositional(0, label: "app")
    }
}

@MainActor
extension DockCommand.RightClickSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "right-click",
                abstract: "Right-click a Dock item and optionally select from menu"
            )
        }
    }
}

extension DockCommand.RightClickSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DockCommand.RightClickSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.requireOption("app", as: String.self)
        self.select = values.singleOption("select")
    }
}

@MainActor
extension DockCommand.HideSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(commandName: "hide", abstract: "Hide the Dock")
        }
    }
}

extension DockCommand.HideSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DockCommand.HideSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

@MainActor
extension DockCommand.ShowSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(commandName: "show", abstract: "Show the Dock")
        }
    }
}

extension DockCommand.ShowSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DockCommand.ShowSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

@MainActor
extension DockCommand.ListSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(commandName: "list", abstract: "List all Dock items")
        }
    }
}

extension DockCommand.ListSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DockCommand.ListSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.includeAll = values.flag("includeAll")
    }
}

// MARK: - Error Handling

private func handleDockServiceError(_ error: DockError, jsonOutput: Bool, logger: Logger) {
    let errorCode: ErrorCode = switch error {
    case .dockNotFound:
        .DOCK_NOT_FOUND
    case .dockListNotFound:
        .DOCK_LIST_NOT_FOUND
    case .itemNotFound:
        .DOCK_ITEM_NOT_FOUND
    case .menuItemNotFound:
        .MENU_ITEM_NOT_FOUND
    case .positionNotFound:
        .POSITION_NOT_FOUND
    case .launchFailed:
        .INTERACTION_FAILED
    case .scriptError:
        .SCRIPT_ERROR
    }

    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: errorCode
            )
        )
        outputJSON(response, logger: logger)
    } else {
        fputs("❌ \(error.localizedDescription)\n", stderr)
    }
}
