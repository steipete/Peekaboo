import Foundation
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooCore
import PeekabooFoundation
import Testing

@Suite("Peekaboo Bridge")
struct PeekabooBridgeTests {
    private func decode(_ data: Data) throws -> PeekabooBridgeResponse {
        try JSONDecoder.peekabooBridgeDecoder().decode(PeekabooBridgeResponse.self, from: data)
    }

    @Test("handshake negotiates version")
    func handshakeNegotiatesVersion() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: PeekabooServices(),
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [])
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "dev.peeka.cli",
            teamIdentifier: "TEAMID",
            processIdentifier: getpid(),
            hostname: Host.current().name)

        let request = PeekabooBridgeRequest.handshake(
            .init(
                protocolVersion: PeekabooBridgeConstants.protocolVersion,
                client: identity,
                requestedHostKind: .gui))

        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .handshake(handshake) = response else {
            Issue.record("Expected handshake response, got \(response)")
            return
        }

        #expect(handshake.negotiatedVersion == PeekabooBridgeConstants.protocolVersion)
        #expect(handshake.supportedOperations.contains(PeekabooBridgeOperation.permissionsStatus))
        #expect(handshake.enabledOperations?.contains(PeekabooBridgeOperation.permissionsStatus) != false)
        #expect(handshake.permissions != nil)
        #expect(handshake.hostKind == PeekabooBridgeHostKind.gui)
    }

    @Test("handshake rejects unauthorized team")
    func handshakeRejectsUnauthorizedTeam() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: PeekabooServices(),
                hostKind: .gui,
                allowlistedTeams: ["GOODTEAM"],
                allowlistedBundles: [])
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "dev.peeka.cli",
            teamIdentifier: "BADTEAM",
            processIdentifier: getpid(),
            hostname: Host.current().name)

        let peer = PeekabooBridgePeer(
            processIdentifier: getpid(),
            userIdentifier: getuid(),
            bundleIdentifier: identity.bundleIdentifier,
            teamIdentifier: identity.teamIdentifier)

        let request = PeekabooBridgeRequest.handshake(
            .init(
                protocolVersion: PeekabooBridgeConstants.protocolVersion,
                client: identity,
                requestedHostKind: .gui))

        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: peer)
        let response = try self.decode(responseData)

        guard case let .error(envelope) = response else {
            Issue.record("Expected error response, got \(response)")
            return
        }
        #expect(envelope.code == PeekabooBridgeErrorCode.unauthorizedClient)
    }

    @Test("handshake rejects unauthorized bundle")
    func handshakeRejectsUnauthorizedBundle() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: PeekabooServices(),
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: ["com.peekaboo.cli"])
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "dev.peeka.cli",
            teamIdentifier: "TEAMID",
            processIdentifier: getpid(),
            hostname: Host.current().name)

        let peer = PeekabooBridgePeer(
            processIdentifier: getpid(),
            userIdentifier: getuid(),
            bundleIdentifier: identity.bundleIdentifier,
            teamIdentifier: identity.teamIdentifier)

        let request = PeekabooBridgeRequest.handshake(
            .init(
                protocolVersion: PeekabooBridgeConstants.protocolVersion,
                client: identity,
                requestedHostKind: .gui))

        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: peer)
        let response = try self.decode(responseData)

        guard case let .error(envelope) = response else {
            Issue.record("Expected error response, got \(response)")
            return
        }
        #expect(envelope.code == PeekabooBridgeErrorCode.unauthorizedClient)
    }

    @Test("handshake rejects incompatible protocol version")
    func handshakeRejectsIncompatibleProtocol() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: PeekabooServices(),
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [])
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "dev.peeka.cli",
            teamIdentifier: "TEAMID",
            processIdentifier: getpid(),
            hostname: Host.current().name)

        let request = PeekabooBridgeRequest.handshake(
            .init(
                protocolVersion: .init(major: 2, minor: 0),
                client: identity,
                requestedHostKind: .gui))

        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .error(envelope) = response else {
            Issue.record("Expected error response, got \(response)")
            return
        }
        #expect(envelope.code == PeekabooBridgeErrorCode.versionMismatch)
    }

    @Test("unsupported operations are rejected when not allowlisted")
    func unsupportedOperationRejected() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: StubServices(),
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [],
                allowedOperations: [PeekabooBridgeOperation.permissionsStatus])
        }

        let request = PeekabooBridgeRequest
            .listMenus(PeekabooBridgeMenuListRequest(appIdentifier: "com.apple.TextEdit"))
        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .error(envelope) = response else {
            Issue.record("Expected error response, got \(response)")
            return
        }
        #expect(envelope.code == PeekabooBridgeErrorCode.operationNotSupported)
    }

    @Test("permissions status round trips")
    func permissionsStatusRoundTrips() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: PeekabooServices(),
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [])
        }

        let request = PeekabooBridgeRequest.permissionsStatus
        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .permissionsStatus(status) = response else {
            Issue.record("Expected permissions status response, got \(response)")
            return
        }

        #expect(status.missingPermissions.isEmpty == status.allGranted)
        #expect(status.missingPermissions.count <= 3)
    }

    @Test("daemon status not advertised without provider")
    func daemonStatusNotAdvertised() async throws {
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: PeekabooServices(),
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [])
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "dev.peeka.cli",
            teamIdentifier: "TEAMID",
            processIdentifier: getpid(),
            hostname: Host.current().name)

        let request = PeekabooBridgeRequest.handshake(
            .init(
                protocolVersion: PeekabooBridgeConstants.protocolVersion,
                client: identity,
                requestedHostKind: .gui))

        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .handshake(handshake) = response else {
            Issue.record("Expected handshake response, got \(response)")
            return
        }

        #expect(handshake.supportedOperations.contains(.daemonStatus) == false)
    }

    @Test("daemon status round trips")
    func daemonStatusRoundTrips() async throws {
        let daemon = StubDaemonControl()
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: StubServices(),
                hostKind: .onDemand,
                allowlistedTeams: [],
                allowlistedBundles: [],
                daemonControl: daemon)
        }

        let request = PeekabooBridgeRequest.daemonStatus
        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .daemonStatus(status) = response else {
            Issue.record("Expected daemon status response, got \(response)")
            return
        }

        #expect(status.running == true)
        #expect(status.mode == .manual)
        #expect(status.bridge?.hostKind == .onDemand)
    }

    @Test("capture round trips through bridge")
    func captureRoundTrip() async throws {
        let stub = await MainActor.run { StubServices() }
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: stub,
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [])
        }

        let request = PeekabooBridgeRequest.captureFrontmost(
            PeekabooBridgeCaptureFrontmostRequest(
                visualizerMode: CaptureVisualizerMode.screenshotFlash,
                scale: CaptureScalePreference.logical1x))
        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case let .capture(result) = response else {
            Issue.record("Expected capture response, got \(response)")
            return
        }

        #expect(result.imageData == Data("stub-capture".utf8))
        #expect(result.metadata.mode == CaptureMode.frontmost)
    }

    @Test("automation click is forwarded")
    func automationClick() async throws {
        let stub = await MainActor.run { StubServices() }
        let server = await MainActor.run {
            PeekabooBridgeServer(
                services: stub,
                hostKind: .gui,
                allowlistedTeams: [],
                allowlistedBundles: [])
        }

        let request = PeekabooBridgeRequest.click(
            PeekabooBridgeClickRequest(target: .elementId("B1"), clickType: .single, snapshotId: nil))
        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case .ok = response else {
            Issue.record("Expected ok response, got \(response)")
            return
        }

        let lastClick = await stub.automationStub.lastClick
        if case let .elementId(id)? = lastClick?.target {
            #expect(id == "B1")
        } else {
            Issue.record("Expected elementId(B1), got \(String(describing: lastClick?.target))")
        }
        #expect(lastClick?.type == .single)
    }
}

