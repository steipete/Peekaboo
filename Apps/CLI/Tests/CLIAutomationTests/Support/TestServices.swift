import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation
@testable import PeekabooCLI
@testable import PeekabooCore

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
    var permissionGranted: Bool
    var defaultCaptureResult: CaptureResult?
    var captureScreenHandler: ((Int?) async throws -> CaptureResult)?
    var captureWindowHandler: ((String, Int?) async throws -> CaptureResult)?
    var captureFrontmostHandler: (() async throws -> CaptureResult)?
    var captureAreaHandler: ((CGRect) async throws -> CaptureResult)?

    init(permissionGranted: Bool = true) {
        self.permissionGranted = permissionGranted
    }

    func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        if let handler = self.captureScreenHandler {
            return try await handler(displayIndex)
        }
        return try await self.makeDefaultCaptureResult(function: #function)
    }

    func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        if let handler = self.captureWindowHandler {
            return try await handler(appIdentifier, windowIndex)
        }
        return try await self.makeDefaultCaptureResult(function: #function)
    }

    func captureFrontmost() async throws -> CaptureResult {
        if let handler = self.captureFrontmostHandler {
            return try await handler()
        }
        return try await self.makeDefaultCaptureResult(function: #function)
    }

    func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        if let handler = self.captureAreaHandler {
            return try await handler(rect)
        }
        return try await self.makeDefaultCaptureResult(function: #function)
    }

    func hasScreenRecordingPermission() async -> Bool {
        self.permissionGranted
    }

    private func makeDefaultCaptureResult(function: StaticString) async throws -> CaptureResult {
        if let result = self.defaultCaptureResult {
            return result
        }
        throw TestStubError.unimplemented(function)
    }
}

@MainActor
final class StubAutomationService: UIAutomationServiceProtocol {
    struct ClickCall: Sendable {
        let target: ClickTarget
        let clickType: ClickType
        let sessionId: String?
    }

    struct TypeTextCall: Sendable {
        let text: String
        let target: String?
        let clearExisting: Bool
        let typingDelay: Int
        let sessionId: String?
    }

    struct TypeActionsCall: Sendable {
        let actions: [TypeAction]
        let typingDelay: Int
        let sessionId: String?
    }

    struct ScrollCall: Sendable {
        let request: ScrollRequest
    }

    struct SwipeCall: Sendable {
        let from: CGPoint
        let to: CGPoint
        let duration: Int
        let steps: Int
    }

    struct DragCall: Sendable {
        let from: CGPoint
        let to: CGPoint
        let duration: Int
        let steps: Int
        let modifiers: String?
    }

    struct MoveMouseCall: Sendable {
        let destination: CGPoint
        let duration: Int
        let steps: Int
        let profile: MouseMovementProfile
    }

    struct HotkeyCall: Sendable {
        let keys: String
        let holdDuration: Int
    }

    struct WaitForElementCall: Sendable {
        let target: ClickTarget
        let timeout: TimeInterval
        let sessionId: String?
    }

    private enum WaitTargetKey: Hashable {
        case elementId(String)
        case query(String)
        case coordinates(x: Double, y: Double)
    }

    var clickCalls: [ClickCall] = []
    var typeTextCalls: [TypeTextCall] = []
    var typeActionsCalls: [TypeActionsCall] = []
    var scrollCalls: [ScrollCall] = []
    var swipeCalls: [SwipeCall] = []
    var dragCalls: [DragCall] = []
    var moveMouseCalls: [MoveMouseCall] = []
    var hotkeyCalls: [HotkeyCall] = []
    var waitForElementCalls: [WaitForElementCall] = []
    var detectElementsCalls: [(imageData: Data, sessionId: String?, windowContext: WindowContext?)] = []

    var nextTypeActionsResult: TypeResult?
    var typeActionsResultProvider: (([TypeAction], Int, String?) -> TypeResult)?
    var waitForElementProvider: ((ClickTarget, TimeInterval, String?) -> WaitForElementResult)?
    private var waitForElementResults: [WaitTargetKey: WaitForElementResult] = [:]
    var detectElementsHandler: ((Data, String?, WindowContext?) async throws -> ElementDetectionResult)?
    var nextDetectionResult: ElementDetectionResult?

