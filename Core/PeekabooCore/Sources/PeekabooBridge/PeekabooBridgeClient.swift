import Darwin
import Foundation
import os.log
import PeekabooAutomationKit
import PeekabooFoundation

public actor PeekabooBridgeClient {
    private let socketPath: String
    private let maxResponseBytes: Int
    private let requestTimeoutSec: TimeInterval
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "boo.peekaboo.bridge", category: "client")

    public init(
        socketPath: String = PeekabooBridgeConstants.peekabooSocketPath,
        maxResponseBytes: Int = 64 * 1024 * 1024,
        requestTimeoutSec: TimeInterval = 10,
        encoder: JSONEncoder = .peekabooBridgeEncoder(),
        decoder: JSONDecoder = .peekabooBridgeDecoder())
    {
        self.socketPath = socketPath
        self.maxResponseBytes = maxResponseBytes
        self.requestTimeoutSec = requestTimeoutSec
        self.encoder = encoder
        self.decoder = decoder
    }

    @discardableResult
    public func handshake(
        client: PeekabooBridgeClientIdentity,
        requestedHost: PeekabooBridgeHostKind? = nil,
        protocolVersion: PeekabooBridgeProtocolVersion = PeekabooBridgeConstants.protocolVersion)
        async throws -> PeekabooBridgeHandshakeResponse
    {
        let payload = PeekabooBridgeHandshake(
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
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected handshake response")
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
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected permissions response")
        }
    }

    public func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let payload = PeekabooBridgeCaptureScreenRequest(
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
        let payload = PeekabooBridgeCaptureWindowRequest(
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
        let payload = PeekabooBridgeCaptureFrontmostRequest(visualizerMode: visualizerMode, scale: scale)
        let response = try await self.send(.captureFrontmost(payload))
        return try Self.unwrapCapture(from: response)
    }

    public func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let payload = PeekabooBridgeCaptureAreaRequest(rect: rect, visualizerMode: visualizerMode, scale: scale)
        let response = try await self.send(.captureArea(payload))
        return try Self.unwrapCapture(from: response)
    }

    public func detectElements(
        in imageData: Data,
        snapshotId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        let payload = PeekabooBridgeDetectElementsRequest(
            imageData: imageData,
            snapshotId: snapshotId,
            windowContext: windowContext)
        let response = try await self.send(.detectElements(payload))
        switch response {
        case let .elementDetection(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected detectElements response")
        }
    }

    public func click(target: ClickTarget, clickType: ClickType, snapshotId: String?) async throws {
        let payload = PeekabooBridgeClickRequest(target: target, clickType: clickType, snapshotId: snapshotId)
        try await self.sendExpectOK(.click(payload))
    }

    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        snapshotId: String?) async throws
    {
        let payload = PeekabooBridgeTypeRequest(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            snapshotId: snapshotId)
        try await self.sendExpectOK(.type(payload))
    }

    public func typeActions(
        _ actions: [TypeAction],
        cadence: TypingCadence,
        snapshotId: String?) async throws -> TypeResult
    {
        let payload = PeekabooBridgeTypeActionsRequest(actions: actions, cadence: cadence, snapshotId: snapshotId)
        let response = try await self.send(.typeActions(payload))
        switch response {
        case let .typeResult(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected typeActions response")
        }
    }

    public func scroll(_ request: ScrollRequest) async throws {
        try await self.sendExpectOK(.scroll(PeekabooBridgeScrollRequest(request: request)))
    }

    public func hotkey(keys: String, holdDuration: Int) async throws {
        try await self.sendExpectOK(.hotkey(PeekabooBridgeHotkeyRequest(keys: keys, holdDuration: holdDuration)))
    }

    public func swipe(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        let payload = PeekabooBridgeSwipeRequest(from: from, to: to, duration: duration, steps: steps, profile: profile)
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
        let payload = PeekabooBridgeDragRequest(
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
        let payload = PeekabooBridgeMoveMouseRequest(to: point, duration: duration, steps: steps, profile: profile)
        try await self.sendExpectOK(.moveMouse(payload))
    }

    public func waitForElement(target: ClickTarget, timeout: TimeInterval, snapshotId: String?) async throws
        -> WaitForElementResult
    {
        let payload = PeekabooBridgeWaitRequest(target: target, timeout: timeout, snapshotId: snapshotId)
        let response = try await self.send(.waitForElement(payload))
        switch response {
        case let .waitResult(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected waitForElement response")
        }
    }

    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        let response = try await self.send(.listWindows(PeekabooBridgeWindowTargetRequest(target: target)))
        switch response {
        case let .windows(windows):
            return windows
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected listWindows response")
        }
    }

    public func focusWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.focusWindow(PeekabooBridgeWindowTargetRequest(target: target)))
    }

    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        try await self.sendExpectOK(.moveWindow(PeekabooBridgeWindowMoveRequest(target: target, position: position)))
    }

    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        try await self.sendExpectOK(.resizeWindow(PeekabooBridgeWindowResizeRequest(target: target, size: size)))
    }

    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        try await self.sendExpectOK(.setWindowBounds(PeekabooBridgeWindowBoundsRequest(target: target, bounds: bounds)))
    }

    public func closeWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.closeWindow(PeekabooBridgeWindowTargetRequest(target: target)))
    }

    public func minimizeWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.minimizeWindow(PeekabooBridgeWindowTargetRequest(target: target)))
    }

    public func maximizeWindow(target: WindowTarget) async throws {
        try await self.sendExpectOK(.maximizeWindow(PeekabooBridgeWindowTargetRequest(target: target)))
    }

    public func getFocusedWindow() async throws -> ServiceWindowInfo? {
        let response = try await self.send(.getFocusedWindow)
        switch response {
        case let .window(info):
            return info
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected getFocusedWindow response")
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
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected listApplications response")
        }
    }

    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let response = try await self.send(.findApplication(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
        switch response {
        case let .application(app):
            return app
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected findApplication response")
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
            throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected frontmost application response")
        }
    }

    public func isApplicationRunning(identifier: String) async throws -> Bool {
        let response = try await self
            .send(.isApplicationRunning(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
        switch response {
        case let .bool(running):
            return running
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected isApplicationRunning response")
        }
    }

    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let response = try await self
            .send(.launchApplication(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
        switch response {
        case let .application(app):
            return app
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected launchApplication response")
        }
    }

    public func activateApplication(identifier: String) async throws {
        try await self.sendExpectOK(.activateApplication(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
    }

    public func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        let payload = PeekabooBridgeQuitAppRequest(identifier: identifier, force: force)
        let response = try await self.send(.quitApplication(payload))
        switch response {
        case let .bool(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected quitApplication response")
        }
    }

    public func hideApplication(identifier: String) async throws {
        try await self.sendExpectOK(.hideApplication(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
    }

    public func unhideApplication(identifier: String) async throws {
        try await self.sendExpectOK(.unhideApplication(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
    }

    public func hideOtherApplications(identifier: String) async throws {
        try await self.sendExpectOK(.hideOtherApplications(PeekabooBridgeAppIdentifierRequest(identifier: identifier)))
    }

    public func showAllApplications() async throws {
        try await self.sendExpectOK(.showAllApplications)
    }

    // MARK: - Menus

    public func listMenus(appIdentifier: String) async throws -> MenuStructure {
        let response = try await self.send(.listMenus(PeekabooBridgeMenuListRequest(appIdentifier: appIdentifier)))
        switch response {
        case let .menuStructure(structure): return structure
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected menu list response")
        }
    }

    public func listFrontmostMenus() async throws -> MenuStructure {
        let response = try await self.send(.listFrontmostMenus)
        switch response {
        case let .menuStructure(structure): return structure
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected menu list response")
        }
    }

    public func clickMenuItem(appIdentifier: String, itemPath: String) async throws {
        try await self.sendExpectOK(.clickMenuItem(PeekabooBridgeMenuClickRequest(
            appIdentifier: appIdentifier,
            itemPath: itemPath)))
    }

    public func clickMenuItemByName(appIdentifier: String, itemName: String) async throws {
        try await self.sendExpectOK(.clickMenuItemByName(PeekabooBridgeMenuClickByNameRequest(
            appIdentifier: appIdentifier,
            itemName: itemName)))
    }

    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        let response = try await self.send(.listMenuExtras)
        switch response {
        case let .menuExtras(extras): return extras
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected menu extras response")
        }
    }

    public func clickMenuExtra(title: String) async throws {
        try await self.sendExpectOK(.clickMenuExtra(PeekabooBridgeMenuBarClickByNameRequest(name: title)))
    }

    public func listMenuBarItems(includeRaw: Bool) async throws -> [MenuBarItemInfo] {
        let response = try await self.send(.listMenuBarItems(includeRaw))
        switch response {
        case let .menuBarItems(items): return items
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected menu bar response")
        }
    }

    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        let response = try await self.send(.clickMenuBarItemNamed(PeekabooBridgeMenuBarClickByNameRequest(name: name)))
        switch response {
        case let .clickResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected menu bar click response")
        }
    }

    public func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        let response = try await self
            .send(.clickMenuBarItemIndex(PeekabooBridgeMenuBarClickByIndexRequest(index: index)))
        switch response {
        case let .clickResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected menu bar click response")
        }
    }

    // MARK: - Dock

    public func listDockItems(includeAll: Bool) async throws -> [DockItem] {
        let response = try await self.send(.listDockItems(PeekabooBridgeDockListRequest(includeAll: includeAll)))
        switch response {
        case let .dockItems(items): return items
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dock list response")
        }
    }

    public func launchDockItem(appName: String) async throws {
        try await self.sendExpectOK(.launchDockItem(PeekabooBridgeDockLaunchRequest(appName: appName)))
    }

    public func rightClickDockItem(appName: String, menuItem: String?) async throws {
        try await self.sendExpectOK(.rightClickDockItem(PeekabooBridgeDockRightClickRequest(
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
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dock state response")
        }
    }

    public func findDockItem(name: String) async throws -> DockItem {
        let response = try await self.send(.findDockItem(PeekabooBridgeDockFindRequest(name: name)))
        switch response {
        case let .dockItem(item):
            if let item { return item }
            throw PeekabooBridgeErrorEnvelope(code: .notFound, message: "Dock item not found")
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dock find response")
        }
    }

    // MARK: - Dialogs

    public func dialogFindActive(windowTitle: String?, appName: String?) async throws -> DialogInfo {
        let response = try await self.send(.dialogFindActive(PeekabooBridgeDialogFindRequest(
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogInfo(info): return info
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog response")
        }
    }

    public func dialogClickButton(
        buttonText: String,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        let response = try await self.send(.dialogClickButton(PeekabooBridgeDialogClickButtonRequest(
            buttonText: buttonText,
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogEnterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        let response = try await self.send(.dialogEnterText(PeekabooBridgeDialogEnterTextRequest(
            text: text,
            fieldIdentifier: fieldIdentifier,
            clearExisting: clearExisting,
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogHandleFile(
        path: String?,
        filename: String?,
        actionButton: String,
        appName: String?) async throws -> DialogActionResult
    {
        let response = try await self.send(.dialogHandleFile(PeekabooBridgeDialogHandleFileRequest(
            path: path,
            filename: filename,
            actionButton: actionButton,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogDismiss(force: Bool, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        let response = try await self.send(.dialogDismiss(PeekabooBridgeDialogDismissRequest(
            force: force,
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogResult(result): return result
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected dialog result")
        }
    }

    public func dialogListElements(windowTitle: String?, appName: String?) async throws -> DialogElements {
        let response = try await self.send(.dialogListElements(PeekabooBridgeDialogFindRequest(
            windowTitle: windowTitle,
            appName: appName)))
        switch response {
        case let .dialogElements(elements): return elements
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected dialog elements response")
        }
    }

    // MARK: - Snapshots

    public func createSnapshot() async throws -> String {
        let response = try await self.send(.createSnapshot(.init()))
        switch response {
        case let .snapshotId(id): return id
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected createSnapshot response")
        }
    }

    public func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        try await self.sendExpectOK(.storeDetectionResult(.init(snapshotId: snapshotId, result: result)))
    }

    public func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult {
        let response = try await self.send(.getDetectionResult(.init(snapshotId: snapshotId)))
        switch response {
        case let .detection(result): return result
        case let .error(envelope): throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected getDetectionResult response")
        }
    }

    public func storeScreenshot(
        snapshotId: String,
        screenshotPath: String,
        applicationBundleId: String?,
        applicationProcessId: Int32?,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        try await self.sendExpectOK(
            .storeScreenshot(
                .init(
                    snapshotId: snapshotId,
                    screenshotPath: screenshotPath,
                    applicationBundleId: applicationBundleId,
                    applicationProcessId: applicationProcessId,
                    applicationName: applicationName,
                    windowTitle: windowTitle,
                    windowBounds: windowBounds)))
    }

    public func storeAnnotatedScreenshot(snapshotId: String, annotatedScreenshotPath: String) async throws {
        try await self.sendExpectOK(
            .storeAnnotatedScreenshot(
                .init(
                    snapshotId: snapshotId,
                    annotatedScreenshotPath: annotatedScreenshotPath)))
    }

    public func listSnapshots() async throws -> [SnapshotInfo] {
        let response = try await self.send(.listSnapshots)
        switch response {
        case let .snapshots(list): return list
        case let .error(envelope): throw envelope
        default: throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected listSnapshots response")
        }
    }

    public func getMostRecentSnapshot(applicationBundleId: String? = nil) async throws -> String {
        let response = try await self.send(.getMostRecentSnapshot(.init(applicationBundleId: applicationBundleId)))
        switch response {
        case let .snapshotId(id): return id
        case let .error(envelope): throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected getMostRecentSnapshot response")
        }
    }

    public func cleanSnapshot(snapshotId: String) async throws {
        try await self.sendExpectOK(.cleanSnapshot(.init(snapshotId: snapshotId)))
    }

    public func cleanSnapshotsOlderThan(days: Int) async throws -> Int {
        let response = try await self.send(.cleanSnapshotsOlderThan(.init(days: days)))
        switch response {
        case let .int(count): return count
        case let .error(envelope): throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected cleanSnapshotsOlderThan response")
        }
    }

    public func cleanAllSnapshots() async throws -> Int {
        let response = try await self.send(.cleanAllSnapshots)
        switch response {
        case let .int(count): return count
        case let .error(envelope): throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected cleanAllSnapshots response")
        }
    }

    public func appleScriptProbe() async throws {
        try await self.sendExpectOK(.appleScriptProbe)
    }

    // MARK: - Private

    private func send(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        let payload = try self.encoder.encode(request)
        let op = request.operation
        let start = Date()
        self.logger.debug("Sending bridge request \(op.rawValue, privacy: .public)")

        let socketPath = self.socketPath
        let maxResponseBytes = self.maxResponseBytes
        let requestTimeoutSec = self.requestTimeoutSec
        let responseData = try await Task.detached(priority: .userInitiated) {
            try Self.sendBlocking(
                socketPath: socketPath,
                requestData: payload,
                maxResponseBytes: maxResponseBytes,
                timeoutSec: requestTimeoutSec)
        }.value

        let response = try self.decoder.decode(PeekabooBridgeResponse.self, from: responseData)
        let duration = Date().timeIntervalSince(start)
        self.logger.debug(
            "bridge \(op.rawValue, privacy: .public) completed in \(duration, format: .fixed(precision: 3))s")
        return response
    }

    private func sendExpectOK(_ request: PeekabooBridgeRequest) async throws {
        let response = try await self.send(request)
        switch response {
        case .ok:
            return
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected response for void request")
        }
    }

    private static func unwrapCapture(from response: PeekabooBridgeResponse) throws -> CaptureResult {
        switch response {
        case let .capture(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected capture response")
        }
    }

    private nonisolated static func disableSigPipe(fd: Int32) {
        var one: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
    }

    private nonisolated static func sendBlocking(
        socketPath: String,
        requestData: Data,
        maxResponseBytes: Int,
        timeoutSec: TimeInterval) throws -> Data
    {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }

        Self.disableSigPipe(fd: fd)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        let copied = socketPath.withCString { cstr -> Int in
            strlcpy(&addr.sun_path.0, cstr, capacity)
        }
        guard copied < capacity else { throw POSIXError(.ENAMETOOLONG) }
        addr.sun_len = UInt8(MemoryLayout.size(ofValue: addr))

        let len = socklen_t(MemoryLayout.size(ofValue: addr))
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            connect(fd, UnsafePointer<sockaddr>(OpaquePointer(ptr)), len)
        }
        guard connectResult == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .ECONNREFUSED) }

        try Self.writeAll(fd: fd, data: requestData)
        _ = shutdown(fd, SHUT_WR)

        return try Self.readAll(fd: fd, maxBytes: maxResponseBytes, timeoutSec: timeoutSec)
    }

    private nonisolated static func writeAll(fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            var written = 0
            while written < data.count {
                let n = write(fd, base.advanced(by: written), data.count - written)
                if n > 0 {
                    written += n
                    continue
                }
                if n == -1, errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
    }

    private nonisolated static func readAll(fd: Int32, maxBytes: Int, timeoutSec: TimeInterval) throws -> Data {
        let deadline = Date().addingTimeInterval(timeoutSec)
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)

        while true {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                throw POSIXError(.ETIMEDOUT)
            }

            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let sliceMs = max(1.0, min(remaining, 0.25) * 1000.0)
            let polled = poll(&pfd, 1, Int32(sliceMs))
            if polled == 0 { continue }
            if polled < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }

            let n = buffer.withUnsafeMutableBytes { read(fd, $0.baseAddress!, $0.count) }
            if n > 0 {
                data.append(buffer, count: n)
                if data.count > maxBytes {
                    throw POSIXError(.EMSGSIZE)
                }
                continue
            }

            if n == 0 {
                return data
            }

            if errno == EINTR { continue }
            if errno == EAGAIN { continue }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