// MARK: - Test stubs

@MainActor
private final class StubServices: PeekabooBridgeServiceProviding {
    let screenCapture: any ScreenCaptureServiceProtocol = StubScreenCaptureService()
    let automationStub = StubAutomationService()
    let automation: any UIAutomationServiceProtocol
    let applications: any ApplicationServiceProtocol = StubApplicationService()
    let windows: any WindowManagementServiceProtocol = StubWindowService()
    let menu: any MenuServiceProtocol = UnimplementedMenuService()
    let dock: any DockServiceProtocol = UnimplementedDockService()
    let dialogs: any DialogServiceProtocol = UnimplementedDialogService()
    let snapshots: any SnapshotManagerProtocol = SnapshotManager()
    let permissions: PermissionsService = .init()

    init() {
        self.automation = self.automationStub
    }
}

private final class StubScreenCaptureService: ScreenCaptureServiceProtocol {
    static let sampleData = Data("stub-capture".utf8)

    func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        _ = (displayIndex, visualizerMode, scale)
        return self.makeResult(mode: .screen)
    }

    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        _ = (appIdentifier, windowIndex, visualizerMode, scale)
        return self.makeResult(mode: .window)
    }

    func captureFrontmost(
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        _ = (visualizerMode, scale)
        return self.makeResult(mode: .frontmost)
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        _ = (rect, visualizerMode, scale)
        return self.makeResult(mode: .area)
    }

    func hasScreenRecordingPermission() async -> Bool { true }

    private func makeResult(mode: CaptureMode) -> CaptureResult {
        CaptureResult(
            imageData: Self.sampleData,
            savedPath: nil,
            metadata: CaptureMetadata(
                size: .init(width: 1, height: 1),
                mode: mode,
                timestamp: Date()))
    }
}