    func setWaitForElementResult(_ result: WaitForElementResult, for target: ClickTarget) {
        self.waitForElementResults[self.key(for: target)] = result
    }

    func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        self.detectElementsCalls.append((imageData, sessionId, windowContext))

        if let handler = self.detectElementsHandler {
            return try await handler(imageData, sessionId, windowContext)
        }

        if let nextDetectionResult {
            return nextDetectionResult
        }

        throw TestStubError.unimplemented(#function)
    }

    func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        self.clickCalls.append(ClickCall(target: target, clickType: clickType, sessionId: sessionId))
    }

    func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        sessionId: String?
    ) async throws {
        self.typeTextCalls.append(
            TypeTextCall(
                text: text,
                target: target,
                clearExisting: clearExisting,
                typingDelay: typingDelay,
                sessionId: sessionId
            ))
    }

    func typeActions(
        _ actions: [TypeAction],
        typingDelay: Int,
        sessionId: String?
    ) async throws -> TypeResult {
        self.typeActionsCalls.append(
            TypeActionsCall(actions: actions, typingDelay: typingDelay, sessionId: sessionId)
        )

        if let provider = self.typeActionsResultProvider {
            return provider(actions, typingDelay, sessionId)
        }

        if let nextResult = self.nextTypeActionsResult {
            return nextResult
        }

        let totals = actions.reduce(into: (characters: 0, keyPresses: 0)) { partial, action in
            switch action {
            case let .text(text):
                partial.characters += text.count
            case .key:
                partial.keyPresses += 1
            case .clear:
                break
            }
        }

        return TypeResult(totalCharacters: totals.characters, keyPresses: totals.keyPresses)
    }

    func scroll(_ request: ScrollRequest) async throws {
        self.scrollCalls.append(
            ScrollCall(request: request)
        )
    }

    func hotkey(keys: String, holdDuration: Int) async throws {
        self.hotkeyCalls.append(HotkeyCall(keys: keys, holdDuration: holdDuration))
    }

    func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        self.swipeCalls.append(SwipeCall(from: from, to: to, duration: duration, steps: steps))
    }

    func hasAccessibilityPermission() async -> Bool {
        true
    }

    func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?
    ) async throws -> WaitForElementResult {
        self.waitForElementCalls.append(
            WaitForElementCall(target: target, timeout: timeout, sessionId: sessionId)
        )

        if let provider = self.waitForElementProvider {
            return provider(target, timeout, sessionId)
        }

        if let stored = self.waitForElementResults[self.key(for: target)] {
            return stored
        }

        return WaitForElementResult(found: false, element: nil, waitTime: 0)
    }

    func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws {
        self.dragCalls.append(
            DragCall(from: from, to: to, duration: duration, steps: steps, modifiers: modifiers)
        )
    }

    func moveMouse(to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws {
        self.moveMouseCalls.append(
            MoveMouseCall(destination: to, duration: duration, steps: steps, profile: profile)
        )
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

    private func key(for target: ClickTarget) -> WaitTargetKey {
        switch target {
        case let .elementId(identifier):
            .elementId(identifier)
        case let .query(query):
            .query(query)
        case let .coordinates(point):
            .coordinates(x: point.x, y: point.y)
        }
    }
}

@MainActor
final class StubApplicationService: ApplicationServiceProtocol {
    var applications: [ServiceApplicationInfo]
    var windowsByApp: [String: [ServiceWindowInfo]]
    var launchResults: [String: ServiceApplicationInfo]
    var launchCalls: [String] = []
    var activateCalls: [String] = []
    var quitCalls: [(identifier: String, force: Bool)] = []
    var quitShouldSucceed = true
    var hideCalls: [String] = []
    var unhideCalls: [String] = []
    var hideOtherCalls: [String] = []
    var showAllCallCount = 0

    init(applications: [ServiceApplicationInfo], windowsByApp: [String: [ServiceWindowInfo]] = [:]) {
        self.applications = applications
        self.windowsByApp = windowsByApp
        self.launchResults = [:]
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

    func listWindows(
        for appIdentifier: String,
        timeout: Float?
    ) async throws -> UnifiedToolOutput<ServiceWindowListData> {
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
        self.launchCalls.append(identifier)
        if let result = self.launchResults[identifier] {
            return result
        }
        if let existing = self.applications
            .first(where: { $0.name == identifier || $0.bundleIdentifier == identifier }) {
            return existing
        }
        return ServiceApplicationInfo(
            processIdentifier: Int32.random(in: 1000...2000),
            bundleIdentifier: "launched.\(identifier)",
            name: identifier
        )
    }

    func activateApplication(identifier: String) async throws {
        self.activateCalls.append(identifier)
    }

    func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        self.quitCalls.append((identifier: identifier, force: force))
        return self.quitShouldSucceed
    }

    func hideApplication(identifier: String) async throws {
        self.hideCalls.append(identifier)
    }

    func unhideApplication(identifier: String) async throws {
        self.unhideCalls.append(identifier)
    }

    func hideOtherApplications(identifier: String) async throws {
        self.hideOtherCalls.append(identifier)
    }

    func showAllApplications() async throws {
        self.showAllCallCount += 1
    }
}

final class StubSessionManager: SessionManagerProtocol, @unchecked Sendable {
    private(set) var detectionResults: [String: ElementDetectionResult] = [:]
    private(set) var sessionInfos: [String: SessionInfo] = [:]
    private(set) var storedElements: [String: [String: PeekabooCore.UIElement]] = [:]
    var mostRecentSessionId: String?
    struct ScreenshotRecord: Sendable {
        let path: String
        let applicationName: String?
        let windowTitle: String?
        let windowBounds: CGRect?
    }

    private(set) var storedScreenshots: [String: [ScreenshotRecord]] = [:]

    func createSession() async throws -> String {
        let sessionId = UUID().uuidString
        let now = Date()
        self.sessionInfos[sessionId] = SessionInfo(
            id: sessionId,
            processId: 0,
            createdAt: now,
            lastAccessedAt: now,
            sizeInBytes: 0,
            screenshotCount: 0,
            isActive: true
        )
        self.mostRecentSessionId = sessionId
        return sessionId
    }

    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        self.detectionResults[sessionId] = result
        self.mostRecentSessionId = sessionId

        let existingInfo = self.sessionInfos[sessionId]
        let createdAt = existingInfo?.createdAt ?? Date()
        self.sessionInfos[sessionId] = SessionInfo(
            id: sessionId,
            processId: existingInfo?.processId ?? 0,
            createdAt: createdAt,
            lastAccessedAt: Date(),
            sizeInBytes: existingInfo?.sizeInBytes ?? 0,
            screenshotCount: (existingInfo?.screenshotCount ?? 0) + 1,
            isActive: true
        )

        self.storedElements[sessionId] = result.elements.all
            .reduce(into: [String: PeekabooCore.UIElement]()) { partial, element in
                partial[element.id] = PeekabooCore.UIElement(
                    id: element.id,
                    elementId: element.id,
                    role: element.type.rawValue,
                    title: element.label,
                    label: element.label,
                    value: element.value,
                    description: nil,
                    help: nil,
                    roleDescription: nil,
                    identifier: element.attributes["identifier"],
                    frame: element.bounds,
                    isActionable: true,
                    parentId: nil,
                    children: [],
                    keyboardShortcut: nil
                )
            }
    }

    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        self.detectionResults[sessionId]
    }

    func getMostRecentSession() async -> String? {
        self.mostRecentSessionId
    }

    func listSessions() async throws -> [SessionInfo] {
        Array(self.sessionInfos.values)
    }

    func cleanSession(sessionId: String) async throws {
        self.detectionResults.removeValue(forKey: sessionId)
        self.sessionInfos.removeValue(forKey: sessionId)
        self.storedElements.removeValue(forKey: sessionId)
        if self.mostRecentSessionId == sessionId {
            self.mostRecentSessionId = nil
        }
    }

    func cleanSessionsOlderThan(days: Int) async throws -> Int {
        let threshold = Date().addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        let ids = self.sessionInfos.values
            .filter { $0.lastAccessedAt < threshold }
            .map(\.id)
        for id in ids {
            try await self.cleanSession(sessionId: id)
        }
        return ids.count
    }

    func cleanAllSessions() async throws -> Int {
        let count = self.sessionInfos.count
        self.detectionResults.removeAll()
        self.sessionInfos.removeAll()
        self.storedElements.removeAll()
        self.mostRecentSessionId = nil
        return count
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
    ) async throws {
        let existingInfo = self.sessionInfos[sessionId]
        let createdAt = existingInfo?.createdAt ?? Date()
        let screenshotCount = (existingInfo?.screenshotCount ?? 0) + 1
        self.sessionInfos[sessionId] = SessionInfo(
            id: sessionId,
            processId: existingInfo?.processId ?? 0,
            createdAt: createdAt,
            lastAccessedAt: Date(),
            sizeInBytes: existingInfo?.sizeInBytes ?? 0,
            screenshotCount: screenshotCount,
            isActive: existingInfo?.isActive ?? true
        )
        var records = self.storedScreenshots[sessionId] ?? []
        records.append(
            ScreenshotRecord(
                path: screenshotPath,
                applicationName: applicationName,
                windowTitle: windowTitle,
                windowBounds: windowBounds
            )
        )
        self.storedScreenshots[sessionId] = records
    }

    func getElement(sessionId: String, elementId: String) async throws -> PeekabooCore.UIElement? {
        self.storedElements[sessionId]?[elementId]
    }

    func findElements(sessionId: String, matching query: String) async throws -> [PeekabooCore.UIElement] {
        self.storedElements[sessionId]?.values.filter {
            $0.label?.localizedCaseInsensitiveContains(query) == true ||
                $0.title?.localizedCaseInsensitiveContains(query) == true
        } ?? []
    }

    func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        nil
    }
}

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
final class StubProcessService: ProcessServiceProtocol, @unchecked Sendable {
    struct LoadScriptCall {
        let path: String
    }

