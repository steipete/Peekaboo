import AsyncXPCConnection
import Foundation
import os.log
import PeekabooAutomation
import PeekabooFoundation

private struct UncheckedResponseHandler: @unchecked Sendable {
    let handler: (Data?, (any Error)?) -> Void
}

private typealias XPCReplyHandler = (Data?, (any Error)?) -> Void

public actor PeekabooXPCClient {
    private let remote: RemoteXPCService<any PeekabooXPCConnection>
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "boo.peekaboo.xpc", category: "client")
    private let throttler = XPCRequestThrottler(maxConcurrent: 4)

    public init(
        serviceName: String = PeekabooXPCConstants.serviceName,
        encoder: JSONEncoder = .peekabooXPCEncoder(),
        decoder: JSONDecoder = .peekabooXPCDecoder(),
        configure: ((NSXPCConnection) -> Void)? = nil)
    {
        let connection = NSXPCConnection(machServiceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface.peekabooXPCInterface()
        configure?(connection)
        connection.resume()

        self.remote = RemoteXPCService(connection: connection)
        self.encoder = encoder
        self.decoder = decoder
    }

    public init(
        endpoint: NSXPCListenerEndpoint,
        encoder: JSONEncoder = .peekabooXPCEncoder(),
        decoder: JSONDecoder = .peekabooXPCDecoder(),
        configure: ((NSXPCConnection) -> Void)? = nil)
    {
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface.peekabooXPCInterface()
        configure?(connection)
        connection.resume()

        self.remote = RemoteXPCService(connection: connection)
        self.encoder = encoder
        self.decoder = decoder
    }

    @discardableResult
    public func handshake(
        client: PeekabooXPCClientIdentity,
        requestedHost: PeekabooXPCHostKind? = nil,
        protocolVersion: PeekabooXPCProtocolVersion = PeekabooXPCConstants.protocolVersion)
        async throws -> PeekabooXPCHandshakeResponse
    {
        let payload = PeekabooXPCHandshake(
            protocolVersion: protocolVersion,
            client: client,
            requestedHostKind: requestedHost)
        let response = try await self.send(.handshake(payload))

        switch response {
        case let .handshake(handshake):
            return handshake
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected handshake response")
        }
    }

    public func permissionsStatus() async throws -> PermissionsStatus {
        let response = try await self.send(.permissionsStatus)
        switch response {
        case let .permissionsStatus(status):
            return status
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected permissions response")
        }
    }

    public func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let payload = PeekabooXPCCaptureScreenRequest(
            displayIndex: displayIndex,
            visualizerMode: visualizerMode,
            scale: scale)
        let response = try await self.send(.captureScreen(payload))
        return try Self.unwrapCapture(from: response)
    }

    public func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let payload = PeekabooXPCCaptureWindowRequest(
            appIdentifier: appIdentifier,
            windowIndex: windowIndex,
            visualizerMode: visualizerMode,
            scale: scale)
        let response = try await self.send(.captureWindow(payload))
        return try Self.unwrapCapture(from: response)
    }

    public func captureFrontmost(
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let payload = PeekabooXPCCaptureFrontmostRequest(visualizerMode: visualizerMode, scale: scale)
        let response = try await self.send(.captureFrontmost(payload))
        return try Self.unwrapCapture(from: response)
    }

    public func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let payload = PeekabooXPCCaptureAreaRequest(rect: rect, visualizerMode: visualizerMode, scale: scale)
        let response = try await self.send(.captureArea(payload))
        return try Self.unwrapCapture(from: response)
    }

    public func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        let payload = PeekabooXPCDetectElementsRequest(
            imageData: imageData,
            sessionId: sessionId,
            windowContext: windowContext)
        let response = try await self.send(.detectElements(payload))
        switch response {
        case let .elementDetection(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected detectElements response")
        }
    }

    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        let payload = PeekabooXPCClickRequest(target: target, clickType: clickType, sessionId: sessionId)
        try await self.sendExpectOK(.click(payload))
    }

    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        sessionId: String?) async throws
    {
        let payload = PeekabooXPCTypeRequest(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            sessionId: sessionId)
        try await self.sendExpectOK(.type(payload))
    }

    public func typeActions(
        _ actions: [TypeAction],
        cadence: TypingCadence,
        sessionId: String?) async throws -> TypeResult
    {
        let payload = PeekabooXPCTypeActionsRequest(actions: actions, cadence: cadence, sessionId: sessionId)
        let response = try await self.send(.typeActions(payload))
        switch response {
        case let .typeResult(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected typeActions response")
        }
    }

    public func scroll(_ request: ScrollRequest) async throws {
        try await self.sendExpectOK(.scroll(PeekabooXPCScrollRequest(request: request)))
    }

    public func hotkey(keys: String, holdDuration: Int) async throws {
        try await self.sendExpectOK(.hotkey(PeekabooXPCHotkeyRequest(keys: keys, holdDuration: holdDuration)))
    }

    public func swipe(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        let payload = PeekabooXPCSwipeRequest(from: from, to: to, duration: duration, steps: steps, profile: profile)
        try await self.sendExpectOK(.swipe(payload))
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
        let payload = PeekabooXPCDragRequest(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            modifiers: modifiers,
            profile: profile)
        try await self.sendExpectOK(.drag(payload))
    }

    // swiftlint:enable function_parameter_count

    public func moveMouse(
        to point: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        let payload = PeekabooXPCMoveMouseRequest(to: point, duration: duration, steps: steps, profile: profile)
        try await self.sendExpectOK(.moveMouse(payload))
    }

    public func waitForElement(target: ClickTarget, timeout: TimeInterval, sessionId: String?) async throws
        -> WaitForElementResult
    {
        let payload = PeekabooXPCWaitRequest(target: target, timeout: timeout, sessionId: sessionId)
        let response = try await self.send(.waitForElement(payload))
        switch response {
        case let .waitResult(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected waitForElement response")
        }
    }

    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        let response = try await self.send(.listWindows(PeekabooXPCWindowTargetRequest(target: target)))
        switch response {
        case let .windows(windows):
            return windows
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected listWindows response")
        }
    }

    public func focusWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.focusWindow(PeekabooXPCWindowTargetRequest(target: target)))
    }

    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        try await self.sendExpectOK(.moveWindow(PeekabooXPCWindowMoveRequest(target: target, position: position)))
    }

    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        try await self.sendExpectOK(.resizeWindow(PeekabooXPCWindowResizeRequest(target: target, size: size)))
    }

    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        try await self.sendExpectOK(.setWindowBounds(PeekabooXPCWindowBoundsRequest(target: target, bounds: bounds)))
    }

    public func closeWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.closeWindow(PeekabooXPCWindowTargetRequest(target: target)))
    }

    public func minimizeWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.minimizeWindow(PeekabooXPCWindowTargetRequest(target: target)))
    }

    public func maximizeWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.maximizeWindow(PeekabooXPCWindowTargetRequest(target: target)))
    }

    public func getFocusedWindow() async throws -> ServiceWindowInfo? {
        let response = try await self.send(.getFocusedWindow)
        switch response {
        case let .window(info):
            return info
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected getFocusedWindow response")
        }
    }

    public func listApplications() async throws -> [ServiceApplicationInfo] {
        let response = try await self.send(.listApplications)
        switch response {
        case let .applications(apps):
            return apps
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected listApplications response")
        }
    }

    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let response = try await self.send(.findApplication(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
        switch response {
        case let .application(app):
            return app
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected findApplication response")
        }
    }

    public func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        let response = try await self.send(.getFrontmostApplication)
        switch response {
        case let .application(app):
            return app
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected frontmost application response")
        }
    }

    public func isApplicationRunning(identifier: String) async throws -> Bool {
        let response = try await self
            .send(.isApplicationRunning(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
        switch response {
        case let .bool(running):
            return running
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected isApplicationRunning response")
        }
    }

    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let response = try await self.send(.launchApplication(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
        switch response {
        case let .application(app):
            return app
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected launchApplication response")
        }
    }

    public func activateApplication(identifier: String) async throws {
        try await self.sendExpectOK(.activateApplication(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
    }

    public func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        let payload = PeekabooXPCQuitAppRequest(identifier: identifier, force: force)
        let response = try await self.send(.quitApplication(payload))
        switch response {
        case let .bool(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected quitApplication response")
        }
    }

    public func hideApplication(identifier: String) async throws {
        try await self.sendExpectOK(.hideApplication(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
    }

    public func unhideApplication(identifier: String) async throws {
        try await self.sendExpectOK(.unhideApplication(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
    }

    public func hideOtherApplications(identifier: String) async throws {
        try await self.sendExpectOK(.hideOtherApplications(PeekabooXPCAppIdentifierRequest(identifier: identifier)))
    }

    public func showAllApplications() async throws {
        try await self.sendExpectOK(.showAllApplications)
    }

    // MARK: - Menus

    public func listMenus(appIdentifier: String) async throws -> MenuStructure {
        let response = try await self.send(.listMenus(PeekabooXPCMenuListRequest(appIdentifier: appIdentifier)))
        switch response {
        case let .menuStructure(structure): return structure
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected menu list response")
        }
    }

    public func listFrontmostMenus() async throws -> MenuStructure {
        let response = try await self.send(.listFrontmostMenus)
        switch response {
        case let .menuStructure(structure): return structure
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected menu list response")
        }
    }

    public func clickMenuItem(appIdentifier: String, itemPath: String) async throws {
        try await self.sendExpectOK(.clickMenuItem(PeekabooXPCMenuClickRequest(
            appIdentifier: appIdentifier,
            itemPath: itemPath)))
    }

    public func clickMenuItemByName(appIdentifier: String, itemName: String) async throws {
        try await self.sendExpectOK(.clickMenuItemByName(PeekabooXPCMenuClickByNameRequest(
            appIdentifier: appIdentifier,
            itemName: itemName)))
    }

    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        let response = try await self.send(.listMenuExtras)
        switch response {
        case let .menuExtras(extras): return extras
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected menu extras response")
        }
    }

    public func clickMenuExtra(title: String) async throws {
        try await self.sendExpectOK(.clickMenuExtra(PeekabooXPCMenuBarClickByNameRequest(name: title)))
    }

    public func listMenuBarItems(includeRaw: Bool) async throws -> [MenuBarItemInfo] {
        let response = try await self.send(.listMenuBarItems(includeRaw))
        switch response {
        case let .menuBarItems(items): return items
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected menu bar response")
        }
    }

    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        let response = try await self.send(.clickMenuBarItemNamed(PeekabooXPCMenuBarClickByNameRequest(name: name)))
        switch response {
        case let .clickResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected menu bar click response")
        }
    }

    public func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        let response = try await self.send(.clickMenuBarItemIndex(PeekabooXPCMenuBarClickByIndexRequest(index: index)))
        switch response {
        case let .clickResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected menu bar click response")
        }
    }

    // MARK: - Dock

    public func listDockItems(includeAll: Bool) async throws -> [DockItem] {
        let response = try await self.send(.listDockItems(PeekabooXPCDockListRequest(includeAll: includeAll)))
        switch response {
        case let .dockItems(items): return items
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dock list response")
        }
    }

    public func launchDockItem(appName: String) async throws {
        try await self.sendExpectOK(.launchDockItem(PeekabooXPCDockLaunchRequest(appName: appName)))
    }

    public func rightClickDockItem(appName: String, menuItem: String?) async throws {
        try await self.sendExpectOK(.rightClickDockItem(PeekabooXPCDockRightClickRequest(
            appName: appName,
            menuItem: menuItem)))
    }

    public func hideDock() async throws { try await self.sendExpectOK(.hideDock) }
    public func showDock() async throws { try await self.sendExpectOK(.showDock) }
    public func isDockHidden() async throws -> Bool {
        let response = try await self.send(.isDockHidden)
        switch response {
        case let .bool(value): return value
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dock state response")
        }
    }

    public func findDockItem(name: String) async throws -> DockItem {
        let response = try await self.send(.findDockItem(PeekabooXPCDockFindRequest(name: name)))
        switch response {
        case let .dockItem(item):
            if let item { return item }
            throw PeekabooXPCErrorEnvelope(code: .notFound, message: "Dock item not found")
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dock find response")
        }
    }

    // MARK: - Dialogs

    public func dialogFindActive(windowTitle: String?, appName: String?) async throws -> DialogInfo {
        let response = try await self.send(.dialogFindActive(PeekabooXPCDialogFindRequest(
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogInfo(info): return info
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog response")
        }
    }

    public func dialogClickButton(
        buttonText: String,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        let response = try await self.send(.dialogClickButton(PeekabooXPCDialogClickButtonRequest(
            buttonText: buttonText,
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogEnterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        let response = try await self.send(.dialogEnterText(PeekabooXPCDialogEnterTextRequest(
            text: text,
            fieldIdentifier: fieldIdentifier,
            clearExisting: clearExisting,
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogHandleFile(
        path: String?,
        filename: String?,
        actionButton: String,
        appName: String?) async throws -> DialogActionResult
    {
        let response = try await self.send(.dialogHandleFile(PeekabooXPCDialogHandleFileRequest(
            path: path,
            filename: filename,
            actionButton: actionButton,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogDismiss(force: Bool, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        let response = try await self.send(.dialogDismiss(PeekabooXPCDialogDismissRequest(
            force: force,
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogListElements(windowTitle: String?, appName: String?) async throws -> DialogElements {
        let response = try await self.send(.dialogListElements(PeekabooXPCDialogFindRequest(
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogElements(elements): return elements
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog elements response")
        }
    }

    // MARK: - Sessions

    public func createSession() async throws -> String {
        let response = try await self.send(.createSession(.init()))
        switch response {
        case let .sessionId(id): return id
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected createSession response")
        }
    }

    public func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        try await self.sendExpectOK(.storeDetectionResult(.init(sessionId: sessionId, result: result)))
    }

    public func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult {
        let response = try await self.send(.getDetectionResult(.init(sessionId: sessionId)))
        switch response {
        case let .detection(result): return result
        case let .error(envelope): throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected getDetectionResult response")
        }
    }

    public func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        try await self.sendExpectOK(
            .storeScreenshot(
                .init(
                    sessionId: sessionId,
                    screenshotPath: screenshotPath,
                    applicationName: applicationName,
                    windowTitle: windowTitle,
                    windowBounds: windowBounds)))
    }

    public func listSessions() async throws -> [SessionInfo] {
        let response = try await self.send(.listSessions)
        switch response {
        case let .sessions(list): return list
        case let .error(envelope): throw envelope
        default: throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected listSessions response")
        }
    }

    public func getMostRecentSession() async throws -> String {
        let response = try await self.send(.getMostRecentSession)
        switch response {
        case let .sessionId(id): return id
        case let .error(envelope): throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected getMostRecentSession response")
        }
    }

    public func cleanSession(sessionId: String) async throws {
        try await self.sendExpectOK(.cleanSession(.init(sessionId: sessionId)))
    }

    public func cleanSessionsOlderThan(days: Int) async throws -> Int {
        let response = try await self.send(.cleanSessionsOlderThan(.init(days: days)))
        switch response {
        case let .int(count): return count
        case let .error(envelope): throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected cleanSessionsOlderThan response")
        }
    }

    public func cleanAllSessions() async throws -> Int {
        let response = try await self.send(.cleanAllSessions)
        switch response {
        case let .int(count): return count
        case let .error(envelope): throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected cleanAllSessions response")
        }
    }

    // MARK: - Private

    private func send(_ request: PeekabooXPCRequest) async throws -> PeekabooXPCResponse {
        let payload = try self.encoder.encode(request)
        let op = request.operation
        let start = Date()
        self.logger.debug("Sending XPC request \(op.rawValue, privacy: .public)")

        await self.throttler.acquire()
        let response: PeekabooXPCResponse
        do {
            response = try await self.remote.withDecodingCompletion(using: self.decoder)
            { (service: any PeekabooXPCConnection, handler: @escaping XPCReplyHandler) in
                let boxed = UncheckedResponseHandler(handler: handler)
                service.send(payload, withReply: { data, error in
                    boxed.handler(data, error)
                })
            }
        } catch {
            await self.throttler.release()
            throw error
        }
        await self.throttler.release()
        let duration = Date().timeIntervalSince(start)
        self.logger
            .debug("XPC \(op.rawValue, privacy: .public) completed in \(duration, format: .fixed(precision: 3))s")
        return response
    }

    private func sendExpectOK(_ request: PeekabooXPCRequest) async throws {
        let response = try await self.send(request)
        switch response {
        case .ok:
            return
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected response for void request")
        }
    }

    private static func unwrapCapture(from response: PeekabooXPCResponse) throws -> CaptureResult {
        switch response {
        case let .capture(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooXPCErrorEnvelope(code: .invalidRequest, message: "Unexpected capture response")
        }
    }
}

private actor XPCRequestThrottler {
    private let maxConcurrent: Int
    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }

    func acquire() async {
        if self.inFlight >= self.maxConcurrent {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.waiters.append(continuation)
            }
        }
        self.inFlight += 1
    }

    func release() {
        self.inFlight -= 1
        if let waiter = self.waiters.first {
            self.waiters.removeFirst()
            waiter.resume()
        }
    }
}
