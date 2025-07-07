import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation

struct DockCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dock",
        abstract: "Interact with the macOS Dock",
        discussion: """
        Control Dock applications, folders, and settings.

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
            ListSubcommand.self
        ]
    )

    // MARK: - Launch from Dock

    struct LaunchSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application from the Dock"
        )

        @Argument(help: "Application name in the Dock")
        var app: String

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Find Dock application
                guard let dock = findDockApplication() else {
                    throw DockError.dockNotFound
                }

                // Get Dock items
                guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
                    throw DockError.dockListNotFound
                }

                // Find the target app
                let dockItems = dockList.children() ?? []
                guard let targetItem = dockItems.first(where: { item in
                    item.title() == app ||
                        item.title()?.contains(app) == true
                }) else {
                    throw DockError.itemNotFound(app)
                }

                // Click the item
                try targetItem.performAction(.press)

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_launch",
                            "app": targetItem.title() ?? app
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("✓ Launched \(targetItem.title() ?? app) from Dock")
                }

            } catch let error as DockError {
                handleDockError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Right-Click Dock Item

    struct RightClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "right-click",
            abstract: "Right-click a Dock item and optionally select from menu"
        )

        @Option(help: "Application name in the Dock")
        var app: String

        @Option(help: "Menu item to select after right-clicking")
        var select: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Find Dock application
                guard let dock = findDockApplication() else {
                    throw DockError.dockNotFound
                }

                // Get Dock items
                guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
                    throw DockError.dockListNotFound
                }

                // Find the target app
                let dockItems = dockList.children() ?? []
                guard let targetItem = dockItems.first(where: { item in
                    item.title() == app ||
                        item.title()?.contains(app) == true
                }) else {
                    throw DockError.itemNotFound(app)
                }

                // Get item position
                guard let position = targetItem.position(),
                      let size = targetItem.size() else {
                    throw DockError.positionNotFound
                }

                let center = CGPoint(
                    x: position.x + size.width / 2,
                    y: position.y + size.height / 2
                )

                // Perform right-click
                let rightMouseDown = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .rightMouseDown,
                    mouseCursorPosition: center,
                    mouseButton: .right
                )

                let rightMouseUp = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .rightMouseUp,
                    mouseCursorPosition: center,
                    mouseButton: .right
                )

                rightMouseDown?.post(tap: .cghidEventTap)
                usleep(50000) // 50ms
                rightMouseUp?.post(tap: .cghidEventTap)

                // If menu item specified, click it
                if let menuItem = select {
                    // Wait for context menu
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms

                    // Find the menu
                    if let menu = targetItem.children()?.first(where: { $0.role() == "AXMenu" }) {
                        let menuItems = menu.children() ?? []
                        guard let targetMenuItem = menuItems.first(where: { item in
                            item.title() == menuItem ||
                                item.title()?.contains(menuItem) == true
                        }) else {
                            throw DockError.menuItemNotFound(menuItem)
                        }

                        try targetMenuItem.performAction(.press)
                    }
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_right_click",
                            "app": targetItem.title() ?? app,
                            "selected_item": select
                        ])
                    )
                    outputJSON(response)
                } else {
                    if let selected = select {
                        print("✓ Right-clicked \(app) and selected '\(selected)'")
                    } else {
                        print("✓ Right-clicked \(app) in Dock")
                    }
                }

            } catch let error as DockError {
                handleDockError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Hide Dock

    struct HideSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide the Dock"
        )

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            // Use AppleScript to hide Dock (more reliable than AX)
            let script = "tell application \"System Events\" to set autohide of dock preferences to true"

            do {
                try await runAppleScript(script)

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_hide"
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("✓ Dock hidden")
                }
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Show Dock

    struct ShowSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show the Dock"
        )

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            // Use AppleScript to show Dock
            let script = "tell application \"System Events\" to set autohide of dock preferences to false"

            do {
                try await runAppleScript(script)

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dock_show"
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("✓ Dock shown")
                }
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - List Dock Items

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all Dock items"
        )

        @Flag(help: "Include separators and spacers")
        var includeAll = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        func run() async throws {
            do {
                // Find Dock application
                guard let dock = findDockApplication() else {
                    throw DockError.dockNotFound
                }

                // Get Dock items
                guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
                    throw DockError.dockListNotFound
                }

                let dockItems = dockList.children() ?? []

                // Collect item information
                var itemsData: [[String: Any]] = []

                for (index, item) in dockItems.enumerated() {
                    let role = item.role() ?? ""
                    let title = item.title() ?? ""
                    let subrole = item.subrole() ?? ""

                    // Skip separators unless includeAll
                    if !includeAll && (role == "AXSeparator" || subrole == "AXSeparator") {
                        continue
                    }

                    var itemData: [String: Any] = [
                        "index": index,
                        "title": title,
                        "role": role
                    ]

                    if !subrole.isEmpty {
                        itemData["subrole"] = subrole
                    }

                    // Check if running
                    if let isRunning = item.attribute(Attribute<Bool>("AXIsApplicationRunning")) {
                        itemData["running"] = isRunning
                    }

                    itemsData.append(itemData)
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "dock_items": itemsData,
                            "count": itemsData.count
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("Dock items:")
                    for item in itemsData {
                        let title = item["title"] as? String ?? "Untitled"
                        let index = item["index"] as? Int ?? 0
                        let running = item["running"] as? Bool ?? false

                        let runningIndicator = running ? " •" : ""
                        print("  [\(index)] \(title)\(runningIndicator)")
                    }
                    print("\nTotal: \(itemsData.count) items")
                }

            } catch let error as DockError {
                handleDockError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }
}

// MARK: - Helper Functions

@MainActor
private func findDockApplication() -> Element? {
    let workspace = NSWorkspace.shared
    guard let dockApp = workspace.runningApplications.first(where: {
        $0.bundleIdentifier == "com.apple.dock"
    }) else {
        return nil
    }

    return Element(AXUIElementCreateApplication(dockApp.processIdentifier))
}

private func runAppleScript(_ script: String) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let error = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw DockError.scriptError(error)
    }
}

// MARK: - Dock Errors

enum DockError: LocalizedError {
    case dockNotFound
    case dockListNotFound
    case itemNotFound(String)
    case menuItemNotFound(String)
    case positionNotFound
    case scriptError(String)

    var errorDescription: String? {
        switch self {
        case .dockNotFound:
            "Dock application not found"
        case .dockListNotFound:
            "Dock item list not found"
        case let .itemNotFound(item):
            "Dock item '\(item)' not found"
        case let .menuItemNotFound(item):
            "Menu item '\(item)' not found"
        case .positionNotFound:
            "Could not determine Dock item position"
        case let .scriptError(error):
            "Script error: \(error)"
        }
    }

    var errorCode: String {
        switch self {
        case .dockNotFound:
            "DOCK_NOT_FOUND"
        case .dockListNotFound:
            "DOCK_LIST_NOT_FOUND"
        case .itemNotFound:
            "DOCK_ITEM_NOT_FOUND"
        case .menuItemNotFound:
            "MENU_ITEM_NOT_FOUND"
        case .positionNotFound:
            "POSITION_NOT_FOUND"
        case .scriptError:
            "SCRIPT_ERROR"
        }
    }
}

// MARK: - Error Handling

private func handleDockError(_ error: DockError, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR
            )
        )
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}
