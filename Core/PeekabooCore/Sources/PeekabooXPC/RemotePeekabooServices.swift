import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooFoundation

@MainActor
public final class RemoteScreenCaptureService: ScreenCaptureServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        try await self.client.captureScreen(displayIndex: displayIndex, visualizerMode: visualizerMode, scale: scale)
    }

    public func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        try await self.client.captureWindow(
            appIdentifier: appIdentifier,
            windowIndex: windowIndex,
            visualizerMode: visualizerMode,
            scale: scale)
    }

    public func captureFrontmost(
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        try await self.client.captureFrontmost(visualizerMode: visualizerMode, scale: scale)
    }

    public func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        try await self.client.captureArea(rect, visualizerMode: visualizerMode, scale: scale)
    }

    public func hasScreenRecordingPermission() async -> Bool {
        do {
            let status = try await self.client.permissionsStatus()
            return status.screenRecording
        } catch {
            return false
        }
    }
}

@MainActor
public final class RemoteUIAutomationService: UIAutomationServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        try await self.client.detectElements(in: imageData, sessionId: sessionId, windowContext: windowContext)
    }

    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        try await self.client.click(target: target, clickType: clickType, sessionId: sessionId)
    }

    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        sessionId: String?) async throws
    {
        try await self.client.type(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            sessionId: sessionId)
    }

    public func typeActions(
        _ actions: [TypeAction],
        cadence: TypingCadence,
        sessionId: String?) async throws -> TypeResult
    {
        try await self.client.typeActions(actions, cadence: cadence, sessionId: sessionId)
    }

    public func scroll(_ request: ScrollRequest) async throws {
        try await self.client.scroll(request)
    }

    public func hotkey(keys: String, holdDuration: Int) async throws {
        try await self.client.hotkey(keys: keys, holdDuration: holdDuration)
    }

    public func swipe(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        try await self.client.swipe(from: from, to: to, duration: duration, steps: steps, profile: profile)
    }

    public func hasAccessibilityPermission() async -> Bool {
        do {
            let status = try await self.client.permissionsStatus()
            return status.accessibility
        } catch {
            return false
        }
    }

    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?) async throws -> WaitForElementResult
    {
        try await self.client.waitForElement(target: target, timeout: timeout, sessionId: sessionId)
    }

    // swiftlint:disable function_parameter_count
    public func drag(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        modifiers: String?,
        profile: MouseMovementProfile) async throws
    {
        try await self.client.drag(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            modifiers: modifiers,
            profile: profile)
    }

    // swiftlint:enable function_parameter_count

    public func moveMouse(to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws {
        try await self.client.moveMouse(to: to, duration: duration, steps: steps, profile: profile)
    }

    public func getFocusedElement() -> UIFocusInfo? {
        // Not yet implemented over XPC; fall back to nil to avoid blocking callers.
        nil
    }

    public func findElement(matching criteria: UIElementSearchCriteria, in appName: String?) async throws
        -> DetectedElement
    {
        // Currently unsupported over XPC; this path is rarely used by CLI.
        throw PeekabooError.operationError(message: "findElement is not available over XPC yet")
    }
}

@MainActor
public final class RemoteWindowManagementService: WindowManagementServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func closeWindow(target: WindowTarget) async throws {
        try await self.client.closeWindow(target: target)
    }

    public func minimizeWindow(target: WindowTarget) async throws {
        try await self.client.minimizeWindow(target: target)
    }

    public func maximizeWindow(target: WindowTarget) async throws {
        try await self.client.maximizeWindow(target: target)
    }

    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        try await self.client.moveWindow(target: target, to: position)
    }

    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        try await self.client.resizeWindow(target: target, to: size)
    }

    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        try await self.client.setWindowBounds(target: target, bounds: bounds)
    }

    public func focusWindow(target: WindowTarget) async throws {
        try await self.client.focusWindow(target: target)
    }

    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        try await self.client.listWindows(target: target)
    }

    public func getFocusedWindow() async throws -> ServiceWindowInfo? {
        try await self.client.getFocusedWindow()
    }
}