@MainActor
private final class StubAutomationService: UIAutomationServiceProtocol {
    struct Click { let target: ClickTarget; let type: ClickType }
    private(set) var lastClick: Click?

    func detectElements(in _: Data, snapshotId _: String?, windowContext _: WindowContext?) async throws
        -> ElementDetectionResult
    {
        ElementDetectionResult(
            snapshotId: "s",
            screenshotPath: "/tmp/s.png",
            elements: DetectedElements(),
            metadata: DetectionMetadata(
                detectionTime: 0,
                elementCount: 0,
                method: "stub",
                warnings: [],
                windowContext: nil,
                isDialog: false))
    }

    func click(target: ClickTarget, clickType: ClickType, snapshotId _: String?) async throws {
        self.lastClick = Click(target: target, type: clickType)
    }

    func type(text _: String, target _: String?, clearExisting _: Bool, typingDelay _: Int, snapshotId _: String?) async
    throws {}

    func typeActions(_ actions: [TypeAction], cadence _: TypingCadence, snapshotId _: String?) async throws
        -> TypeResult
    {
        TypeResult(totalCharacters: actions.count, keyPresses: actions.count)
    }

    func scroll(_ request: ScrollRequest) async throws {
        _ = request
    }

    func hotkey(keys _: String, holdDuration _: Int) async throws {}

    func swipe(from _: CGPoint, to _: CGPoint, duration _: Int, steps _: Int, profile _: MouseMovementProfile) async
    throws {}

    func hasAccessibilityPermission() async -> Bool { true }

    func waitForElement(target _: ClickTarget, timeout _: TimeInterval, snapshotId _: String?) async throws
        -> WaitForElementResult
    {
        WaitForElementResult(found: true, element: nil, waitTime: 0)
    }

    // swiftlint:disable function_parameter_count
    func drag(
        from _: CGPoint,
        to _: CGPoint,
        duration _: Int,
        steps _: Int,
        modifiers _: String?,
        profile _: MouseMovementProfile)
    async throws {}
    // swiftlint:enable function_parameter_count

    func moveMouse(to _: CGPoint, duration _: Int, steps _: Int, profile _: MouseMovementProfile) async throws {}

    func getFocusedElement() -> UIFocusInfo? { nil }

    func findElement(matching _: UIElementSearchCriteria, in _: String?) async throws -> DetectedElement {
        throw PeekabooError.operationError(message: "stub")
    }
}

@MainActor
private final class StubWindowService: WindowManagementServiceProtocol {
    private let windowsList: [ServiceWindowInfo] = [
        ServiceWindowInfo(windowID: 1, title: "Stub", bounds: .init(x: 0, y: 0, width: 100, height: 100)),
    ]

    func closeWindow(target _: WindowTarget) async throws {}
    func minimizeWindow(target _: WindowTarget) async throws {}
    func maximizeWindow(target _: WindowTarget) async throws {}
    func moveWindow(target _: WindowTarget, to _: CGPoint) async throws {}
    func resizeWindow(target _: WindowTarget, to _: CGSize) async throws {}
    func setWindowBounds(target _: WindowTarget, bounds _: CGRect) async throws {}
    func focusWindow(target _: WindowTarget) async throws {}
    func listWindows(target _: WindowTarget) async throws -> [ServiceWindowInfo] { self.windowsList }
    func getFocusedWindow() async throws -> ServiceWindowInfo? { self.windowsList.first }
}

