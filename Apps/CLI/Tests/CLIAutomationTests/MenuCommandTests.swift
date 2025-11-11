import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
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

@Suite("Menu Command Tests", .serialized, .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
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
        let result = try await self.runMenuCommand(["menu", "click", "--help"])
        #expect(result.exitStatus == 0)
        let output = self.output(from: result)
        #expect(output.contains("Click a menu item"))
        #expect(output.contains("--app"))
        #expect(output.contains("--path"))
        #expect(output.contains("--item"))
    }

    @Test("Menu click requires app and path/item")
    func menuClickValidation() async throws {
        // Test missing app
        await #expect(throws: (any Error).self) {
            _ = try await self.runMenuCommand(["menu", "click", "--path", "File > New"])
        }

        // Test missing path/item
        await #expect(throws: (any Error).self) {
            _ = try await self.runMenuCommand(["menu", "click", "--app", "Finder"])
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
        let result = try await self.runMenuCommand(["menu", "click-system", "--help"])
        #expect(result.exitStatus == 0)
        let output = self.output(from: result)
        #expect(output.contains("Click system menu items"))
        #expect(output.contains("--title"))
        #expect(output.contains("--item"))
    }

    @Test("Menu list command help")
    func menuListHelp() async throws {
        let result = try await self.runMenuCommand(["menu", "list", "--help"])
        #expect(result.exitStatus == 0)
        let output = self.output(from: result)
        #expect(output.contains("List all menu items"))
        #expect(output.contains("--app"))
        #expect(output.contains("--include-disabled"))
    }

    @Test("Menu error codes")
    func menuErrorCodes() {
        #expect(ErrorCode.MENU_BAR_NOT_FOUND.rawValue == "MENU_BAR_NOT_FOUND")
        #expect(ErrorCode.MENU_ITEM_NOT_FOUND.rawValue == "MENU_ITEM_NOT_FOUND")
    }

    @Test("Menu click executes menu service")
    func menuClickExecution() async throws {
        let args = [
            "menu", "click",
            "--app", "Finder",
            "--item", "Open",
            "--no-auto-focus",
            "--json-output",
        ]
        let (result, context) = try await self.runMenuCommandWithContext(args)
        #expect(result.exitStatus == 0)
        let calls = await self.menuState(context.menuService) { $0.clickItemCalls }
        #expect(calls.contains { $0.app == "Finder" && $0.item == "Open" })
    }

    @Test("Menu click path executes menu service")
    func menuClickPathExecution() async throws {
        let args = [
            "menu", "click",
            "--app", "Finder",
            "--path", "File > Save",
            "--no-auto-focus",
            "--json-output",
        ]
        let (result, context) = try await self.runMenuCommandWithContext(args)
        #expect(result.exitStatus == 0)
        let pathCalls = await self.menuState(context.menuService) { $0.clickPathCalls }
        #expect(pathCalls.contains { $0.app == "Finder" && $0.path == "File > Save" })
    }

    private func runMenuCommand(
        _ args: [String],
        configure: (@MainActor (StubMenuService, StubApplicationService) -> ())? = nil
    ) async throws -> CommandRunResult {
        let (result, _) = try await self.runMenuCommandWithContext(args, configure: configure)
        return result
    }

    private func runMenuCommandWithContext(
        _ args: [String],
        configure: (@MainActor (StubMenuService, StubApplicationService) -> ())? = nil
    ) async throws -> (CommandRunResult, MenuHarnessContext) {
        let context = await self.makeMenuContext()
        if let configure {
            await MainActor.run {
                configure(context.menuService, context.applicationService)
            }
        }
        let result = try await InProcessCommandRunner.run(args, services: context.services)
        return (result, context)
    }

    private func output(from result: CommandRunResult) -> String {
        result.stdout.isEmpty ? result.stderr : result.stdout
    }

    private func menuState<T: Sendable>(
        _ service: StubMenuService,
        _ operation: @MainActor (StubMenuService) -> T
    ) async -> T {
        await MainActor.run {
            operation(service)
        }
    }

    @MainActor
    private func makeMenuContext() -> MenuHarnessContext {
        let data = Self.defaultMenuData()
        let menuService = StubMenuService(menusByApp: data.menusByApp, menuExtras: data.extras)
        let applicationService = StubApplicationService(applications: [data.appInfo])
        let services = TestServicesFactory.makePeekabooServices(
            applications: applicationService,
            menu: menuService
        )
        return MenuHarnessContext(services: services, menuService: menuService, applicationService: applicationService)
    }

    @MainActor
    private static func defaultMenuData()
    -> (appInfo: ServiceApplicationInfo, menusByApp: [String: MenuStructure], extras: [MenuExtraInfo]) {
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 101,
            bundleIdentifier: "com.apple.finder",
            name: "Finder",
            bundlePath: "/System/Library/CoreServices/Finder.app",
            isActive: true,
            isHidden: false,
            windowCount: 1
        )

        let fileMenu = Menu(
            title: "File",
            items: [
                MenuItem(title: "New", path: "File > New"),
                MenuItem(title: "Open", path: "File > Open"),
                MenuItem(title: "Save", path: "File > Save"),
            ],
            isEnabled: true
        )

        let viewMenu = Menu(
            title: "View",
            items: [
                MenuItem(title: "Show Path Bar", path: "View > Show Path Bar"),
            ],
            isEnabled: true
        )

        let menuStructure = MenuStructure(application: appInfo, menus: [fileMenu, viewMenu])
        let extras = [MenuExtraInfo(title: "WiFi", position: CGPoint(x: 0, y: 0), isVisible: true)]

        return (appInfo, ["Finder": menuStructure], extras)
    }

    private struct MenuHarnessContext {
        let services: PeekabooServices
        let menuService: StubMenuService
        let applicationService: StubApplicationService
    }
}

// MARK: - Menu Command Integration Tests (removed real CLI coverage)

#endif
