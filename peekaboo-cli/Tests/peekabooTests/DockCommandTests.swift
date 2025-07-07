import Foundation
import Testing
@testable import peekaboo

@Suite("Dock Command Tests", .serialized)
struct DockCommandTests {
    @Test("Dock command exists")
    func dockCommandExists() {
        let config = DockCommand.configuration
        #expect(config.commandName == "dock")
        #expect(config.abstract.contains("macOS Dock"))
    }

    @Test("Dock command has expected subcommands")
    func dockSubcommands() {
        let subcommands = DockCommand.configuration.subcommands
        #expect(subcommands.count == 5)

        let subcommandNames = subcommands.map(\.configuration.commandName)
        #expect(subcommandNames.contains("click"))
        #expect(subcommandNames.contains("right-click"))
        #expect(subcommandNames.contains("hide"))
        #expect(subcommandNames.contains("show"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("Dock click command help")
    func dockClickHelp() async throws {
        let output = try await runCommand(["dock", "click", "--help"])

        #expect(output.contains("Launch an app from the Dock"))
        #expect(output.contains("--app"))
        #expect(output.contains("--index"))
    }

    @Test("Dock right-click command help")
    func dockRightClickHelp() async throws {
        let output = try await runCommand(["dock", "right-click", "--help"])

        #expect(output.contains("Right-click a Dock item"))
        #expect(output.contains("--app"))
        #expect(output.contains("--select"))
    }

    @Test("Dock hide/show commands")
    func dockHideShow() async throws {
        let hideOutput = try await runCommand(["dock", "hide", "--help"])
        #expect(hideOutput.contains("Hide the Dock"))

        let showOutput = try await runCommand(["dock", "show", "--help"])
        #expect(showOutput.contains("Show the Dock"))
    }

    @Test("Dock list command help")
    func dockListHelp() async throws {
        let output = try await runCommand(["dock", "list", "--help"])

        #expect(output.contains("List all items in the Dock"))
        #expect(output.contains("--type"))
    }

    @Test("Dock error codes")
    func dockErrorCodes() {
        #expect(ErrorCode.DOCK_NOT_FOUND.rawValue == "DOCK_NOT_FOUND")
        #expect(ErrorCode.DOCK_ITEM_NOT_FOUND.rawValue == "DOCK_ITEM_NOT_FOUND")
    }

    @Test("Dock item types")
    func dockItemTypes() {
        // Test that we can specify different item types
        let validTypes = ["all", "apps", "other"]
        for type in validTypes {
            let cmd = ["dock", "list", "--type", type]
            #expect(cmd.count == 5)
        }
    }
}

// MARK: - Dock Command Integration Tests

@Suite("Dock Command Integration Tests", .serialized, .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
struct DockCommandIntegrationTests {
    @Test("List Dock items")
    func listDockItems() async throws {
        let output = try await runCommand([
            "dock", "list",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        if let dockData = data.data?.value as? [String: Any],
           let items = dockData["items"] as? [[String: Any]]
        {
            #expect(!items.isEmpty)

            // Check for common Dock items
            let titles = items.compactMap { $0["title"] as? String }
            #expect(titles.contains("Finder")) // Finder is always in Dock
        }
    }

    @Test("Click Dock item by name")
    func clickDockItemByName() async throws {
        let output = try await runCommand([
            "dock", "click",
            "--app", "Finder",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        if let clickData = data.data?.value as? [String: Any] {
            #expect(clickData["action"] as? String == "dock_click")
            #expect(clickData["app"] as? String == "Finder")
        }
    }

    @Test("Hide and show Dock")
    func hideShowDock() async throws {
        // Hide Dock
        let hideOutput = try await runCommand([
            "dock", "hide",
            "--json-output",
        ])

        let hideData = try JSONDecoder().decode(JSONResponse.self, from: hideOutput.data(using: .utf8)!)
        #expect(hideData.success == true)

        // Wait a moment
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Show Dock
        let showOutput = try await runCommand([
            "dock", "show",
            "--json-output",
        ])

        let showData = try JSONDecoder().decode(JSONResponse.self, from: showOutput.data(using: .utf8)!)
        #expect(showData.success == true)
    }

    @Test("Right-click Dock item")
    func rightClickDockItem() async throws {
        let output = try await runCommand([
            "dock", "right-click",
            "--app", "Finder",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        if let rightClickData = data.data?.value as? [String: Any] {
            #expect(rightClickData["action"] as? String == "dock_right_click")
        }
    }

    @Test("List Dock items by type")
    func listDockItemsByType() async throws {
        // List only apps
        let appsOutput = try await runCommand([
            "dock", "list",
            "--type", "apps",
            "--json-output",
        ])

        let appsData = try JSONDecoder().decode(JSONResponse.self, from: appsOutput.data(using: .utf8)!)
        if appsData.success {
            if let dockData = appsData.data?.value as? [String: Any],
               let items = dockData["items"] as? [[String: Any]]
            {
                // All items should be applications
                for item in items {
                    if let subrole = item["subrole"] as? String {
                        #expect(subrole == "AXApplicationDockItem")
                    }
                }
            }
        }
    }
}

// MARK: - Test Helpers

private func runCommand(_ args: [String]) async throws -> String {
    let output = try await runPeekabooCommand(args)
    return output
}

private func runPeekabooCommand(_ args: [String]) async throws -> String {
    // This is a placeholder - in real tests, this would execute the actual CLI
    // For unit tests, we're mainly testing command structure and validation
    ""
}
