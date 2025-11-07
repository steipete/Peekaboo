@preconcurrency import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Command for interacting with macOS menu bar items (status items).
@MainActor
struct MenuBarCommand: @MainActor MainActorAsyncParsableCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
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

    @Argument(help: "Action to perform (list or click)")
    var action: String

    @Argument(help: "Name of the menu bar item to click (for click action)")
    var itemName: String?

    @Option(help: "Index of the menu bar item (0-based)")
    var index: Int?

    @Flag(name: .shortAndLong, help: "Output results as JSON")
    var jsonOutput = false

    @Flag(name: .shortAndLong, help: "Show more detailed output")
    var verbose = false

    func run() async throws {
        switch self.action.lowercased() {
        case "list":
            try await self.listMenuBarItems()
        case "click":
            try await self.clickMenuBarItem()
        default:
            throw PeekabooError.invalidInput("Unknown action '\(self.action)'. Use 'list' or 'click'.")
        }
    }

    private func listMenuBarItems() async throws {
        let startTime = Date()

        do {
            let menuBarItems = try await PeekabooServices.shared.menu.listMenuBarItems()

            if self.jsonOutput {
                let output = ListJSONOutput(
                    success: true,
                    menuBarItems: menuBarItems.map { item in
                        JSONMenuBarItem(
                            title: item.title,
                            index: item.index,
                            isVisible: item.isVisible,
                            description: item.description
                        )
                    },
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
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
                        if let desc = item.description, verbose {
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
                outputSuccessCodable(data: output)
            } else {
                throw error
            }
        }
    }

    private func clickMenuBarItem() async throws {
        let startTime = Date()

        do {
            let result: PeekabooCore.ClickResult

            if let idx = self.index {
                result = try await PeekabooServices.shared.menu.clickMenuBarItem(at: idx)
            } else if let name = self.itemName {
                result = try await PeekabooServices.shared.menu.clickMenuBarItem(named: name)
            } else {
                throw PeekabooError.invalidInput("Please provide either a menu bar item name or use --index")
            }

            if self.jsonOutput {
                let output = ClickJSONOutput(
                    success: true,
                    clicked: result.elementDescription,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Clicked menu bar item: \(result.elementDescription)")
                if self.verbose {
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
                outputSuccessCodable(data: output)
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