    struct ExecuteScriptCall {
        let script: PeekabooScript
        let failFast: Bool
        let verbose: Bool
    }

    struct ExecuteStepCall {
        let step: ScriptStep
        let sessionId: String?
    }

    var loadScriptCalls: [LoadScriptCall] = []
    var executeScriptCalls: [ExecuteScriptCall] = []
    var executeStepCalls: [ExecuteStepCall] = []

    var scriptsByPath: [String: PeekabooScript] = [:]
    var loadScriptProvider: ((String) async throws -> PeekabooScript)?
    var executeScriptProvider: ((PeekabooScript, Bool, Bool) async throws -> [StepResult])?
    var executeStepProvider: ((ScriptStep, String?) async throws -> StepExecutionResult)?

    var nextScript: PeekabooScript?
    var nextExecuteScriptResults: [StepResult]?
    var nextStepResult: StepExecutionResult?

    func loadScript(from path: String) async throws -> PeekabooScript {
        self.loadScriptCalls.append(LoadScriptCall(path: path))

        if let provider = self.loadScriptProvider {
            return try await provider(path)
        }

        if let script = self.scriptsByPath[path] ?? self.scriptsByPath["*"] {
            return script
        }

        if let script = self.nextScript {
            return script
        }

        throw TestStubError.unimplemented(#function)
    }

    func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool
    ) async throws -> [StepResult] {
        self.executeScriptCalls.append(ExecuteScriptCall(script: script, failFast: failFast, verbose: verbose))

        if let provider = self.executeScriptProvider {
            return try await provider(script, failFast, verbose)
        }

        if let results = self.nextExecuteScriptResults {
            return results
        }

        return []
    }

