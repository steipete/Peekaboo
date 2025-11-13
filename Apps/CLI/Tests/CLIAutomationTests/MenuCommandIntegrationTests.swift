import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Menu Command Integration Tests", .serialized, .tags(.automation))
struct MenuCommandIntegrationTests {
    @Test("menu list returns JSON even when no windows exist")
    func menuListNoWindows() async throws {
        let context = await self.makeMenuContext(hasWindows: false)
        let result = try await self.runMenuCommand(
            [
                "menu", "list",
                "--app", context.appInfo.name,
                "--json-output",
                "--no-auto-focus",
            ],
            context: context
        )

        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        let response = try JSONDecoder().decode(
            CodableJSONResponse<MenuListData>.self,
            from: output.data(using: .utf8)!
        )

        #expect(response.success == true)
        #expect(response.data.menu_structure.first?.title == "File")
        #expect(context.menuService.listMenusRequests == [context.appInfo.name])
    }

    @Test("menu click succeeds after list when auto focus is disabled")
    func menuClickAfterList() async throws {
        let context = await self.makeMenuContext(hasWindows: false)

        _ = try await self.runMenuCommand(
            [
                "menu", "list",
                "--app", context.appInfo.name,
                "--json-output",
                "--no-auto-focus",
            ],
            context: context
        )

        let result = try await self.runMenuCommand(
            [
                "menu", "click",
                "--app", context.appInfo.name,
                "--path", "File > New",
                "--json-output",
                "--no-auto-focus",
            ],
            context: context
        )

        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        let response = try JSONDecoder().decode(
            CodableJSONResponse<MenuClickResult>.self,
            from: output.data(using: .utf8)!
        )

        #expect(response.success == true)
        #expect(response.data.menu_path == "File > New")
        #expect(context.menuService.clickPathCalls == [(context.appInfo.name, "File > New")])
    }

    // MARK: - Helpers

    private func runMenuCommand(
        _ arguments: [String],
        context: MenuTestContext,
        allowedExitStatuses: Set<Int32> = [0]
    ) async throws -> CommandRunResult {
        let result = try await InProcessCommandRunner.run(arguments, services: context.services)
        try result.validateExitStatus(allowedExitCodes: allowedExitStatuses, arguments: arguments)
        return result
    }

    @MainActor
    private func makeMenuContext(hasWindows: Bool) -> MenuTestContext {
        let appName = "Finder"
        let bundleID = "com.apple.finder"
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 501,
            bundleIdentifier: bundleID,
            name: appName,
            bundlePath: "/System/Library/CoreServices/Finder.app",
            isActive: true,
            isHidden: false,
            windowCount: hasWindows ? 1 : 0
        )

        let menuStructure = self.sampleMenuStructure(appInfo: appInfo)
        let menuService = StubMenuService(menusByApp: [appName: menuStructure])

        let windows = hasWindows ? [appName: [self.sampleWindowInfo()]] : [:]
        let windowService = StubWindowService(windowsByApp: windows)
        let applicationService = StubApplicationService(applications: [appInfo], windowsByApp: windows)

        let services = TestServicesFactory.makePeekabooServices(
            applications: applicationService,
            windows: windowService,
            menu: menuService
        )

        return MenuTestContext(
            services: services,
            appInfo: appInfo,
            menuService: menuService,
            windowService: windowService
        )
    }

    private func sampleMenuStructure(appInfo: ServiceApplicationInfo) -> MenuStructure {
        let newItem = MenuItem(
            title: "New",
            bundleIdentifier: appInfo.bundleIdentifier,
            ownerName: appInfo.name,
            keyboardShortcut: nil,
            isEnabled: true,
            isChecked: false,
            isSeparator: false,
            submenu: [],
            path: "File > New"
        )
        let fileMenu = Menu(
            title: "File",
            bundleIdentifier: appInfo.bundleIdentifier,
            ownerName: appInfo.name,
            items: [newItem]
        )
        return MenuStructure(application: appInfo, menus: [fileMenu])
    }

    private func sampleWindowInfo() -> ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: 101,
            title: "Finder",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 0,
            spaceID: 1,
            spaceName: "Desktop 1",
            screenIndex: 0,
            screenName: "Built-in"
        )
    }

    private struct MenuTestContext {
        let services: PeekabooServices
        let appInfo: ServiceApplicationInfo
        let menuService: StubMenuService
        let windowService: StubWindowService
    }
}
#endif
