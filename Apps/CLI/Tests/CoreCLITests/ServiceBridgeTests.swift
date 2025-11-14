import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

@Suite("Service Bridge Routing")
@MainActor
struct ServiceBridgeTests {
    @Test func automationClickForwardsCalls() async throws {
        let automation = MockAutomationService()
        try await AutomationServiceBridge.click(
            automation: automation,
            target: .coordinates(CGPoint(x: 10, y: 20)),
            clickType: .double,
            sessionId: "session-123"
        )

        #expect(automation.clickCalls.count == 1)
        #expect(automation.clickCalls.first?.sessionId == "session-123")
    }

    @Test func automationWaitReturnsMockResult() async throws {
        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "OK",
            value: nil,
            bounds: CGRect(x: 0, y: 0, width: 44, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: [:]
        )
        let mock = MockAutomationService(waitResult: .init(found: true, element: element, waitTime: 0.25))

        let result = try await AutomationServiceBridge.waitForElement(
            automation: mock,
            target: .elementId("B1"),
            timeout: 1,
            sessionId: "S42"
        )

        #expect(result.found)
        #expect(mock.waitCalls.count == 1)
    }

    @Test func windowBridgeReturnsStubbedWindows() async throws {
        let window = ServiceWindowInfo(
            windowID: 101,
            title: "Main",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        let windows = try await WindowServiceBridge.listWindows(
            windows: MockWindowService(result: [window]),
            target: .frontmost
        )
        #expect(windows == [window])
    }

    @Test func menuBridgeListsMenuBarItems() async throws {
        let menuItems = [MenuBarItemInfo(
            title: "Item",
            index: 0,
            isVisible: true,
            description: nil,
            rawTitle: "Item",
            bundleIdentifier: "com.test",
            ownerName: "Test",
            frame: nil,
            identifier: "com.test.item"
        )]
        let items = try await MenuServiceBridge.listMenuBarItems(menu: MockMenuService(barItems: menuItems))
        #expect(items.count == 1)
        #expect(items.first?.title == "Item")
    }

    @Test func dockBridgeListsItems() async throws {
        let dockItems = [DockItem(
            index: 0,
            title: "Peekaboo",
            itemType: .application,
            isRunning: true,
            bundleIdentifier: "boo.peekaboo",
            position: nil,
            size: nil
        )]
        let items = try await DockServiceBridge.listDockItems(
            dock: MockDockService(items: dockItems),
            includeAll: true
        )
        #expect(items == dockItems)
    }
}

@MainActor
final class MockAutomationService: UIAutomationServiceProtocol {
    struct ClickCall { let target: ClickTarget; let clickType: ClickType; let sessionId: String? }
    var clickCalls: [ClickCall] = []
    var waitCalls: [ClickTarget] = []
    var waitResult: WaitForElementResult

    init(waitResult: WaitForElementResult = .init(found: false, element: nil, waitTime: 0)) {
        self.waitResult = waitResult
    }

    func detectElements(
        in _: Data,
        sessionId _: String?,
        windowContext _: WindowContext?
    ) async throws -> ElementDetectionResult {
        throw PeekabooError.notImplemented("mock detectElements")
    }

    func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        self.clickCalls.append(.init(target: target, clickType: clickType, sessionId: sessionId))
    }

    func type(
        text _: String,
        target _: String?,
        clearExisting _: Bool,
        typingDelay _: Int,
        sessionId _: String?
    ) async throws {}

    func typeActions(_ actions: [TypeAction], typingDelay _: Int, sessionId _: String?) async throws -> TypeResult {
        TypeResult(totalCharacters: actions.count, keyPresses: actions.count)
    }

    func scroll(_ request: ScrollRequest) async throws { _ = request }

    func hotkey(keys _: String, holdDuration _: Int) async throws {}

    func swipe(from _: CGPoint, to _: CGPoint, duration _: Int, steps _: Int) async throws {}

    func hasAccessibilityPermission() async -> Bool { true }

    func waitForElement(
        target: ClickTarget,
        timeout _: TimeInterval,
        sessionId _: String?
    ) async throws -> WaitForElementResult {
        self.waitCalls.append(target)
        return self.waitResult
    }

    func drag(from _: CGPoint, to _: CGPoint, duration _: Int, steps _: Int, modifiers _: String?) async throws {}

    func moveMouse(to _: CGPoint, duration _: Int, steps _: Int) async throws {}

    func getFocusedElement() -> UIFocusInfo? { nil }

    func findElement(matching _: UIElementSearchCriteria, in _: String?) async throws -> DetectedElement {
        throw PeekabooError.elementNotFound("not implemented")
    }
}

@MainActor
final class MockWindowService: WindowManagementServiceProtocol {
    let windowsResult: [ServiceWindowInfo]

    init(result: [ServiceWindowInfo]) {
        self.windowsResult = result
    }

    func closeWindow(target _: WindowTarget) async throws {}
    func minimizeWindow(target _: WindowTarget) async throws {}
    func maximizeWindow(target _: WindowTarget) async throws {}
    func moveWindow(target _: WindowTarget, to _: CGPoint) async throws {}
    func resizeWindow(target _: WindowTarget, to _: CGSize) async throws {}
    func setWindowBounds(target _: WindowTarget, bounds _: CGRect) async throws {}
    func focusWindow(target _: WindowTarget) async throws {}
    func listWindows(target _: WindowTarget) async throws -> [ServiceWindowInfo] { self.windowsResult }
    func getFocusedWindow() async throws -> ServiceWindowInfo? { self.windowsResult.first }
}

@MainActor
final class MockMenuService: MenuServiceProtocol {
    var barItems: [MenuBarItemInfo]

    init(barItems: [MenuBarItemInfo]) {
        self.barItems = barItems
    }

    func listMenus(for _: String) async throws -> MenuStructure { self.emptyStructure }
    func listFrontmostMenus() async throws -> MenuStructure { self.emptyStructure }
    func clickMenuItem(app _: String, itemPath _: String) async throws {}
    func clickMenuItemByName(app _: String, itemName _: String) async throws {}
    func clickMenuExtra(title _: String) async throws {}
    func listMenuExtras() async throws -> [MenuExtraInfo] { [] }
    func listMenuBarItems() async throws -> [MenuBarItemInfo] { self.barItems }
    func clickMenuBarItem(named _: String) async throws -> PeekabooCore.ClickResult { .init(
        elementDescription: "",
        location: nil
    ) }
    func clickMenuBarItem(at _: Int) async throws -> PeekabooCore.ClickResult { .init(
        elementDescription: "",
        location: nil
    ) }

    private var emptyStructure: MenuStructure {
        MenuStructure(
            application: ServiceApplicationInfo(processIdentifier: 1, bundleIdentifier: "test", name: "Test"),
            menus: []
        )
    }
}

@MainActor
final class MockDockService: DockServiceProtocol {
    var items: [DockItem]

    init(items: [DockItem]) {
        self.items = items
    }

    func listDockItems(includeAll _: Bool) async throws -> [DockItem] { self.items }
    func launchFromDock(appName _: String) async throws {}
    func addToDock(path _: String, persistent _: Bool) async throws {}
    func removeFromDock(appName _: String) async throws {}
    func rightClickDockItem(appName _: String, menuItem _: String?) async throws {}
    func hideDock() async throws {}
    func showDock() async throws {}
    func isDockAutoHidden() async -> Bool { false }
    func findDockItem(name _: String) async throws -> DockItem { self.items.first! }
}