    func executeStep(
        _ step: ScriptStep,
        sessionId: String?
    ) async throws -> StepExecutionResult {
        self.executeStepCalls.append(ExecuteStepCall(step: step, sessionId: sessionId))

        if let provider = self.executeStepProvider {
            return try await provider(step, sessionId)
        }

        if let result = self.nextStepResult {
            return result
        }

        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubDockService: DockServiceProtocol {
    var items: [DockItem]
    var autoHidden: Bool

    init(items: [DockItem] = [], autoHidden: Bool = false) {
        self.items = items
        self.autoHidden = autoHidden
    }

    func listDockItems(includeAll: Bool) async throws -> [DockItem] {
        self.items
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
        self.autoHidden
    }

    func findDockItem(name: String) async throws -> DockItem {
        guard let match = self.items.first(where: { $0.title == name }) else {
            throw PeekabooError.elementNotFound(name)
        }
        return match
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
    var clickPathCalls: [(app: String, path: String)] = []
    var clickItemCalls: [(app: String, item: String)] = []
    var clickExtraCalls: [String] = []
    var listMenusRequests: [String] = []

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
        self.listMenusRequests.append(appIdentifier)
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
        guard self.menusByApp[app] != nil else {
            throw PeekabooError.menuNotFound(app)
        }
        self.clickPathCalls.append((app, itemPath))
    }

    func clickMenuItemByName(app: String, itemName: String) async throws {
        guard self.menusByApp[app] != nil else {
            throw PeekabooError.menuNotFound(app)
        }
        self.clickItemCalls.append((app, itemName))
    }

    func clickMenuExtra(title: String) async throws {
        guard self.menuExtras.contains(where: { $0.title == title }) else {
            throw PeekabooError.menuNotFound(title)
        }
        self.clickExtraCalls.append(title)
    }

    func listMenuExtras() async throws -> [MenuExtraInfo] {
        self.menuExtras
    }

    func listMenuBarItems() async throws -> [MenuBarItemInfo] {
        []
    }

    func clickMenuBarItem(named name: String) async throws -> PeekabooCore.ClickResult {
        throw TestStubError.unimplemented(#function)
    }

    func clickMenuBarItem(at index: Int) async throws -> PeekabooCore.ClickResult {
        throw TestStubError.unimplemented(#function)
    }
}

@MainActor
final class StubDialogService: DialogServiceProtocol {
    var dialogElements: DialogElements?
    var clickButtonResult: DialogActionResult?
    var handleFileDialogResult: DialogActionResult?
    var dismissResult: DialogActionResult?
    var enterTextResult: DialogActionResult?

    private(set) var recordedButtonClicks: [(button: String, window: String?)] = []

    init(elements: DialogElements? = nil) {
        self.dialogElements = elements
    }

    func findActiveDialog(windowTitle: String?, appName: String?) async throws -> DialogInfo {
        guard let elements = self.dialogElements else {
            throw PeekabooError.elementNotFound(windowTitle ?? "dialog")
        }
        return elements.dialogInfo
    }

    func clickButton(buttonText: String, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        self.recordedButtonClicks.append((buttonText, windowTitle))
        if let result = self.clickButtonResult {
            return result
        }
        throw PeekabooError.elementNotFound(buttonText)
    }

    func enterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?,
        appName: String?
    ) async throws -> DialogActionResult {
        if let result = self.enterTextResult {
            return result
        }
        throw PeekabooError.elementNotFound(fieldIdentifier ?? "field")
    }

    func handleFileDialog(
        path: String?,
        filename: String?,
        actionButton: String,
        appName: String?
    ) async throws -> DialogActionResult {
        if let result = self.handleFileDialogResult {
            return result
        }
        throw PeekabooError.elementNotFound(actionButton)
    }

    func dismissDialog(force: Bool, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        if let result = self.dismissResult {
            return result
        }
        throw PeekabooError.elementNotFound(windowTitle ?? "dialog")
    }

    func listDialogElements(windowTitle: String?, appName: String?) async throws -> DialogElements {
        guard let elements = self.dialogElements else {
            throw PeekabooError.elementNotFound(windowTitle ?? "dialog")
        }
        return elements
    }
}

@MainActor
final class StubWindowService: WindowManagementServiceProtocol {
    var windowsByApp: [String: [ServiceWindowInfo]]
    var focusCalls: [WindowTarget] = []

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
        try self.updateWindow(target: target) { info in
            let newBounds = CGRect(origin: position, size: info.bounds.size)
            return info.withBounds(newBounds)
        }
    }

    func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        try self.updateWindow(target: target) { info in
            let newBounds = CGRect(origin: info.bounds.origin, size: size)
            return info.withBounds(newBounds)
        }
    }

    func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        try self.updateWindow(target: target) { info in
            info.withBounds(bounds)
        }
    }

