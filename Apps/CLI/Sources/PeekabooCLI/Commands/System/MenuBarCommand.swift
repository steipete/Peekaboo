import AXorcist
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Command for interacting with macOS menu bar items (status items).
@MainActor
struct MenuBarCommand: ParsableCommand, OutputFormattable {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "menubar",
                abstract: "Interact with macOS menu bar items (status items)",
                discussion: """
                The menubar command provides specialized support for interacting with menu bar items
                (also known as status items) on macOS. These are the icons that appear on the right
                side of the menu bar.

                FEATURES:
                  • Fuzzy matching - Partial text and case-insensitive search
                  • Index-based clicking - Use item number from list output
                  • Smart error messages - Shows available items when not found
                  • JSON output support - For scripting and automation

                EXAMPLES:
                  # List all menu bar items with indices
                  peekaboo menubar list
                  peekaboo menubar list --json-output      # JSON format

                  # Click by exact or partial name (case-insensitive)
                  peekaboo menubar click "Wi-Fi"           # Exact match
                  peekaboo menubar click "wi"              # Partial match
                  peekaboo menubar click "Bluetooth"       # Click Bluetooth icon

                  # Click by index from the list
                  peekaboo menubar click --index 3         # Click the 3rd item

                NOTE: Menu bar items are different from regular application menus. For application
                menus (File, Edit, etc.), use the 'menu' command instead.
                """
            )
        }
    }

    @Argument(help: "Action to perform (list or click)")
    var action: String

    @Argument(help: "Name of the menu bar item to click (for click action)")
    var itemName: String?

    @Option(help: "Index of the menu bar item (0-based)")
    var index: Int?
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }

    private var configuration: CommandRuntime.Configuration { self.resolvedRuntime.configuration }

    var jsonOutput: Bool { self.configuration.jsonOutput }
    private var isVerbose: Bool { self.configuration.verbose }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        switch self.action.lowercased() {
        case "list":
            try await self.listMenuBarItems()
        case "click":
            try await self.clickMenuBarItem()
        default:
            throw PeekabooError.invalidInput("Unknown action '\(self.action)'. Use 'list' or 'click'.")
        }
    }

    @MainActor
    private func listMenuBarItems() async throws {
        let startTime = Date()

        do {
            let menuBarItems = try await MenuServiceBridge.listMenuBarItems(menu: self.services.menu)

            if self.jsonOutput {
                let output = ListJSONOutput(
                    success: true,
                    menuBarItems: menuBarItems.map { item in
                        JSONMenuBarItem(
                            title: item.title,
                            raw_title: item.rawTitle,
                            bundle_id: item.bundleIdentifier,
                            owner_name: item.ownerName,
                            identifier: item.identifier,
                            index: item.index,
                            isVisible: item.isVisible,
                            description: item.description
                        )
                    },
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                if menuBarItems.isEmpty {
                    print("No menu bar items found.")
                } else {
                    print("📊 Menu Bar Items:")
                    for item in menuBarItems {
                        var info = "  [\(item.index)] \(item.title ?? "Untitled")"
                        if !item.isVisible {
                            info += " (hidden)"
                        }
                        if let desc = item.description, self.isVerbose {
                            info += " - \(desc)"
                        }
                        print(info)
                    }
                    print("\n💡 Tip: Use 'peekaboo menubar click \"name\"' to click a menu bar item")
                }
            }
        } catch {
            if self.jsonOutput {
                let output = JSONErrorOutput(
                    success: false,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                throw error
            }
        }
    }

    @MainActor
    private func clickMenuBarItem() async throws {
        let startTime = Date()

        do {
            let result: PeekabooCore.ClickResult
            if let idx = self.index {
                result = try await MenuServiceBridge.clickMenuBarItem(at: idx, menu: self.services.menu)
            } else if let name = self.itemName {
                result = try await MenuServiceBridge.clickMenuBarItem(named: name, menu: self.services.menu)
            } else {
                throw PeekabooError.invalidInput("Please provide either a menu bar item name or use --index")
            }

            if self.jsonOutput {
                let output = ClickJSONOutput(
                    success: true,
                    clicked: result.elementDescription,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                print("✅ Clicked menu bar item: \(result.elementDescription)")
                if self.isVerbose {
                    print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
                }
            }
        } catch {
            if self.jsonOutput {
                let output = JSONErrorOutput(
                    success: false,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                // Provide helpful hints for common errors
                if error.localizedDescription.contains("not found") {
                    print("❌ Error: \(error.localizedDescription)")
                    print("\n💡 Hints:")
                    print("  • Menu bar items often require clicking on their icon coordinates")
                    print("  • Try 'peekaboo see' first to get element IDs")
                    print("  • Use 'peekaboo menubar list' to see available items")
                } else {
                    throw error
                }
            }
        }
    }
}

// MARK: - JSON Output Types

private struct JSONMenuBarItem: Codable {
    let title: String?
    let raw_title: String?
    let bundle_id: String?
    let owner_name: String?
    let identifier: String?
    let index: Int
    let isVisible: Bool
    let description: String?
}

private struct ListJSONOutput: Codable {
    let success: Bool
    let menuBarItems: [JSONMenuBarItem]
    let executionTime: TimeInterval
}

private struct ClickJSONOutput: Codable {
    let success: Bool
    let clicked: String
    let executionTime: TimeInterval
}

private struct JSONErrorOutput: Codable {
    let success: Bool
    let error: String
    let executionTime: TimeInterval
}

extension MenuBarCommand: AsyncRuntimeCommand {}

@MainActor
extension MenuBarCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.action = try values.decodePositional(0, label: "action")
        self.itemName = try values.decodeOptionalPositional(1, label: "itemName")
        self.index = try values.decodeOption("index", as: Int.self)
    }
}
