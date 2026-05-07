import CoreGraphics
import Foundation
import PeekabooAutomationKit
import PeekabooFoundation

@MainActor
extension PeekabooBridgeServer {
    func handleAuthorized(
        _ request: PeekabooBridgeRequest,
        peer: PeekabooBridgePeer?) async throws -> PeekabooBridgeResponse
    {
        switch request.operation {
        case .permissionsStatus, .requestPostEventPermission, .daemonStatus, .daemonStop:
            try await self.handleCoreRequest(request, peer: peer)
        case .captureScreen, .captureWindow, .captureFrontmost, .captureArea:
            try await self.handleCaptureRequest(request)
        case .detectElements, .click, .type, .typeActions, .scroll, .hotkey, .targetedHotkey, .swipe, .drag,
             .moveMouse, .waitForElement:
            try await self.handleAutomationRequest(request)
        case .listWindows, .focusWindow, .moveWindow, .resizeWindow, .setWindowBounds, .closeWindow,
             .minimizeWindow, .maximizeWindow, .getFocusedWindow:
            try await self.handleWindowRequest(request)
        case .listApplications, .findApplication, .getFrontmostApplication, .isApplicationRunning,
             .launchApplication, .activateApplication, .quitApplication, .hideApplication, .unhideApplication,
             .hideOtherApplications, .showAllApplications:
            try await self.handleApplicationRequest(request)
        case .listMenus, .listFrontmostMenus, .clickMenuItem, .clickMenuItemByName, .listMenuExtras,
             .clickMenuExtra, .menuExtraOpenMenuFrame, .listMenuBarItems, .clickMenuBarItemNamed,
             .clickMenuBarItemIndex:
            try await self.handleMenuRequest(request)
        case .listDockItems, .launchDockItem, .rightClickDockItem, .hideDock, .showDock, .isDockHidden,
             .findDockItem:
            try await self.handleDockRequest(request)
        case .dialogFindActive, .dialogClickButton, .dialogEnterText, .dialogHandleFile, .dialogDismiss,
             .dialogListElements:
            try await self.handleDialogRequest(request)
        case .createSnapshot, .storeDetectionResult, .getDetectionResult, .storeScreenshot,
             .storeAnnotatedScreenshot, .listSnapshots, .getMostRecentSnapshot, .cleanSnapshot,
             .cleanSnapshotsOlderThan, .cleanAllSnapshots:
            try await self.handleSnapshotRequest(request)
        case ._appleScriptProbe:
            try self.handleAppleScriptProbe()
        }
    }

    private func handleCoreRequest(
        _ request: PeekabooBridgeRequest,
        peer: PeekabooBridgePeer?) async throws -> PeekabooBridgeResponse
    {
        switch request {
        case .permissionsStatus:
            return .permissionsStatus(self.currentPermissions(allowAppleScriptLaunch: false))
        case .requestPostEventPermission:
            return .bool(self.postEventAccessRequester())
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
        case let .handshake(payload):
            return try self.handleHandshake(payload, peer: peer)
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleCaptureRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
        case let .captureScreen(payload):
            let capture = try await self.services.screenCapture.captureScreen(
                displayIndex: payload.displayIndex,
                visualizerMode: payload.visualizerMode,
                scale: payload.scale)
            return .capture(capture)
        case let .captureWindow(payload):
            return try await self.handleCaptureWindow(payload)
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
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleCaptureWindow(
        _ payload: PeekabooBridgeCaptureWindowRequest) async throws -> PeekabooBridgeResponse
    {
        if let windowId = payload.windowId {
            let capture = try await self.services.screenCapture.captureWindow(
                windowID: CGWindowID(windowId),
                visualizerMode: payload.visualizerMode,
                scale: payload.scale)
            return .capture(capture)
        }

        guard !payload.appIdentifier.isEmpty else {
            throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "captureWindow requires appIdentifier or windowId")
        }

        let capture = try await self.services.screenCapture.captureWindow(
            appIdentifier: payload.appIdentifier,
            windowIndex: payload.windowIndex,
            visualizerMode: payload.visualizerMode,
            scale: payload.scale)
        return .capture(capture)
    }

    private func handleAutomationRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
        case let .targetedHotkey(payload):
            guard
                let targetedHotkeyService = self.services.automation as? any TargetedHotkeyServiceProtocol,
                targetedHotkeyService.supportsTargetedHotkeys
            else {
                throw PeekabooBridgeErrorEnvelope(
                    code: .operationNotSupported,
                    message: "Background hotkeys are not supported by this bridge host")
            }

            try await targetedHotkeyService.hotkey(
                keys: payload.keys,
                holdDuration: payload.holdDuration,
                targetProcessIdentifier: pid_t(payload.targetProcessIdentifier))
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
            try await self.services.automation.drag(payload.automationRequest)
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
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleWindowRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleApplicationRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleMenuRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
        case let .menuExtraOpenMenuFrame(payload):
            let frame = try await self.services.menu.menuExtraOpenMenuFrame(
                title: payload.title,
                ownerPID: payload.ownerPID)
            return .rect(frame)
        case let .listMenuBarItems(includeRaw):
            let items = try await self.services.menu.listMenuBarItems(includeRaw: includeRaw)
            return .menuBarItems(items)
        case let .clickMenuBarItemNamed(payload):
            let result = try await self.services.menu.clickMenuBarItem(named: payload.name)
            return .clickResult(result)
        case let .clickMenuBarItemIndex(payload):
            let result = try await self.services.menu.clickMenuBarItem(at: payload.index)
            return .clickResult(result)
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleDockRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleDialogRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleSnapshotRequest(_ request: PeekabooBridgeRequest) async throws -> PeekabooBridgeResponse {
        switch request {
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
            }
            throw PeekabooBridgeErrorEnvelope(
                code: .notFound,
                message: "No detection result for snapshot \(payload.snapshotId)")
        case let .storeScreenshot(payload):
            try await self.services.snapshots.storeScreenshot(payload.snapshotRequest)
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
            return try await self.handleMostRecentSnapshot(payload)
        case let .cleanSnapshot(payload):
            try await self.services.snapshots.cleanSnapshot(snapshotId: payload.snapshotId)
            return .ok
        case let .cleanSnapshotsOlderThan(payload):
            let count = try await self.services.snapshots.cleanSnapshotsOlderThan(days: payload.days)
            return .int(count)
        case .cleanAllSnapshots:
            let count = try await self.services.snapshots.cleanAllSnapshots()
            return .int(count)
        default:
            throw Self.invalidRequest(for: request)
        }
    }

    private func handleMostRecentSnapshot(
        _ payload: PeekabooBridgeGetMostRecentSnapshotRequest) async throws -> PeekabooBridgeResponse
    {
        let id: String? = if let bundleId = payload.applicationBundleId {
            await self.services.snapshots.getMostRecentSnapshot(applicationBundleId: bundleId)
        } else {
            await self.services.snapshots.getMostRecentSnapshot()
        }

        guard let id else {
            throw PeekabooBridgeErrorEnvelope(
                code: .notFound,
                message: "No recent snapshot found")
        }

        return .snapshotId(id)
    }

    private func handleAppleScriptProbe() throws -> PeekabooBridgeResponse {
        guard self.services.permissions.checkAppleScriptPermission() else {
            throw PeekabooBridgeErrorEnvelope(
                code: .permissionDenied,
                message: "AppleScript permission not granted")
        }

        return .ok
    }
}
