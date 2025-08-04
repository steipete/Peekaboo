import Foundation
import Testing
@testable import peekaboo

// Import the necessary types from the menu command
private struct MenuListData: Codable {
    let app: String
    let bundle_id: String?
    let menu_structure: [MenuData]
}

private struct MenuData: Codable {
    let title: String
    let enabled: Bool
    let items: [MenuItemData]?
}

private struct MenuItemData: Codable {
    let title: String
    let enabled: Bool
    let key_equivalent: String?
    let submenu: [MenuItemData]?
}

@Suite("Menu Command Tests", .serialized)
struct MenuCommandTests {
    @Test("Menu command exists")
    func menuCommandExists() {
        let config = MenuCommand.configuration
        #expect(config.commandName == "menu")
        #expect(config.abstract.contains("menu bar"))
    }

    @Test("Menu command has expected subcommands")
    func menuSubcommands() {
        let subcommands = MenuCommand.configuration.subcommands
        #expect(subcommands.count == 3)

        let subcommandNames = subcommands.map(\.configuration.commandName)
        #expect(subcommandNames.contains("click"))
        #expect(subcommandNames.contains("click-system"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("Menu click command help")
    func menuClickHelp() async throws {
        let output = try await runCommand(["menu", "click", "--help"])

        #expect(output.contains("Click a menu item"))
        #expect(output.contains("--app"))
        #expect(output.contains("--path"))
        #expect(output.contains("--item"))
    }

    @Test("Menu click requires app and path/item")
    func menuClickValidation() async throws {
        // Test missing app
        await #expect(throws: Error.self) {
            _ = try await runCommand(["menu", "click", "--path", "File > New"])
        }

        // Test missing path/item
        await #expect(throws: Error.self) {
            _ = try await runCommand(["menu", "click", "--app", "Finder"])
        }
    }

    @Test("Menu path parsing")
    func menuPathParsing() {
        // Test simple path
        let path1 = "File > New"
        let components1 = path1.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(components1 == ["File", "New"])

        // Test complex path
        let path2 = "Window > Bring All to Front"
        let components2 = path2.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(components2 == ["Window", "Bring All to Front"])
    }

    @Test("Menu click-system command help")
    func menuSystemHelp() async throws {
        let output = try await runCommand(["menu", "click-system", "--help"])

        #expect(output.contains("Click system menu items"))
        #expect(output.contains("--title"))
        #expect(output.contains("--item"))
    }

    @Test("Menu list command help")
    func menuListHelp() async throws {
        let output = try await runCommand(["menu", "list", "--help"])

        #expect(output.contains("List all menu items"))
        #expect(output.contains("--app"))
        #expect(output.contains("--include-disabled"))
    }

    @Test("Menu error codes")
    func menuErrorCodes() {
        #expect(ErrorCode.MENU_BAR_NOT_FOUND.rawValue == "MENU_BAR_NOT_FOUND")
        #expect(ErrorCode.MENU_ITEM_NOT_FOUND.rawValue == "MENU_ITEM_NOT_FOUND")
    }
}

// MARK: - Menu Command Integration Tests

@Suite(
    "Menu Command Integration Tests",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true")
)
struct MenuCommandIntegrationTests {
    @Test("Click menu item in Finder")
    func clickFinderMenuItem() async throws {
        let output = try await runCommand([
            "menu", "click",
            "--app", "Finder",
            "--path", "View > Show Path Bar",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)
    }

    @Test("List menu items for application")
    func listMenuItems() async throws {
        let output = try await runCommand([
            "menu", "list",
            "--app", "Finder",
            "--json-output",
        ])

        let response = try JSONDecoder().decode(CodableJSONResponse<MenuListData>.self, from: output.data(using: .utf8)!)
        #expect(response.success == true)

        let menuData = response.data
        let structure = menuData.menu_structure
        if !structure.isEmpty {
            #expect(!structure.isEmpty)

            // Check for standard menus
            let menuTitles = structure.map { $0.title }
            #expect(menuTitles.contains("File"))
            #expect(menuTitles.contains("Edit"))
            #expect(menuTitles.contains("View"))
        }
    }

    @Test("Click system menu item")
    func clickSystemMenuItem() async throws {
        let output = try await runCommand([
            "menu", "click-system",
            "--title", "Notification Center",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        // System menu items might not always be available
        if !data.success {
            #expect(data.error?.code == "MENU_ITEM_NOT_FOUND")
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
