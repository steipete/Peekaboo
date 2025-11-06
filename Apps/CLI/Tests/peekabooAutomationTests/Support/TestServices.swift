import AppKit
import CoreGraphics
import Foundation
import PeekabooCLI
import PeekabooCore

enum TestStubError: Error {
    case unimplemented(String)
}

@MainActor
func stubUnimplemented(_ function: StaticString = #function) -> Never {
    fatalError("Test stub method not implemented: \(function)")
}

// MARK: - Stub Services

@MainActor
final class StubScreenCaptureService: ScreenCaptureServiceProtocol {
    func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        throw TestStubError.unimplemented(#function)
    }

    func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        throw TestStubError.unimplemented(#function)
    }

    func captureFrontmost() async throws -> CaptureResult {
        throw TestStubError.unimplemented(#function)
    }

    func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        throw TestStubError.unimplemented(#function)
    }

    func hasScreenRecordingPermission() async -> Bool {
        false
    }
}

@MainActor
final class StubAutomationService: UIAutomationServiceProtocol {
    func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        throw TestStubError.unimplemented(#function)
    }

    func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        sessionId: String?
    ) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func typeActions(
        _ actions: [TypeAction],
        typingDelay: Int,
        sessionId: String?
    ) async throws -> TypeResult {
        throw TestStubError.unimplemented(#function)
    }

    func scroll(
        direction: ScrollDirection,
        amount: Int,
        target: String?,
        smooth: Bool,
        delay: Int,
        sessionId: String?
    ) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func hotkey(keys: String, holdDuration: Int) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func hasAccessibilityPermission() async -> Bool {
        false
    }

    func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?
    ) async throws -> WaitForElementResult {
        throw TestStubError.unimplemented(#function)
    }

    func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func getFocusedElement() -> UIFocusInfo? {
        nil
    }

    func findElement(
        matching criteria: UIElementSearchCriteria,
        in appName: String?
    ) async throws -> DetectedElement {
        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubApplicationService: ApplicationServiceProtocol {
    var applications: [ServiceApplicationInfo]
    var windowsByApp: [String: [ServiceWindowInfo]]

    init(applications: [ServiceApplicationInfo], windowsByApp: [String: [ServiceWindowInfo]] = [:]) {
        self.applications = applications
        self.windowsByApp = windowsByApp
    }

    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        let data = ServiceApplicationListData(applications: self.applications)
        let summary = UnifiedToolOutput<ServiceApplicationListData>.Summary(
            brief: "Stub application list",
            status: .success,
            counts: ["applications": self.applications.count]
        )
        return UnifiedToolOutput(
            data: data,
            summary: summary,
            metadata: .init(duration: 0)
        )
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        if let match = self.applications.first(where: { $0.name == identifier || $0.bundleIdentifier == identifier }) {
            return match
        }
        throw PeekabooError.appNotFound(identifier)
    }

    func listWindows(for appIdentifier: String, timeout: Float?) async throws -> UnifiedToolOutput<ServiceWindowListData> {
        let windows = self.windowsByApp[appIdentifier] ?? []
        let targetApp = self.applications.first(where: { $0.name == appIdentifier })
        let data = ServiceWindowListData(windows: windows, targetApplication: targetApp)
        let summary = UnifiedToolOutput<ServiceWindowListData>.Summary(
            brief: "Stub window list",
            status: .success,
            counts: ["windows": windows.count]
        )
        return UnifiedToolOutput(
            data: data,
            summary: summary,
            metadata: .init(duration: 0)
        )
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        guard let first = self.applications.first else {
            throw PeekabooError.appNotFound("frontmost")
        }
        return first
    }

    func isApplicationRunning(identifier: String) async -> Bool {
        self.applications.contains { $0.name == identifier || $0.bundleIdentifier == identifier }
    }

    func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        throw TestStubError.unimplemented(#function)
    }

    func activateApplication(identifier: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        throw TestStubError.unimplemented(#function)
    }

    func hideApplication(identifier: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func unhideApplication(identifier: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func hideOtherApplications(identifier: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func showAllApplications() async throws {
        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubSessionManager: SessionManagerProtocol {
    func createSession() async throws -> String {
        UUID().uuidString
    }

    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {}

    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        nil
    }

    func getMostRecentSession() async -> String? {
        nil
    }

    func listSessions() async throws -> [SessionInfo] {
        []
    }

    func cleanSession(sessionId: String) async throws {}

    func cleanSessionsOlderThan(days: Int) async throws -> Int {
        0
    }

    func cleanAllSessions() async throws -> Int {
        0
    }

    func getSessionStoragePath() -> String {
        "/tmp/peekaboo-sessions"
    }

    func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?
    ) async throws {}

    func getElement(sessionId: String, elementId: String) async throws -> PeekabooCore.UIElement? {
        nil
    }

    func findElements(sessionId: String, matching query: String) async throws -> [PeekabooCore.UIElement] {
        []
    }

    func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        nil
    }
}

@MainActor
final class StubFileService: FileServiceProtocol {
    func cleanAllSessions(dryRun: Bool) async throws -> CleanResult {
        CleanResult(sessionsRemoved: 0, bytesFreed: 0, sessionDetails: [], dryRun: dryRun)
    }

    func cleanOldSessions(hours: Int, dryRun: Bool) async throws -> CleanResult {
        CleanResult(sessionsRemoved: 0, bytesFreed: 0, sessionDetails: [], dryRun: dryRun)
    }

    func cleanSpecificSession(sessionId: String, dryRun: Bool) async throws -> CleanResult {
        CleanResult(sessionsRemoved: 0, bytesFreed: 0, sessionDetails: [], dryRun: dryRun)
    }

    func getSessionCacheDirectory() -> URL {
        URL(fileURLWithPath: "/tmp/peekaboo-sessions")
    }

    func calculateDirectorySize(_ directory: URL) async throws -> Int64 {
        0
    }

    func listSessions() async throws -> [FileSessionInfo] {
        []
    }
}

@available(macOS 14.0, *)
@MainActor
final class StubProcessService: ProcessServiceProtocol {
    func loadScript(from path: String) async throws -> PeekabooScript {
        throw TestStubError.unimplemented(#function)
    }

    func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool
    ) async throws -> [StepResult] {
        throw TestStubError.unimplemented(#function)
    }

    func executeStep(
        _ step: ScriptStep,
        sessionId: String?
    ) async throws -> StepExecutionResult {
        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubDockService: DockServiceProtocol {
    func listDockItems(includeAll: Bool) async throws -> [DockItem] {
        []
    }

    func launchFromDock(appName: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func addToDock(path: String, persistent: Bool) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func removeFromDock(appName: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func rightClickDockItem(appName: String, menuItem: String?) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func hideDock() async throws {
        throw TestStubError.unimplemented(#function)
    }

    func showDock() async throws {
        throw TestStubError.unimplemented(#function)
    }

    func isDockAutoHidden() async -> Bool {
        false
    }

    func findDockItem(name: String) async throws -> DockItem {
        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubScreenService: ScreenServiceProtocol {
    var screens: [ScreenInfo]

    init(screens: [ScreenInfo] = []) {
        self.screens = screens
    }

    func listScreens() -> [ScreenInfo] {
        self.screens
    }

    func screenContainingWindow(bounds: CGRect) -> ScreenInfo? {
        self.screens.first
    }

    func screen(at index: Int) -> ScreenInfo? {
        guard index >= 0, index < self.screens.count else { return nil }
        return self.screens[index]
    }

    var primaryScreen: ScreenInfo? {
        self.screens.first
    }
}

@MainActor
final class StubMenuService: MenuServiceProtocol {
    var menusByApp: [String: MenuStructure]
    var frontmostMenus: MenuStructure?
    var menuExtras: [MenuExtraInfo]

    init(
        menusByApp: [String: MenuStructure],
        frontmostMenus: MenuStructure? = nil,
        menuExtras: [MenuExtraInfo] = []
    ) {
        self.menusByApp = menusByApp
        self.frontmostMenus = frontmostMenus
        self.menuExtras = menuExtras
    }

    func listMenus(for appIdentifier: String) async throws -> MenuStructure {
        guard let structure = self.menusByApp[appIdentifier] else {
            throw PeekabooError.menuNotFound(appIdentifier)
        }
        return structure
    }

    func listFrontmostMenus() async throws -> MenuStructure {
        guard let menus = self.frontmostMenus else {
            throw PeekabooError.menuNotFound("frontmost")
        }
        return menus
    }

    func clickMenuItem(app: String, itemPath: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func clickMenuItemByName(app: String, itemName: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func clickMenuExtra(title: String) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func listMenuExtras() async throws -> [MenuExtraInfo] {
        self.menuExtras
    }

    func listMenuBarItems() async throws -> [MenuBarItemInfo] {
        []
    }

    func clickMenuBarItem(named name: String) async throws -> ClickResult {
        throw TestStubError.unimplemented(#function)
    }

    func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubDialogService: DialogServiceProtocol {
    var dialogElements: DialogElements?

    init(elements: DialogElements? = nil) {
        self.dialogElements = elements
    }

    func findActiveDialog(windowTitle: String?) async throws -> DialogInfo {
        guard let elements = self.dialogElements else {
            throw PeekabooError.dialogNotFound(windowTitle ?? "dialog")
        }
        return elements.dialogInfo
    }

    func clickButton(buttonText: String, windowTitle: String?) async throws -> DialogActionResult {
        throw TestStubError.unimplemented(#function)
    }

    func enterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?
    ) async throws -> DialogActionResult {
        throw TestStubError.unimplemented(#function)
    }

    func handleFileDialog(path: String?, filename: String?, actionButton: String) async throws -> DialogActionResult {
        throw TestStubError.unimplemented(#function)
    }

    func dismissDialog(force: Bool, windowTitle: String?) async throws -> DialogActionResult {
        throw TestStubError.unimplemented(#function)
    }

    func listDialogElements(windowTitle: String?) async throws -> DialogElements {
        guard let elements = self.dialogElements else {
            throw PeekabooError.dialogNotFound(windowTitle ?? "dialog")
        }
        return elements
    }
}

@MainActor
final class StubWindowService: WindowManagementServiceProtocol {
    var windowsByApp: [String: [ServiceWindowInfo]]

    init(windowsByApp: [String: [ServiceWindowInfo]]) {
        self.windowsByApp = windowsByApp
    }

    func closeWindow(target: WindowTarget) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func minimizeWindow(target: WindowTarget) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func maximizeWindow(target: WindowTarget) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func focusWindow(target: WindowTarget) async throws {
        throw TestStubError.unimplemented(#function)
    }

    func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        switch target {
        case let .application(app):
            return self.windowsByApp[app] ?? []
        case let .applicationAndTitle(app, title):
            return self.windowsByApp[app]?.filter { $0.title.contains(title) } ?? []
        case .frontmost:
            return self.windowsByApp.values.first ?? []
        case let .windowId(id):
            return self.windowsByApp.values.flatMap { $0 }.filter { $0.windowID == id }
        case let .title(title):
            return self.windowsByApp.values.flatMap { $0 }.filter { $0.title.contains(title) }
        case let .index(app, index):
            guard let windows = self.windowsByApp[app], index < windows.count else { return [] }
            return [windows[index]]
        }
    }

    func getFocusedWindow() async throws -> ServiceWindowInfo? {
        nil
    }
}

@MainActor
final class StubSpaceService: SpaceCommandSpaceService {
    var spaces: [SpaceInfo]
    var windowSpaces: [Int: [SpaceInfo]]

    init(spaces: [SpaceInfo], windowSpaces: [Int: [SpaceInfo]] = [:]) {
        self.spaces = spaces
        self.windowSpaces = windowSpaces
    }

    func getAllSpaces() -> [SpaceInfo] {
        self.spaces
    }

    func getSpacesForWindow(windowID: CGWindowID) -> [SpaceInfo] {
        self.windowSpaces[Int(windowID)] ?? []
    }

    func moveWindowToCurrentSpace(windowID: CGWindowID) throws {}

    func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) throws {}

    func switchToSpace(_ spaceID: CGSSpaceID) async throws {}
}

// MARK: - Aggregator

@MainActor
enum TestServicesFactory {
    static func makePeekabooServices(
        applications: ApplicationServiceProtocol,
        windows: WindowManagementServiceProtocol,
        menu: MenuServiceProtocol,
        dialogs: DialogServiceProtocol,
        screens: [ScreenInfo] = []
    ) -> PeekabooServices {
        let screenService = StubScreenService(screens: screens)
        let services = PeekabooServices(
            logging: LoggingService(),
            screenCapture: StubScreenCaptureService(),
            applications: applications,
            automation: StubAutomationService(),
            windows: windows,
            menu: menu,
            dock: StubDockService(),
            dialogs: dialogs,
            sessions: StubSessionManager(),
            files: StubFileService(),
            process: StubProcessService(),
            permissions: PermissionsService(),
            audioInput: AudioInputService(aiService: PeekabooAIService()),
            agent: nil,
            configuration: ConfigurationManager.shared,
            screens: screenService)

        return services
    }
}
