import Foundation
import os.log
import PeekabooAutomationKit
import PeekabooFoundation
import Security

public struct PeekabooBridgePeer: Sendable {
    public let processIdentifier: pid_t
    public let userIdentifier: uid_t?
    public let bundleIdentifier: String?
    public let teamIdentifier: String?

    public init(
        processIdentifier: pid_t,
        userIdentifier: uid_t?,
        bundleIdentifier: String?,
        teamIdentifier: String?)
    {
        self.processIdentifier = processIdentifier
        self.userIdentifier = userIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
    }
}

@MainActor
public final class PeekabooBridgeServer {
    private let services: any PeekabooBridgeServiceProviding
    private let hostKind: PeekabooBridgeHostKind
    private let allowlistedTeams: Set<String>
    private let allowlistedBundles: Set<String>
    private let supportedVersions: ClosedRange<PeekabooBridgeProtocolVersion>
    private let allowedOperations: Set<PeekabooBridgeOperation>
    private let daemonControl: (any PeekabooDaemonControlProviding)?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "boo.peekaboo.bridge", category: "server")

    public init(
        services: any PeekabooBridgeServiceProviding,
        hostKind: PeekabooBridgeHostKind = .gui,
        allowlistedTeams: Set<String>,
        allowlistedBundles: Set<String>,
        supportedVersions: ClosedRange<PeekabooBridgeProtocolVersion> = PeekabooBridgeConstants.supportedProtocolRange,
        allowedOperations: Set<PeekabooBridgeOperation> = PeekabooBridgeOperation.remoteDefaultAllowlist,
        daemonControl: (any PeekabooDaemonControlProviding)? = nil,
        encoder: JSONEncoder = .peekabooBridgeEncoder(),
        decoder: JSONDecoder = .peekabooBridgeDecoder())
    {
        self.services = services
        self.hostKind = hostKind
        self.allowlistedTeams = allowlistedTeams
        self.allowlistedBundles = allowlistedBundles
        self.supportedVersions = supportedVersions
        self.allowedOperations = allowedOperations
        self.daemonControl = daemonControl
        self.encoder = encoder
        self.decoder = decoder
    }

    public func decodeAndHandle(_ requestData: Data, peer: PeekabooBridgePeer?) async -> Data {
        do {
            let request = try self.decoder.decode(PeekabooBridgeRequest.self, from: requestData)
            let response = try await self.route(request, peer: peer)
            return try self.encoder.encode(response)
        } catch let envelope as PeekabooBridgeErrorEnvelope {
            self.logger.error("bridge request failed: \(envelope.message, privacy: .public)")
            return (try? self.encoder.encode(PeekabooBridgeResponse.error(envelope))) ?? Data()
        } catch {
            self.logger.error("bridge request decoding failed: \(error.localizedDescription, privacy: .public)")
            let envelope = PeekabooBridgeErrorEnvelope(
                code: .decodingFailed,
                message: "Failed to decode request",
                details: "\(error)")
            return (try? self.encoder.encode(PeekabooBridgeResponse.error(envelope))) ?? Data()
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    private func route(
        _ request: PeekabooBridgeRequest,
        peer: PeekabooBridgePeer?) async throws -> PeekabooBridgeResponse
    {
        if peer == nil, !self.allowlistedTeams.isEmpty || !self.allowlistedBundles.isEmpty {
            throw PeekabooBridgeErrorEnvelope(
                code: .unauthorizedClient,
                message: "Unsigned bridge clients are not allowed for this listener")
        }

        let start = Date()
        let pid = peer?.processIdentifier ?? 0
        var failed = false
        defer {
            if !failed {
                let duration = Date().timeIntervalSince(start)
                let durationString = String(format: "%.3f", duration)
                let message = "bridge op=\(request.operation.rawValue) pid=\(pid) ok in \(durationString)s"
                self.logger.debug("\(message, privacy: .public)")
            }
        }

        let permissions = self.services.permissions.checkAllPermissions()
        let effectiveOps = self.effectiveAllowedOperations(permissions: permissions)
        let op = request.operation

        do {
            if case .handshake = request {
                // Always allow.
            } else if !self.allowedOperations.contains(op) {
                throw PeekabooBridgeErrorEnvelope(
                    code: .operationNotSupported,
                    message: "Operation \(op.rawValue) is not supported by this host")
            } else if !effectiveOps.contains(op) {
                throw PeekabooBridgeErrorEnvelope(
                    code: .permissionDenied,
                    message: "Operation \(op.rawValue) is not allowed with current permissions")
            }

            switch request {
            case let .handshake(payload):
                return try self.handleHandshake(payload, peer: peer)

            case .permissionsStatus:
                return .permissionsStatus(self.services.permissions.checkAllPermissions())

            case .daemonStatus:
                guard let daemonControl = self.daemonControl else {
                    throw PeekabooBridgeErrorEnvelope(
                        code: .operationNotSupported,
                        message: "Daemon status is not supported by this host")
                }
                let status = await daemonControl.daemonStatus()
                return .daemonStatus(status)

            case .daemonStop:
                guard let daemonControl = self.daemonControl else {
                    throw PeekabooBridgeErrorEnvelope(
                        code: .operationNotSupported,
                        message: "Daemon stop is not supported by this host")
                }
                let stopped = await daemonControl.requestStop()
                return .bool(stopped)

            case let .captureScreen(payload):
                let capture = try await self.services.screenCapture.captureScreen(
                    displayIndex: payload.displayIndex,
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(capture)

            case let .captureWindow(payload):
                let capture = try await self.services.screenCapture.captureWindow(
                    appIdentifier: payload.appIdentifier,
                    windowIndex: payload.windowIndex,
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(capture)

            case let .captureFrontmost(payload):
                let capture = try await self.services.screenCapture.captureFrontmost(
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(capture)

            case let .captureArea(payload):
                let capture = try await self.services.screenCapture.captureArea(
                    payload.rect,
                    visualizerMode: payload.visualizerMode,
                    scale: payload.scale)
                return .capture(capture)

            case let .detectElements(payload):
                let result = try await self.services.automation.detectElements(
                    in: payload.imageData,
                    snapshotId: payload.snapshotId,
                    windowContext: payload.windowContext)
                return .elementDetection(result)

            case let .click(payload):
                try await self.services.automation.click(
                    target: payload.target,
                    clickType: payload.clickType,
                    snapshotId: payload.snapshotId)
                return .ok

            case let .type(payload):
                try await self.services.automation.type(
                    text: payload.text,
                    target: payload.target,
                    clearExisting: payload.clearExisting,
                    typingDelay: payload.typingDelay,
                    snapshotId: payload.snapshotId)
                return .ok

            case let .typeActions(payload):
                let result = try await self.services.automation.typeActions(
                    payload.actions,
                    cadence: payload.cadence,
                    snapshotId: payload.snapshotId)
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
                    snapshotId: payload.snapshotId)
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
                    ensureExpanded: payload.ensureExpanded ?? false,
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

            case .createSnapshot:
                let id = try await self.services.snapshots.createSnapshot()
                return .snapshotId(id)

            case let .storeDetectionResult(payload):
                try await self.services.snapshots.storeDetectionResult(
                    snapshotId: payload.snapshotId,
                    result: payload.result)
                return .ok

            case let .getDetectionResult(payload):
                if let result = try await self.services.snapshots.getDetectionResult(snapshotId: payload.snapshotId) {
                    return .detection(result)
                } else {
                    throw PeekabooBridgeErrorEnvelope(
                        code: .notFound,
                        message: "No detection result for snapshot \(payload.snapshotId)")
                }

            case let .storeScreenshot(payload):
                try await self.services.snapshots.storeScreenshot(
                    snapshotId: payload.snapshotId,
                    screenshotPath: payload.screenshotPath,
                    applicationBundleId: payload.applicationBundleId,
                    applicationProcessId: payload.applicationProcessId,
                    applicationName: payload.applicationName,
                    windowTitle: payload.windowTitle,
                    windowBounds: payload.windowBounds)
                return .ok

            case let .storeAnnotatedScreenshot(payload):
                try await self.services.snapshots.storeAnnotatedScreenshot(
                    snapshotId: payload.snapshotId,
                    annotatedScreenshotPath: payload.annotatedScreenshotPath)
                return .ok

            case .listSnapshots:
                let list = try await self.services.snapshots.listSnapshots()
                return .snapshots(list)

            case let .getMostRecentSnapshot(payload):
                let id: String? = if let bundleId = payload.applicationBundleId {
                    await self.services.snapshots.getMostRecentSnapshot(applicationBundleId: bundleId)
                } else {
                    await self.services.snapshots.getMostRecentSnapshot()
                }

                if let id {
                    return .snapshotId(id)
                } else {
                    throw PeekabooBridgeErrorEnvelope(
                        code: .notFound,
                        message: "No recent snapshot found")
                }

            case let .cleanSnapshot(payload):
                try await self.services.snapshots.cleanSnapshot(snapshotId: payload.snapshotId)
                return .ok

            case let .cleanSnapshotsOlderThan(payload):
                let count = try await self.services.snapshots.cleanSnapshotsOlderThan(days: payload.days)
                return .int(count)

            case .cleanAllSnapshots:
                let count = try await self.services.snapshots.cleanAllSnapshots()
                return .int(count)

            case .appleScriptProbe:
                guard self.services.permissions.checkAppleScriptPermission() else {
                    throw PeekabooBridgeErrorEnvelope(
                        code: .permissionDenied,
                        message: "AppleScript permission not granted")
                }
                return .ok
            }
        } catch let envelope as PeekabooBridgeErrorEnvelope {
            failed = true
            let duration = Date().timeIntervalSince(start)
            let durationString = String(format: "%.3f", duration)
            let message =
                "bridge op=\(op.rawValue) pid=\(pid) failed in \(durationString)s: \(envelope.message)"
            self.logger.error("\(message, privacy: .public)")
            throw envelope
        } catch {
            failed = true
            let duration = Date().timeIntervalSince(start)
            let durationString = String(format: "%.3f", duration)
            let message =
                "bridge op=\(op.rawValue) pid=\(pid) failed in \(durationString)s: \(error.localizedDescription)"
            self.logger.error("\(message, privacy: .public)")

            if let error = error as? PeekabooError {
                switch error {
                case let .notImplemented(message):
                    throw PeekabooBridgeErrorEnvelope(
                        code: .operationNotSupported,
                        message: "Operation \(op.rawValue) is not supported: \(message)",
                        details: "\(error)")
                default:
                    break
                }
            }

            throw PeekabooBridgeErrorEnvelope(
                code: .internalError,
                message: "Bridge operation failed",
                details: "\(error)")
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    private func handleHandshake(
        _ payload: PeekabooBridgeHandshake,
        peer: PeekabooBridgePeer?) throws -> PeekabooBridgeResponse
    {
        let resolvedBundle = peer?.bundleIdentifier ?? payload.client.bundleIdentifier
        let resolvedTeam = peer?.teamIdentifier ?? payload.client.teamIdentifier

        guard self.supportedVersions.contains(payload.protocolVersion) else {
            throw PeekabooBridgeErrorEnvelope(
                code: .versionMismatch,
                message: "Protocol \(payload.protocolVersion.major).\(payload.protocolVersion.minor) is not supported")
        }

        if let bundle = resolvedBundle,
           !self.allowlistedBundles.isEmpty,
           !self.allowlistedBundles.contains(bundle)
        {
            throw PeekabooBridgeErrorEnvelope(code: .unauthorizedClient, message: "Bundle \(bundle) is not authorized")
        }

        if let team = resolvedTeam,
           !self.allowlistedTeams.isEmpty,
           !self.allowlistedTeams.contains(team)
        {
            throw PeekabooBridgeErrorEnvelope(code: .unauthorizedClient, message: "Team \(team) is not authorized")
        }

        if let uid = peer?.userIdentifier, uid != getuid() {
            throw PeekabooBridgeErrorEnvelope(
                code: .unauthorizedClient,
                message: "UID \(uid) is not authorized for this listener")
        }

        if let pid = peer?.processIdentifier {
            let bundleDescription = resolvedBundle ?? "<unknown>"
            self.logger
                .debug(
                    "bridge handshake ok pid=\(pid, privacy: .public) bundle=\(bundleDescription, privacy: .public)")
        }

        let permissions = self.services.permissions.checkAllPermissions()
        let advertisedOps = Array(self.allowedOperationsToAdvertise()).sorted { $0.rawValue < $1.rawValue }
        let enabledOps = self.effectiveAllowedOperations(permissions: permissions)
        let permissionTags = Dictionary(
            uniqueKeysWithValues: advertisedOps.map { op in
                (op.rawValue, Array(op.requiredPermissions).sorted { $0.rawValue < $1.rawValue })
            })

        self.logger.debug(
            """
            Handshake advertised=\(advertisedOps.count, privacy: .public) \
            enabled=\(enabledOps.count, privacy: .public) \
            tags=\(permissionTags.count, privacy: .public)
            """)

        let negotiated = min(
            max(payload.protocolVersion, self.supportedVersions.lowerBound),
            self.supportedVersions.upperBound)

        let response = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: negotiated,
            hostKind: self.hostKind,
            build: PeekabooBridgeConstants.buildIdentifier,
            supportedOperations: advertisedOps,
            permissions: permissions,
            enabledOperations: Array(enabledOps).sorted { $0.rawValue < $1.rawValue },
            permissionTags: permissionTags)
        return .handshake(response)
    }

    private func allowedOperationsToAdvertise() -> Set<PeekabooBridgeOperation> {
        var operations = self.allowedOperations
        if self.daemonControl == nil {
            operations.remove(.daemonStatus)
            operations.remove(.daemonStop)
        }
        return operations
    }

    private func effectiveAllowedOperations(permissions: PermissionsStatus) -> Set<PeekabooBridgeOperation> {
        var granted: Set<PeekabooBridgePermissionKind> = []
        if permissions.screenRecording {
            granted.insert(.screenRecording)
        }
        if permissions.accessibility {
            granted.insert(.accessibility)
        }
        if permissions.appleScript {
            granted.insert(.appleScript)
        }

        return Set(
            self.allowedOperationsToAdvertise().filter { operation in
                operation.requiredPermissions.isSubset(of: granted)
            })
    }
}