    func focusWindow(target: WindowTarget) async throws {
        self.focusCalls.append(target)
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
            return self.windowsByApp.values.flatMap(\.self).filter { $0.windowID == id }
        case let .title(title):
            return self.windowsByApp.values.flatMap(\.self).filter { $0.title.contains(title) }
        case let .index(app, index):
            guard let windows = self.windowsByApp[app], index < windows.count else { return [] }
            return [windows[index]]
        }
    }

    func getFocusedWindow() async throws -> ServiceWindowInfo? {
        nil
    }

    private func updateWindow(
        target: WindowTarget,
        transform: (ServiceWindowInfo) -> ServiceWindowInfo
    ) throws {
        let selection = try self.resolveWindowLocation(target: target)
        var windows = self.windowsByApp[selection.app] ?? []
        guard selection.index < windows.count else {
            throw PeekabooError.windowNotFound(criteria: selection.app)
        }
        let updated = transform(windows[selection.index])
        windows[selection.index] = updated
        self.windowsByApp[selection.app] = windows
    }

    private func resolveWindowLocation(target: WindowTarget) throws -> (app: String, index: Int) {
        switch target {
        case let .application(app):
            guard let windows = self.windowsByApp[app], !windows.isEmpty else {
                throw PeekabooError.windowNotFound(criteria: app)
            }
            return (app, 0)
        case let .applicationAndTitle(app, title):
            guard
                let windows = self.windowsByApp[app],
                let index = windows.firstIndex(where: { $0.title.localizedCaseInsensitiveContains(title) })
            else {
                throw PeekabooError.windowNotFound(criteria: "title contains \(title)")
            }
            return (app, index)
        case .frontmost:
            if let entry = self.windowsByApp.first(where: { !$0.value.isEmpty }) {
                return (entry.key, 0)
            }
            throw PeekabooError.windowNotFound(criteria: "frontmost")
        case let .windowId(id):
            for (app, windows) in self.windowsByApp {
                if let index = windows.firstIndex(where: { $0.windowID == id }) {
                    return (app, index)
                }
            }
            throw PeekabooError.windowNotFound(criteria: "windowId \(id)")
        case let .title(title):
            for (app, windows) in self.windowsByApp {
                if let index = windows.firstIndex(where: { $0.title.localizedCaseInsensitiveContains(title) }) {
                    return (app, index)
                }
            }
            throw PeekabooError.windowNotFound(criteria: "title contains \(title)")
        case let .index(app, index):
            guard let windows = self.windowsByApp[app], index < windows.count else {
                throw PeekabooError.windowNotFound(criteria: "index \(index) in \(app)")
            }
            return (app, index)
        }
    }
}