@MainActor
public final class RemoteMenuService: MenuServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func listMenus(for appIdentifier: String) async throws -> MenuStructure {
        try await self.client.listMenus(appIdentifier: appIdentifier)
    }

    public func listFrontmostMenus() async throws -> MenuStructure {
        try await self.client.listFrontmostMenus()
    }

    public func clickMenuItem(app: String, itemPath: String) async throws {
        try await self.client.clickMenuItem(appIdentifier: app, itemPath: itemPath)
    }

    public func clickMenuItemByName(app: String, itemName: String) async throws {
        try await self.client.clickMenuItemByName(appIdentifier: app, itemName: itemName)
    }

    public func clickMenuExtra(title: String) async throws {
        try await self.client.clickMenuExtra(title: title)
    }

    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        try await self.client.listMenuExtras()
    }

    public func listMenuBarItems(includeRaw: Bool) async throws -> [MenuBarItemInfo] {
        try await self.client.listMenuBarItems(includeRaw: includeRaw)
    }

    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        try await self.client.clickMenuBarItem(named: name)
    }

    public func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        try await self.client.clickMenuBarItem(at: index)
    }
}

@MainActor
public final class RemoteDockService: DockServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func listDockItems(includeAll: Bool) async throws -> [DockItem] {
        try await self.client.listDockItems(includeAll: includeAll)
    }

    public func launchFromDock(appName: String) async throws {
        try await self.client.launchDockItem(appName: appName)
    }

    public func addToDock(path _: String, persistent _: Bool) async throws {
        throw PeekabooError.operationError(message: "addToDock not available via XPC")
    }

    public func removeFromDock(appName _: String) async throws {
        throw PeekabooError.operationError(message: "removeFromDock not available via XPC")
    }

    public func rightClickDockItem(appName: String, menuItem: String?) async throws {
        try await self.client.rightClickDockItem(appName: appName, menuItem: menuItem)
    }

    public func hideDock() async throws { try await self.client.hideDock() }

    public func showDock() async throws { try await self.client.showDock() }

    public func isDockAutoHidden() async -> Bool {
        await (try? self.client.isDockHidden()) ?? false
    }

    public func findDockItem(name: String) async throws -> DockItem {
        try await self.client.findDockItem(name: name)
    }
}

@MainActor
public final class RemoteDialogService: DialogServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func findActiveDialog(windowTitle: String?, appName: String?) async throws -> DialogInfo {
        try await self.client.dialogFindActive(windowTitle: windowTitle, appName: appName)
    }

    public func clickButton(buttonText: String, windowTitle: String?, appName: String?) async throws
        -> DialogActionResult
    {
        try await self.client.dialogClickButton(buttonText: buttonText, windowTitle: windowTitle, appName: appName)
    }

    public func enterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        try await self.client.dialogEnterText(
            text: text,
            fieldIdentifier: fieldIdentifier,
            clearExisting: clearExisting,
            windowTitle: windowTitle,
            appName: appName)
    }

    public func handleFileDialog(path: String?, filename: String?, actionButton: String, appName: String?) async throws
        -> DialogActionResult
    {
        try await self.client.dialogHandleFile(
            path: path,
            filename: filename,
            actionButton: actionButton,
            appName: appName)
    }

    public func dismissDialog(force: Bool, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        try await self.client.dialogDismiss(force: force, windowTitle: windowTitle, appName: appName)
    }

    public func listDialogElements(windowTitle: String?, appName: String?) async throws -> DialogElements {
        try await self.client.dialogListElements(windowTitle: windowTitle, appName: appName)
    }
}

@MainActor
public final class RemoteSessionManager: SessionManagerProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func createSession() async throws -> String {
        try await self.client.createSession()
    }

    public func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        try await self.client.storeDetectionResult(sessionId: sessionId, result: result)
    }

    public func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        do {
            return try await self.client.getDetectionResult(sessionId: sessionId)
        } catch let envelope as PeekabooXPCErrorEnvelope where envelope.code == .notFound {
            return nil
        }
    }

    public func getMostRecentSession() async -> String? {
        await (try? self.client.getMostRecentSession())
    }

    public func listSessions() async throws -> [SessionInfo] {
        try await self.client.listSessions()
    }

    public func cleanSession(sessionId: String) async throws {
        try await self.client.cleanSession(sessionId: sessionId)
    }

    public func cleanSessionsOlderThan(days: Int) async throws -> Int {
        try await self.client.cleanSessionsOlderThan(days: days)
    }

    public func cleanAllSessions() async throws -> Int {
        try await self.client.cleanAllSessions()
    }

    public func getSessionStoragePath() -> String {
        // Remote side owns the storage; expose helper-visible path to callers when needed.
        SessionManager().getSessionStoragePath()
    }

    public func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        try await self.client.storeScreenshot(
            sessionId: sessionId,
            screenshotPath: screenshotPath,
            applicationName: applicationName,
            windowTitle: windowTitle,
            windowBounds: windowBounds)
    }

    public func getElement(sessionId: String, elementId: String) async throws -> UIElement? {
        // Not exposed over XPC; rely on detection results.
        _ = sessionId
        _ = elementId
        return nil
    }

    public func findElements(sessionId: String, matching query: String) async throws -> [UIElement] {
        // Not exposed over XPC yet.
        _ = sessionId
        _ = query
        return []
    }

    public func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        // Not exposed over XPC; could be added later.
        _ = sessionId
        return nil
    }
}

