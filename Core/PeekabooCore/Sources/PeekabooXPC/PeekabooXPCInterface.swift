import AsyncXPCConnection
import Foundation
import os.log
import PeekabooAgentRuntime
import PeekabooAutomation

@objc(PeekabooXPCConnection)
public protocol PeekabooXPCConnection: NSObjectProtocol {
    func send(_ requestData: Data, withReply reply: @escaping @Sendable (Data?, NSError?) -> Void)
}

extension NSXPCInterface {
    static func peekabooXPCInterface() -> NSXPCInterface {
        let interface = NSXPCInterface(with: (any PeekabooXPCConnection).self)
        return interface
    }
}

@MainActor
public final class PeekabooXPCServer: NSObject, PeekabooXPCConnection {
    private let services: any PeekabooServiceProviding
    private let allowlistedTeams: Set<String>
    private let allowlistedBundles: Set<String>
    private let supportedVersions: ClosedRange<PeekabooXPCProtocolVersion>
    private let allowedOperations: Set<PeekabooXPCOperation>
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "boo.peekaboo.xpc", category: "server")

    public init(
        services: any PeekabooServiceProviding,
        allowlistedTeams: Set<String>,
        allowlistedBundles: Set<String>,
        supportedVersions: ClosedRange<PeekabooXPCProtocolVersion> = PeekabooXPCConstants.supportedProtocolRange,
        allowedOperations: Set<PeekabooXPCOperation> = PeekabooXPCOperation.remoteDefaultAllowlist,
        encoder: JSONEncoder = .peekabooXPCEncoder(),
        decoder: JSONDecoder = .peekabooXPCDecoder())
    {
        self.services = services
        self.allowlistedTeams = allowlistedTeams
        self.allowlistedBundles = allowlistedBundles
        self.supportedVersions = supportedVersions
        self.allowedOperations = allowedOperations
        self.encoder = encoder
        self.decoder = decoder
        super.init()
    }

    // MARK: PeekabooXPCConnection

    public nonisolated func send(_ requestData: Data, withReply reply: @escaping @Sendable (Data?, NSError?) -> Void) {
        let currentConnection = NSXPCConnection.current()
        Task { @MainActor in
            let responseData = await self.decodeAndHandle(requestData, connection: currentConnection)
            reply(responseData, nil)
        }
    }

    // MARK: - Private

    private func decodeAndHandle(_ requestData: Data, connection: NSXPCConnection?) async -> Data {
        do {
            let request = try self.decoder.decode(PeekabooXPCRequest.self, from: requestData)
            let response = try await self.route(request, connection: connection)
            return try self.encoder.encode(response)
        } catch let envelope as PeekabooXPCErrorEnvelope {
            self.logger.error("XPC request failed with envelope: \(envelope.message, privacy: .public)")
            return (try? self.encoder.encode(PeekabooXPCResponse.error(envelope))) ?? Data()
        } catch {
            self.logger.error("XPC request decoding failed: \(error.localizedDescription, privacy: .public)")
            let envelope = PeekabooXPCErrorEnvelope(
                code: .decodingFailed,
                message: "Failed to decode request",
                details: "\(error)")
            return (try? self.encoder.encode(PeekabooXPCResponse.error(envelope))) ?? Data()
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    private func route(
        _ request: PeekabooXPCRequest,
        connection: NSXPCConnection?) async throws -> PeekabooXPCResponse
    {
        do {
            if case .handshake = request {
                // always allow
            } else if !self.allowedOperations.contains(request.operation) {
                throw PeekabooXPCErrorEnvelope(
                    code: .operationNotSupported,
                    message: "Operation \(request.operation.rawValue) is not enabled on this host")
            }
            switch request {
            case let .handshake(payload):
                return try self.handleHandshake(payload, connection: connection)

            case .permissionsStatus:
                return .permissionsStatus(self.services.permissions.checkAllPermissions())

            case let .captureScreen(payload):
                let result = try await self.services.screenCapture.captureScreen(
                    displayIndex: payload.displayIndex,
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(result)

            case let .captureWindow(payload):
                let result = try await self.services.screenCapture.captureWindow(
                    appIdentifier: payload.appIdentifier,
                    windowIndex: payload.windowIndex,
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(result)

            case let .captureFrontmost(payload):
                let result = try await self.services.screenCapture.captureFrontmost(
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(result)

            case let .captureArea(payload):
                let result = try await self.services.screenCapture.captureArea(
                    payload.rect,
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(result)

            case let .detectElements(payload):
                let result = try await self.services.automation.detectElements(
                    in: payload.imageData,
                    sessionId: payload.sessionId,
                    windowContext: payload.windowContext)
                return .elementDetection(result)

            case let .click(payload):
                try await self.services.automation.click(
                    target: payload.target,
                    clickType: payload.clickType,
                    sessionId: payload.sessionId)
                return .ok

            case let .type(payload):
                try await self.services.automation.type(
                    text: payload.text,
                    target: payload.target,
                    clearExisting: payload.clearExisting,
                    typingDelay: payload.typingDelay,
                    sessionId: payload.sessionId)
                return .ok

            case let .typeActions(payload):
                let result = try await self.services.automation.typeActions(
                    payload.actions,
                    cadence: payload.cadence,
                    sessionId: payload.sessionId)
                return .typeResult(result)

            case let .scroll(payload):
                try await self.services.automation.scroll(payload.request)
                return .ok

            case let .hotkey(payload):
                try await self.services.automation.hotkey(keys: payload.keys, holdDuration: payload.holdDuration)
                return .ok

            case let .swipe(payload):
                try await self.services.automation.swipe(
                    from: payload.from,
                    to: payload.to,
                    duration: payload.duration,
                    steps: payload.steps,
                    profile: payload.profile)
                return .ok

            case let .drag(payload):
                try await self.services.automation.drag(
                    from: payload.from,
                    to: payload.to,
                    duration: payload.duration,
                    steps: payload.steps,
                    modifiers: payload.modifiers,
                    profile: payload.profile)
                return .ok

            case let .moveMouse(payload):
                try await self.services.automation.moveMouse(
                    to: payload.to,
                    duration: payload.duration,
                    steps: payload.steps,
                    profile: payload.profile)
                return .ok

            case let .waitForElement(payload):
                let result = try await self.services.automation.waitForElement(
                    target: payload.target,
                    timeout: payload.timeout,
                    sessionId: payload.sessionId)
                return .waitResult(result)

            case let .listWindows(payload):
                let result = try await self.services.windows.listWindows(target: payload.target)
                return .windows(result)

            case let .focusWindow(payload):
                try await self.services.windows.focusWindow(target: payload.target)
                return .ok

            case let .moveWindow(payload):
                try await self.services.windows.moveWindow(target: payload.target, to: payload.position)
                return .ok

            case let .resizeWindow(payload):
                try await self.services.windows.resizeWindow(target: payload.target, to: payload.size)
                return .ok

            case let .setWindowBounds(payload):
                try await self.services.windows.setWindowBounds(target: payload.target, bounds: payload.bounds)
                return .ok

            case let .closeWindow(payload):
                try await self.services.windows.closeWindow(target: payload.target)
                return .ok

            case let .minimizeWindow(payload):
                try await self.services.windows.minimizeWindow(target: payload.target)
                return .ok

            case let .maximizeWindow(payload):
                try await self.services.windows.maximizeWindow(target: payload.target)
                return .ok

            case .getFocusedWindow:
                let window = try await self.services.windows.getFocusedWindow()
                return .window(window)

            case .listApplications:
                let apps = try await self.services.applications.listApplications()
                return .applications(apps.data.applications)

            case let .findApplication(payload):
                let app = try await self.services.applications.findApplication(identifier: payload.identifier)
                return .application(app)

            case .getFrontmostApplication:
                let app = try await self.services.applications.getFrontmostApplication()
                return .application(app)

            case let .isApplicationRunning(payload):
                let running = await self.services.applications.isApplicationRunning(identifier: payload.identifier)
                return .bool(running)

            case let .launchApplication(payload):
                let app = try await self.services.applications.launchApplication(identifier: payload.identifier)
                return .application(app)

            case let .activateApplication(payload):
                try await self.services.applications.activateApplication(identifier: payload.identifier)
                return .ok

            case let .quitApplication(payload):
                let success = try await self.services.applications.quitApplication(
                    identifier: payload.identifier,
                    force: payload.force)
                return .bool(success)

            case let .hideApplication(payload):
                try await self.services.applications.hideApplication(identifier: payload.identifier)
                return .ok

            case let .unhideApplication(payload):
                try await self.services.applications.unhideApplication(identifier: payload.identifier)
                return .ok

            case let .hideOtherApplications(payload):
                try await self.services.applications.hideOtherApplications(identifier: payload.identifier)
                return .ok

            case .showAllApplications:
                try await self.services.applications.showAllApplications()
                return .ok

            case let .listMenus(payload):
                let menus = try await self.services.menu.listMenus(for: payload.appIdentifier)
                return .menuStructure(menus)

            case .listFrontmostMenus:
                let menus = try await self.services.menu.listFrontmostMenus()
                return .menuStructure(menus)

            case let .clickMenuItem(payload):
                try await self.services.menu.clickMenuItem(app: payload.appIdentifier, itemPath: payload.itemPath)
                return .ok

            case let .clickMenuItemByName(payload):
                try await self.services.menu.clickMenuItemByName(app: payload.appIdentifier, itemName: payload.itemName)
                return .ok

            case .listMenuExtras:
                let extras = try await self.services.menu.listMenuExtras()
                return .menuExtras(extras)

            case let .clickMenuExtra(payload):
                try await self.services.menu.clickMenuExtra(title: payload.name)
                return .ok

            case let .listMenuBarItems(includeRaw):
                let items = try await self.services.menu.listMenuBarItems(includeRaw: includeRaw)
                return .menuBarItems(items)

            case let .clickMenuBarItemNamed(payload):
                let result = try await self.services.menu.clickMenuBarItem(named: payload.name)
                return .clickResult(result)

            case let .clickMenuBarItemIndex(payload):
                let result = try await self.services.menu.clickMenuBarItem(at: payload.index)
                return .clickResult(result)

            case let .listDockItems(payload):
                let items = try await self.services.dock.listDockItems(includeAll: payload.includeAll)
                return .dockItems(items)

            case let .launchDockItem(payload):
                try await self.services.dock.launchFromDock(appName: payload.appName)
                return .ok

            case let .rightClickDockItem(payload):
                try await self.services.dock.rightClickDockItem(appName: payload.appName, menuItem: payload.menuItem)
                return .ok

            case .hideDock:
                try await self.services.dock.hideDock()
                return .ok

            case .showDock:
                try await self.services.dock.showDock()
                return .ok

            case .isDockHidden:
                let hidden = await self.services.dock.isDockAutoHidden()
                return .bool(hidden)

            case let .findDockItem(payload):
                let item = try await self.services.dock.findDockItem(name: payload.name)
                return .dockItem(item)

            case let .dialogFindActive(payload):
                let info = try await self.services.dialogs.findActiveDialog(
                    windowTitle: payload.windowTitle,
                    appName: payload.appName)
                return .dialogInfo(info)

            case let .dialogClickButton(payload):
                let result = try await self.services.dialogs.clickButton(
                    buttonText: payload.buttonText,
                    windowTitle: payload.windowTitle,
                    appName: payload.appName)
                return .dialogResult(result)

            case let .dialogEnterText(payload):
                let result = try await self.services.dialogs.enterText(
                    text: payload.text,
                    fieldIdentifier: payload.fieldIdentifier,
                    clearExisting: payload.clearExisting,
                    windowTitle: payload.windowTitle,
                    appName: payload.appName)
                return .dialogResult(result)

            case let .dialogHandleFile(payload):
                let result = try await self.services.dialogs.handleFileDialog(
                    path: payload.path,
                    filename: payload.filename,
                    actionButton: payload.actionButton,
                    appName: payload.appName)
                return .dialogResult(result)

            case let .dialogDismiss(payload):
                let result = try await self.services.dialogs.dismissDialog(
                    force: payload.force,
                    windowTitle: payload.windowTitle,
                    appName: payload.appName)
                return .dialogResult(result)

            case let .dialogListElements(payload):
                let elements = try await self.services.dialogs.listDialogElements(
                    windowTitle: payload.windowTitle,
                    appName: payload.appName)
                return .dialogElements(elements)
            }
        } catch let envelope as PeekabooXPCErrorEnvelope {
            throw envelope
        } catch {
            throw PeekabooXPCErrorEnvelope(
                code: .internalError,
                message: "XPC operation failed",
                details: "\(error)")
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    private func handleHandshake(
        _ payload: PeekabooXPCHandshake,
        connection: NSXPCConnection?) throws -> PeekabooXPCResponse
    {
        guard self.supportedVersions.contains(payload.protocolVersion) else {
            throw PeekabooXPCErrorEnvelope(
                code: .versionMismatch,
                message: "Protocol \(payload.protocolVersion.major).\(payload.protocolVersion.minor) is not supported")
        }

        if let bundle = payload.client.bundleIdentifier,
           !self.allowlistedBundles.isEmpty,
           !self.allowlistedBundles.contains(bundle)
        {
            throw PeekabooXPCErrorEnvelope(
                code: .unauthorizedClient,
                message: "Bundle \(bundle) is not authorized")
        }

        if let team = payload.client.teamIdentifier,
           !self.allowlistedTeams.isEmpty,
           !self.allowlistedTeams.contains(team)
        {
            throw PeekabooXPCErrorEnvelope(
                code: .unauthorizedClient,
                message: "Team \(team) is not authorized")
        }

        let hostKind = payload.requestedHostKind ?? .helper
        let negotiated = min(
            max(payload.protocolVersion, self.supportedVersions.lowerBound),
            self.supportedVersions.upperBound)

        let response = PeekabooXPCHandshakeResponse(
            negotiatedVersion: negotiated,
            hostKind: hostKind,
            build: PeekabooXPCConstants.buildIdentifier,
            supportedOperations: self.allowedOperations.sorted { $0.rawValue < $1.rawValue })
        return .handshake(response)
    }
}

@MainActor
public final class PeekabooXPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let server: PeekabooXPCServer

    public init(server: PeekabooXPCServer) {
        self.server = server
        super.init()
    }

    public nonisolated func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        newConnection.exportedInterface = NSXPCInterface.peekabooXPCInterface()
        newConnection.exportedObject = self.server
        newConnection.resume()
        return true
    }
}

@MainActor
public struct PeekabooXPCHost {
    private let listener: NSXPCListener
    private let delegate: PeekabooXPCListenerDelegate

    public init(listener: NSXPCListener, delegate: PeekabooXPCListenerDelegate) {
        self.listener = listener
        self.delegate = delegate
        self.listener.delegate = delegate
    }

    public var endpoint: NSXPCListenerEndpoint? {
        self.listener.endpoint
    }

    public static func machService(
        name: String = PeekabooXPCConstants.serviceName,
        server: PeekabooXPCServer) -> PeekabooXPCHost
    {
        let listener = NSXPCListener(machServiceName: name)
        let delegate = PeekabooXPCListenerDelegate(server: server)
        return PeekabooXPCHost(listener: listener, delegate: delegate)
    }

    public static func embedded(server: PeekabooXPCServer) -> PeekabooXPCHost {
        let listener = NSXPCListener.anonymous()
        let delegate = PeekabooXPCListenerDelegate(server: server)
        return PeekabooXPCHost(listener: listener, delegate: delegate)
    }

    public func resume() {
        self.listener.resume()
    }
}