extension ServiceWindowInfo {
    fileprivate func withBounds(_ bounds: CGRect) -> ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: self.windowID,
            title: self.title,
            bounds: bounds,
            isMinimized: self.isMinimized,
            isMainWindow: self.isMainWindow,
            windowLevel: self.windowLevel,
            alpha: self.alpha,
            index: self.index,
            spaceID: self.spaceID,
            spaceName: self.spaceName,
            screenIndex: self.screenIndex,
            screenName: self.screenName
        )
    }
}

final class StubSpaceService: SpaceCommandSpaceService {
    var spaces: [SpaceInfo]
    var windowSpaces: [Int: [SpaceInfo]]
    var switchCalls: [CGSSpaceID] = []
    var moveWindowCalls: [(windowID: CGWindowID, spaceID: CGSSpaceID?)] = []
    var moveToCurrentCalls: [CGWindowID] = []

    init(spaces: [SpaceInfo], windowSpaces: [Int: [SpaceInfo]] = [:]) {
        self.spaces = spaces
        self.windowSpaces = windowSpaces
    }

    func getAllSpaces() async -> [SpaceInfo] {
        self.spaces
    }

    func getSpacesForWindow(windowID: CGWindowID) async -> [SpaceInfo] {
        self.windowSpaces[Int(windowID)] ?? []
    }

