import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

/// Refactored DockCommand using PeekabooCore services
///
/// This version delegates Dock interactions to the service layer
/// while maintaining the same command interface and JSON output compatibility.
struct DockCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dock-v2",
        abstract: "Interact with the macOS Dock using PeekabooCore services",
        discussion: """
        This is a refactored version of the dock command that uses PeekabooCore services
        instead of direct implementation. It maintains the same interface but delegates
        Dock interactions to the service layer.

        EXAMPLES:
          # Launch an app from the Dock
          peekaboo dock-v2 launch Safari

          # Right-click a Dock item
          peekaboo dock-v2 right-click --app Finder --select "New Window"

          # Show/hide the Dock
          peekaboo dock-v2 hide
          peekaboo dock-v2 show

          # List all Dock items
          peekaboo dock-v2 list
        """,
        subcommands: [
            LaunchSubcommandV2.self,
            RightClickSubcommandV2.self,
            HideSubcommandV2.self,
            ShowSubcommandV2.self,
            ListSubcommandV2.self,
        ])

    // MARK: - Launch from Dock

    struct LaunchSubcommandV2: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application from the Dock")

        @Argument(help: "Application name in the Dock")
        var app: String

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private var services: PeekabooServices { PeekabooServices.shared }

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Launch the app using the service
                try await services.dock.launchFromDock(appName: app)

                // Find the launched app's actual name using the service
                let dockItem = try await services.dock.findDockItem(name: app)

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_launch",
                            "app": dockItem.title,
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Launched \(dockItem.title) from Dock")
                }

            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Right-Click Dock Item

    struct RightClickSubcommandV2: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "right-click",
            abstract: "Right-click a Dock item and optionally select from menu")

        @Option(help: "Application name in the Dock")
        var app: String

        @Option(help: "Menu item to select after right-clicking")
        var select: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private var services: PeekabooServices { PeekabooServices.shared }

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Find the dock item first to get its actual name
                let dockItem = try await services.dock.findDockItem(name: app)

                // Right-click the item using the service
                try await services.dock.rightClickDockItem(appName: app, menuItem: select)

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_right_click",
                            "app": dockItem.title,
                            "selected_item": select,
                        ]))
                    outputJSON(response)
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
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Hide Dock

    struct HideSubcommandV2: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide the Dock")

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private var services: PeekabooServices { PeekabooServices.shared }

        func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Hide the Dock using the service
                try await services.dock.hideDock()

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_hide",
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Dock hidden")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Show Dock

    struct ShowSubcommandV2: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show the Dock")

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private var services: PeekabooServices { PeekabooServices.shared }

        func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Show the Dock using the service
                try await services.dock.showDock()

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_show",
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Dock shown")
                }
            } catch let error as DockError {
                handleDockServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Dock Items

    struct ListSubcommandV2: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all Dock items")

        @Flag(help: "Include separators and spacers")
        var includeAll = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private var services: PeekabooServices { PeekabooServices.shared }

        @MainActor
        func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Get Dock items using the service
                let dockItems = try await services.dock.listDockItems(includeAll: includeAll)

                // Convert to output format
                let itemsData = dockItems.map { item -> [String: Any] in
                    var data: [String: Any] = [
                        "index": item.index,
                        "title": item.title,
                        "type": item.itemType.rawValue,
                    ]
                    
                    if let isRunning = item.isRunning {
                        data["running"] = isRunning
                    }
                    
                    if let bundleId = item.bundleIdentifier {
                        data["bundle_id"] = bundleId
                    }
                    
                    return data
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "dock_items": itemsData,
                            "count": itemsData.count,
                        ]))
                    outputJSON(response)
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
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - Error Handling

private func handleDockServiceError(_ error: DockError, jsonOutput: Bool) {
    let errorCode: ErrorCode
    switch error {
    case .dockNotFound:
        errorCode = .DOCK_NOT_FOUND
    case .dockListNotFound:
        errorCode = .DOCK_LIST_NOT_FOUND
    case .itemNotFound(_):
        errorCode = .DOCK_ITEM_NOT_FOUND
    case .menuItemNotFound(_):
        errorCode = .MENU_ITEM_NOT_FOUND
    case .positionNotFound:
        errorCode = .POSITION_NOT_FOUND
    case .launchFailed(_):
        errorCode = .INTERACTION_FAILED  // Use existing error code
    case .scriptError(_):
        errorCode = .SCRIPT_ERROR
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