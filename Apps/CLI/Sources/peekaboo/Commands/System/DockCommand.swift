import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

/// Interact with the macOS Dock
struct DockCommand: AsyncParsableCommand {
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
        ])

    // MARK: - Launch from Dock

    struct LaunchSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application from the Dock")

        @Argument(help: "Application name in the Dock")
        var app: String

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        private var services: PeekabooServices { PeekabooServices.shared }

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Launch the app using the service
                try await self.services.dock.launchFromDock(appName: self.app)

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
                    outputSuccessCodable(data: outputData)
                } else {
                    print("✓ Launched \(dockItem.title) from Dock")
                }

            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Right-Click Dock Item

    struct RightClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "right-click",
            abstract: "Right-click a Dock item and optionally select from menu")

        @Option(help: "Application name in the Dock")
        var app: String

        @Option(help: "Menu item to select after right-clicking")
        var select: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        private var services: PeekabooServices { PeekabooServices.shared }

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Find the dock item first to get its actual name
                let dockItem = try await services.dock.findDockItem(name: self.app)

                // Right-click the item using the service
                try await self.services.dock.rightClickDockItem(appName: self.app, menuItem: self.select)

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
                    outputSuccessCodable(data: outputData)
                } else {
                    if let selected = select {
                        print("✓ Right-clicked \(dockItem.title) and selected '\(selected)'")
                    } else {
                        print("✓ Right-clicked \(dockItem.title) in Dock")
                    }
                }

            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Hide Dock

    struct HideSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide the Dock")

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        private var services: PeekabooServices { PeekabooServices.shared }

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Hide the Dock using the service
                try await self.services.dock.hideDock()

                // Output result
                if self.jsonOutput {
                    struct DockHideResult: Codable {
                        let action: String
                    }
                    
                    let outputData = DockHideResult(action: "dock_hide")
                    outputSuccessCodable(data: outputData)
                } else {
                    print("✓ Dock hidden")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Show Dock

    struct ShowSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show the Dock")

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        private var services: PeekabooServices { PeekabooServices.shared }

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Show the Dock using the service
                try await self.services.dock.showDock()

                // Output result
                if self.jsonOutput {
                    struct DockShowResult: Codable {
                        let action: String
                    }
                    
                    let outputData = DockShowResult(action: "dock_show")
                    outputSuccessCodable(data: outputData)
                } else {
                    print("✓ Dock shown")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Dock Items

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all Dock items")

        @Flag(help: "Include separators and spacers")
        var includeAll = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        private var services: PeekabooServices { PeekabooServices.shared }

        @MainActor
        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Get Dock items using the service
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
                    outputSuccessCodable(data: outputData)
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
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - Error Handling

private func handleDockServiceError(_ error: DockError, jsonOutput: Bool) {
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
                code: errorCode))
        outputJSON(response)
    } else {
        fputs("❌ \(error.localizedDescription)\n", stderr)
    }
}