    func moveWindowToCurrentSpace(windowID: CGWindowID) async throws {
        self.moveToCurrentCalls.append(windowID)
    }

    func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) async throws {
        self.moveWindowCalls.append((windowID, spaceID))
    }

    func switchToSpace(_ spaceID: CGSSpaceID) async throws {
        self.switchCalls.append(spaceID)
    }
}

// MARK: - Aggregator

@MainActor
enum TestServicesFactory {
    static func makePeekabooServices(
        applications: ApplicationServiceProtocol = StubApplicationService(applications: []),
        windows: WindowManagementServiceProtocol = StubWindowService(windowsByApp: [:]),
        menu: MenuServiceProtocol = StubMenuService(menusByApp: [:]),
        dialogs: DialogServiceProtocol = StubDialogService(),
        dock: DockServiceProtocol = StubDockService(),
        sessions: SessionManagerProtocol = StubSessionManager(),
        files: FileServiceProtocol = StubFileService(),
        process: ProcessServiceProtocol = StubProcessService(),
        screens: [ScreenInfo] = [],
        automation: UIAutomationServiceProtocol = StubAutomationService(),
        screenCapture: ScreenCaptureServiceProtocol = StubScreenCaptureService()
    ) -> PeekabooServices {
        let screenService = StubScreenService(screens: screens)
        let services = PeekabooServices(
            logging: LoggingService(),
            screenCapture: screenCapture,
            applications: applications,
            automation: automation,
            windows: windows,
            menu: menu,
            dock: dock,
            dialogs: dialogs,
            sessions: sessions,
            files: files,
            process: process,
            permissions: PermissionsService(),
            audioInput: AudioInputService(aiService: PeekabooAIService()),
            agent: nil,
            configuration: ConfigurationManager.shared,
            screens: screenService
        )

        return services
    }

    @MainActor
    struct AutomationTestContext {
        let services: PeekabooServices
        let automation: StubAutomationService
        let sessions: StubSessionManager
    }

    static func makeAutomationTestContext(
        automation: StubAutomationService = StubAutomationService(),
        sessions: StubSessionManager = StubSessionManager(),
        applications: ApplicationServiceProtocol = StubApplicationService(applications: []),
        windows: WindowManagementServiceProtocol = StubWindowService(windowsByApp: [:]),
        menu: MenuServiceProtocol = StubMenuService(menusByApp: [:]),
        dialogs: DialogServiceProtocol = StubDialogService(),
        dock: DockServiceProtocol = StubDockService(),
        files: FileServiceProtocol = StubFileService(),
        process: ProcessServiceProtocol = StubProcessService(),
        screens: [ScreenInfo] = [],
        screenCapture: ScreenCaptureServiceProtocol = StubScreenCaptureService()
    ) -> AutomationTestContext {
        let services = self.makePeekabooServices(
            applications: applications,
            windows: windows,
            menu: menu,
            dialogs: dialogs,
            dock: dock,
            sessions: sessions,
            files: files,
            process: process,
            screens: screens,
            automation: automation,
            screenCapture: screenCapture
        )

        return AutomationTestContext(services: services, automation: automation, sessions: sessions)
    }
}