@MainActor
private final class StubApplicationService: ApplicationServiceProtocol {
    private let app = ServiceApplicationInfo(
        processIdentifier: 123,
        bundleIdentifier: "dev.stub",
        name: "StubApp",
        bundlePath: nil,
        isActive: true,
        isHidden: false,
        windowCount: 1)

    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        UnifiedToolOutput(
            data: ServiceApplicationListData(applications: [self.app]),
            summary: .init(brief: "1 app", status: .success, counts: ["applications": 1]),
            metadata: .init(duration: 0))
    }

    func findApplication(identifier _: String) async throws -> ServiceApplicationInfo { self.app }

    func listWindows(for _: String, timeout _: Float?) async throws -> UnifiedToolOutput<ServiceWindowListData> {
        UnifiedToolOutput(
            data: ServiceWindowListData(windows: [], targetApplication: self.app),
            summary: .init(brief: "0 windows", status: .success, counts: [:]),
            metadata: .init(duration: 0))
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo { self.app }
    func isApplicationRunning(identifier _: String) async -> Bool { true }
    func launchApplication(identifier _: String) async throws -> ServiceApplicationInfo { self.app }
    func activateApplication(identifier _: String) async throws {}
    func quitApplication(identifier _: String, force _: Bool) async throws -> Bool { true }
    func hideApplication(identifier _: String) async throws {}
    func unhideApplication(identifier _: String) async throws {}
    func hideOtherApplications(identifier _: String) async throws {}
    func showAllApplications() async throws {}
}

@MainActor
private final class UnimplementedMenuService: MenuServiceProtocol {
    func listMenus(for _: String) async throws -> MenuStructure { throw PeekabooError.notImplemented("stub") }
    func listFrontmostMenus() async throws -> MenuStructure { throw PeekabooError.notImplemented("stub") }
    func clickMenuItem(app _: String, itemPath _: String) async throws { throw PeekabooError.notImplemented("stub") }
    func clickMenuItemByName(app _: String, itemName _: String) async throws {
        throw PeekabooError.notImplemented("stub")
    }

    func clickMenuExtra(title _: String) async throws { throw PeekabooError.notImplemented("stub") }
    func listMenuExtras() async throws -> [MenuExtraInfo] { [] }
    func listMenuBarItems(includeRaw _: Bool) async throws -> [MenuBarItemInfo] { [] }
    func clickMenuBarItem(named _: String) async throws -> ClickResult { throw PeekabooError.notImplemented("stub") }
    func clickMenuBarItem(at _: Int) async throws -> ClickResult { throw PeekabooError.notImplemented("stub") }
}

@MainActor
private final class UnimplementedDockService: DockServiceProtocol {
    func launchFromDock(appName _: String) async throws {}
    func findDockItem(name _: String) async throws -> DockItem { throw PeekabooError.notImplemented("stub") }
    func rightClickDockItem(appName _: String, menuItem _: String?) async throws {}
    func hideDock() async throws {}
    func showDock() async throws {}
    func listDockItems(includeAll _: Bool) async throws -> [DockItem] { [] }
    func addToDock(path _: String, persistent _: Bool) async throws {}
    func removeFromDock(appName _: String) async throws {}
    func isDockAutoHidden() async -> Bool { false }
}

@MainActor
private final class UnimplementedDialogService: DialogServiceProtocol {
    func findActiveDialog(windowTitle _: String?, appName _: String?) async throws -> DialogInfo {
        throw PeekabooError.notImplemented("stub")
    }

    func clickButton(buttonText _: String, windowTitle _: String?, appName _: String?) async throws
        -> DialogActionResult
    { throw PeekabooError.notImplemented("stub") }

    func enterText(
        text _: String,
        fieldIdentifier _: String?,
        clearExisting _: Bool,
        windowTitle _: String?,
        appName _: String?) async throws -> DialogActionResult
    { throw PeekabooError.notImplemented("stub") }

    func handleFileDialog(
        path _: String?,
        filename _: String?,
        actionButton _: String?,
        ensureExpanded _: Bool,
        appName _: String?) async
        throws -> DialogActionResult
    { throw PeekabooError.notImplemented("stub") }

    func dismissDialog(force _: Bool, windowTitle _: String?, appName _: String?) async throws -> DialogActionResult {
        throw PeekabooError.notImplemented("stub")
    }

    func listDialogElements(windowTitle _: String?, appName _: String?) async throws -> DialogElements {
        throw PeekabooError.notImplemented("stub")
    }
}

@MainActor
private final class StubDaemonControl: PeekabooDaemonControlProviding {
    func daemonStatus() async -> PeekabooDaemonStatus {
        PeekabooDaemonStatus(
            running: true,
            pid: getpid(),
            startedAt: Date(),
            mode: .manual,
            bridge: PeekabooDaemonBridgeStatus(
                socketPath: "/tmp/peekaboo.sock",
                hostKind: .onDemand,
                allowedOperations: [.daemonStatus]))
    }

    func requestStop() async -> Bool {
        true
    }
}
