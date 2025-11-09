import AppKit
import ApplicationServices
@preconcurrency import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

/// Interact with the macOS Dock
@MainActor
struct DockCommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
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

    // MARK: - Launch from Dock

@MainActor
struct LaunchSubcommand: AsyncRuntimeCommand, OutputFormattable {
        static let mainActorConfiguration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application from the Dock"
        )

        @Argument(help: "Application name in the Dock")
        var app: String

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        mutating func run(using runtime: CommandRuntime) async throws {
            let services = runtime.services
            let logger = runtime.logger

            do {
                // Launch the app using the service
                try await services.dock.launchFromDock(appName: self.app)

                // Find the launched app's actual name using the service
                let dockItem = try await services.dock.findDockItem(name: self.app)

                // Output result
                if self.jsonOutput {
                    struct DockLaunchResult: Codable {
                        let action: String
                        let app: String
                    }

                    let outputData = DockLaunchResult(
                        action: "dock_launch",
                        app: dockItem.title
                    )
                    outputSuccessCodable(data: outputData, logger: logger)
                } else {
                    print("✓ Launched \(dockItem.title) from Dock")
                }

            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Right-Click Dock Item

@MainActor
struct RightClickSubcommand: AsyncRuntimeCommand, OutputFormattable {
        static let mainActorConfiguration = CommandConfiguration(
            commandName: "right-click",
            abstract: "Right-click a Dock item and optionally select from menu"
        )

        @Option(help: "Application name in the Dock")
        var app: String

        @Option(help: "Menu item to select after right-clicking")
        var select: String?

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        mutating func run(using runtime: CommandRuntime) async throws {
            let services = runtime.services
            let logger = runtime.logger

            do {
                // Find the dock item first to get its actual name
                let dockItem = try await services.dock.findDockItem(name: self.app)

                // Right-click the item using the service
                try await services.dock.rightClickDockItem(appName: self.app, menuItem: self.select)

                // Output result
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
                    outputSuccessCodable(data: outputData, logger: logger)
                } else {
                    if let selected = select {
                        print("✓ Right-clicked \(dockItem.title) and selected '\(selected)'")
                    } else {
                        print("✓ Right-clicked \(dockItem.title) in Dock")
                    }
                }

            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Hide Dock

    @MainActor
    struct HideSubcommand: ErrorHandlingCommand, OutputFormattable {
        static let mainActorConfiguration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide the Dock"
        )

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        mutating func run(using runtime: CommandRuntime) async throws {
            let services = runtime.services
            let logger = runtime.logger

            do {
                // Hide the Dock using the service
                try await services.dock.hideDock()

                // Output result
                if self.jsonOutput {
                    struct DockHideResult: Codable {
                        let action: String
                    }

                    let outputData = DockHideResult(action: "dock_hide")
                outputSuccessCodable(data: outputData, logger: logger)
                } else {
                    print("✓ Dock hidden")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Show Dock

    @MainActor
    struct ShowSubcommand: ErrorHandlingCommand, OutputFormattable {
        static let mainActorConfiguration = CommandConfiguration(
            commandName: "show",
            abstract: "Show the Dock"
        )

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        mutating func run(using runtime: CommandRuntime) async throws {
            let services = runtime.services
            let logger = runtime.logger

            do {
                try await services.dock.showDock()

                // Output result
                if self.jsonOutput {
                    struct DockShowResult: Codable {
                        let action: String
                    }

                    let outputData = DockShowResult(action: "dock_show")
                outputSuccessCodable(data: outputData, logger: logger)
                } else {
                    print("✓ Dock shown")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Dock Items

    @MainActor
    struct ListSubcommand: ErrorHandlingCommand, OutputFormattable {
        static let mainActorConfiguration = CommandConfiguration(
            commandName: "list",
            abstract: "List all Dock items"
        )

        @Flag(help: "Include separators and spacers")
        var includeAll = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        mutating func run(using runtime: CommandRuntime) async throws {
            let services = runtime.services
            let logger = runtime.logger

            do {
                let dockItems = try await services.dock.listDockItems(includeAll: self.includeAll)

                // Output result
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

                    let outputData = DockListResult(
                        dockItems: items,
                        count: items.count
                    )
                    outputSuccessCodable(data: outputData, logger: logger)
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
                handleDockServiceError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: logger)
                throw ExitCode(1)
            }
        }
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
        .INTERACTION_FAILED // Use existing error code
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