@MainActor
public final class RemoteApplicationService: ApplicationServiceProtocol {
    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client
    }

    public func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        let apps = try await self.client.listApplications()
        return UnifiedToolOutput(
            data: ServiceApplicationListData(applications: apps),
            summary: .init(brief: "Found \(apps.count) apps", status: .success, counts: ["applications": apps.count]),
            metadata: .init(duration: 0))
    }

    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await self.client.findApplication(identifier: identifier)
    }

    public func listWindows(for appIdentifier: String, timeout: Float?) async throws
        -> UnifiedToolOutput<ServiceWindowListData>
    {
        // Reuse window listing filtered by application via WindowTarget.application
        let windows = try await self.client.listWindows(target: .application(appIdentifier))
        let data = ServiceWindowListData(windows: windows, targetApplication: nil)
        return UnifiedToolOutput(
            data: data,
            summary: .init(
                brief: "Found \(windows.count) windows",
                status: .success,
                counts: ["windows": windows.count]),
            metadata: .init(duration: 0))
    }

    public func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        try await self.client.getFrontmostApplication()
    }

    public func isApplicationRunning(identifier: String) async -> Bool {
        await (try? self.client.isApplicationRunning(identifier: identifier)) ?? false
    }

    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await self.client.launchApplication(identifier: identifier)
    }

    public func activateApplication(identifier: String) async throws {
        try await self.client.activateApplication(identifier: identifier)
    }

    public func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        try await self.client.quitApplication(identifier: identifier, force: force)
    }

    public func hideApplication(identifier: String) async throws {
        try await self.client.hideApplication(identifier: identifier)
    }

    public func unhideApplication(identifier: String) async throws {
        try await self.client.unhideApplication(identifier: identifier)
    }

    public func hideOtherApplications(identifier: String) async throws {
        try await self.client.hideOtherApplications(identifier: identifier)
    }

    public func showAllApplications() async throws {
        try await self.client.showAllApplications()
    }
}

@MainActor
public final class RemotePeekabooServices: PeekabooServiceProviding {
    public let logging: any LoggingServiceProtocol
    public let screenCapture: any ScreenCaptureServiceProtocol
    public let applications: any ApplicationServiceProtocol
    public let automation: any UIAutomationServiceProtocol
    public let windows: any WindowManagementServiceProtocol
    public let menu: any MenuServiceProtocol
    public let dock: any DockServiceProtocol
    public let dialogs: any DialogServiceProtocol
    public let sessions: any SessionManagerProtocol
    public let files: any FileServiceProtocol
    public let clipboard: any ClipboardServiceProtocol
    public let configuration: ConfigurationManager
    public let process: any ProcessServiceProtocol
    public let permissions: PermissionsService
    public let audioInput: AudioInputService
    public let screens: any ScreenServiceProtocol
    public let agent: (any AgentServiceProtocol)?

    private let client: PeekabooXPCClient

    public init(client: PeekabooXPCClient) {
        self.client = client

        self.logging = LoggingService()
        self.screenCapture = RemoteScreenCaptureService(client: client)
        self.applications = RemoteApplicationService(client: client)
        self.automation = RemoteUIAutomationService(client: client)
        self.windows = RemoteWindowManagementService(client: client)
        let sessionManager = RemoteSessionManager(client: client)

        self.menu = RemoteMenuService(client: client)
        self.dock = RemoteDockService(client: client)
        self.dialogs = RemoteDialogService(client: client)
        self.sessions = sessionManager
        self.files = FileService()
        self.clipboard = ClipboardService()
        self.configuration = ConfigurationManager.shared
        self.process = ProcessService(
            applicationService: self.applications,
            screenCaptureService: self.screenCapture,
            sessionManager: sessionManager,
            uiAutomationService: self.automation,
            windowManagementService: self.windows,
            menuService: self.menu,
            dockService: self.dock)
        self.permissions = PermissionsService()
        self.audioInput = AudioInputService(aiService: PeekabooAIService())
        self.screens = ScreenService()
        self.agent = nil
    }

    public func ensureVisualizerConnection() {
        // Remote helper already holds TCC; no-op for client-side container.
    }
}
