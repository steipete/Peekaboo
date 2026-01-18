import Foundation
import PeekabooAutomationKit
import PeekabooFoundation

public struct PeekabooBridgeProtocolVersion: Codable, Sendable, Comparable, Hashable {
    public let major: Int
    public let minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public static func < (lhs: PeekabooBridgeProtocolVersion, rhs: PeekabooBridgeProtocolVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        return lhs.minor < rhs.minor
    }
}

public enum PeekabooBridgeHostKind: String, Codable, Sendable, CaseIterable {
    case gui
    case helper
    case onDemand
    case inProcess
}

public enum PeekabooBridgePermissionKind: String, Codable, Sendable {
    case screenRecording
    case accessibility
    case appleScript
}

public enum PeekabooBridgeOperation: String, Codable, Sendable, CaseIterable, Hashable {
    // Core
    case permissionsStatus
    case daemonStatus
    case daemonStop
    // Capture
    case captureScreen
    case captureWindow
    case captureFrontmost
    case captureArea
    case detectElements
    // Input & automation
    case click
    case type
    case typeActions
    case scroll
    case hotkey
    case swipe
    case drag
    case moveMouse
    case waitForElement
    // Windows
    case listWindows
    case focusWindow
    case moveWindow
    case resizeWindow
    case setWindowBounds
    case closeWindow
    case minimizeWindow
    case maximizeWindow
    case getFocusedWindow
    // Applications
    case listApplications
    case findApplication
    case getFrontmostApplication
    case isApplicationRunning
    case launchApplication
    case activateApplication
    case quitApplication
    case hideApplication
    case unhideApplication
    case hideOtherApplications
    case showAllApplications
    // Menus
    case listMenus
    case listFrontmostMenus
    case clickMenuItem
    case clickMenuItemByName
    // Menu bar extras
    case listMenuExtras
    case clickMenuExtra
    case menuExtraOpenMenuFrame
    case listMenuBarItems
    case clickMenuBarItemNamed
    case clickMenuBarItemIndex
    // Dock
    case listDockItems
    case launchDockItem
    case rightClickDockItem
    case hideDock
    case showDock
    case isDockHidden
    case findDockItem
    // Dialogs
    case dialogFindActive
    case dialogClickButton
    case dialogEnterText
    case dialogHandleFile
    case dialogDismiss
    case dialogListElements
    // Snapshots/cache
    case createSnapshot
    case storeDetectionResult
    case getDetectionResult
    case storeScreenshot
    case storeAnnotatedScreenshot
    case listSnapshots
    case getMostRecentSnapshot
    case cleanSnapshot
    case cleanSnapshotsOlderThan
    case cleanAllSnapshots
    case _appleScriptProbe

    /// TCC permissions an operation relies on. Used to gate advertisement/handling.
    public var requiredPermissions: Set<PeekabooBridgePermissionKind> {
        switch self {
        case .captureScreen, .captureWindow, .captureFrontmost, .captureArea, .detectElements:
            [.screenRecording]
        case .click, .type, .typeActions, .scroll, .hotkey, .swipe, .drag, .moveMouse, .waitForElement,
             .listWindows, .focusWindow, .moveWindow, .resizeWindow, .setWindowBounds, .closeWindow,
             .minimizeWindow, .maximizeWindow, .getFocusedWindow, .listMenus, .listFrontmostMenus,
             .clickMenuItem, .clickMenuItemByName, .listMenuExtras, .clickMenuExtra, .menuExtraOpenMenuFrame,
             .listMenuBarItems, .clickMenuBarItemNamed, .clickMenuBarItemIndex, .listDockItems, .launchDockItem,
             .rightClickDockItem, .hideDock, .showDock, .isDockHidden, .findDockItem, .dialogFindActive,
             .dialogClickButton, .dialogEnterText, .dialogHandleFile, .dialogDismiss, .dialogListElements:
            [.accessibility]
        case .launchApplication, .activateApplication, .quitApplication, .hideApplication, .unhideApplication,
             .hideOtherApplications, .showAllApplications:
            [.appleScript]
        case ._appleScriptProbe,
             .permissionsStatus,
             .daemonStatus,
             .daemonStop,
             .createSnapshot,
             .storeDetectionResult,
             .getDetectionResult,
             .storeScreenshot,
             .storeAnnotatedScreenshot,
             .listSnapshots,
             .getMostRecentSnapshot,
             .cleanSnapshot,
             .cleanSnapshotsOlderThan,
             .cleanAllSnapshots,
             .listApplications,
             .findApplication,
             .getFrontmostApplication,
             .isApplicationRunning:
            []
        }
    }

    /// Operations enabled by default for remote helper hosts.
    public static let remoteDefaultAllowlist: Set<PeekabooBridgeOperation> = [
        .permissionsStatus,
        .daemonStatus,
        .daemonStop,
        .captureScreen,
        .captureWindow,
        .captureFrontmost,
        .captureArea,
        .detectElements,
        .click,
        .type,
        .typeActions,
        .scroll,
        .hotkey,
        .swipe,
        .drag,
        .moveMouse,
        .waitForElement,
        .listWindows,
        .focusWindow,
        .moveWindow,
        .resizeWindow,
        .setWindowBounds,
        .closeWindow,
        .minimizeWindow,
        .maximizeWindow,
        .getFocusedWindow,
        .listApplications,
        .findApplication,
        .getFrontmostApplication,
        .isApplicationRunning,
        .launchApplication,
        .activateApplication,
        .quitApplication,
        .hideApplication,
        .unhideApplication,
        .hideOtherApplications,
        .showAllApplications,
        .listMenus,
        .listFrontmostMenus,
        .clickMenuItem,
        .clickMenuItemByName,
        .listMenuExtras,
        .clickMenuExtra,
        .menuExtraOpenMenuFrame,
        .listMenuBarItems,
        .clickMenuBarItemNamed,
        .clickMenuBarItemIndex,
        .listDockItems,
        .launchDockItem,
        .rightClickDockItem,
        .hideDock,
        .showDock,
        .isDockHidden,
        .findDockItem,
        .dialogFindActive,
        .dialogClickButton,
        .dialogEnterText,
        .dialogHandleFile,
        .dialogDismiss,
        .dialogListElements,
        .createSnapshot,
        .storeDetectionResult,
        .getDetectionResult,
        .storeScreenshot,
        .storeAnnotatedScreenshot,
        .listSnapshots,
        .getMostRecentSnapshot,
        .cleanSnapshot,
        .cleanSnapshotsOlderThan,
        .cleanAllSnapshots,
        ._appleScriptProbe,
    ]
}

public struct PeekabooBridgeClientIdentity: Codable, Sendable {
    public let bundleIdentifier: String?
    public let teamIdentifier: String?
    public let processIdentifier: pid_t
    public let hostname: String?

    public init(
        bundleIdentifier: String?,
        teamIdentifier: String?,
        processIdentifier: pid_t,
        hostname: String? = nil)
    {
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
        self.processIdentifier = processIdentifier
        self.hostname = hostname
    }
}

public struct PeekabooBridgeHandshake: Codable, Sendable {
    public let protocolVersion: PeekabooBridgeProtocolVersion
    public let client: PeekabooBridgeClientIdentity
    public let requestedHostKind: PeekabooBridgeHostKind?

    public init(
        protocolVersion: PeekabooBridgeProtocolVersion,
        client: PeekabooBridgeClientIdentity,
        requestedHostKind: PeekabooBridgeHostKind? = nil)
    {
        self.protocolVersion = protocolVersion
        self.client = client
        self.requestedHostKind = requestedHostKind
    }
}

public struct PeekabooBridgeHandshakeResponse: Codable, Sendable {
    public let negotiatedVersion: PeekabooBridgeProtocolVersion
    public let hostKind: PeekabooBridgeHostKind
    public let build: String?
    public let supportedOperations: [PeekabooBridgeOperation]
    /// Current permission status of the host process (TCC grants).
    public let permissions: PermissionsStatus?
    /// Operations that are currently enabled given the host's permission status.
    public let enabledOperations: [PeekabooBridgeOperation]?
    /// Map of operation rawValue to the permissions it requires so clients can surface missing grants.
    public let permissionTags: [String: [PeekabooBridgePermissionKind]]

    public init(
        negotiatedVersion: PeekabooBridgeProtocolVersion,
        hostKind: PeekabooBridgeHostKind,
        build: String?,
        supportedOperations: [PeekabooBridgeOperation],
        permissions: PermissionsStatus? = nil,
        enabledOperations: [PeekabooBridgeOperation]? = nil,
        permissionTags: [String: [PeekabooBridgePermissionKind]] = [:])
    {
        self.negotiatedVersion = negotiatedVersion
        self.hostKind = hostKind
        self.build = build
        self.supportedOperations = supportedOperations
        self.permissions = permissions
        self.enabledOperations = enabledOperations
        self.permissionTags = permissionTags
    }

    private enum CodingKeys: String, CodingKey {
        case negotiatedVersion
        case hostKind
        case build
        case supportedOperations
        case permissions
        case enabledOperations
        case permissionTags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.negotiatedVersion = try container.decode(PeekabooBridgeProtocolVersion.self, forKey: .negotiatedVersion)
        self.hostKind = try container.decode(PeekabooBridgeHostKind.self, forKey: .hostKind)
        self.build = try container.decodeIfPresent(String.self, forKey: .build)
        self.supportedOperations = try container.decode([PeekabooBridgeOperation].self, forKey: .supportedOperations)
        self.permissions = try container.decodeIfPresent(PermissionsStatus.self, forKey: .permissions)
        self.enabledOperations = try container.decodeIfPresent(
            [PeekabooBridgeOperation].self,
            forKey: .enabledOperations)
        self.permissionTags = try container.decodeIfPresent(
            [String: [PeekabooBridgePermissionKind]].self,
            forKey: .permissionTags) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.negotiatedVersion, forKey: .negotiatedVersion)
        try container.encode(self.hostKind, forKey: .hostKind)
        try container.encodeIfPresent(self.build, forKey: .build)
        try container.encode(self.supportedOperations, forKey: .supportedOperations)
        try container.encodeIfPresent(self.permissions, forKey: .permissions)
        try container.encodeIfPresent(self.enabledOperations, forKey: .enabledOperations)
        if !self.permissionTags.isEmpty {
            try container.encode(self.permissionTags, forKey: .permissionTags)
        }
    }
}

// MARK: - Request payloads

public struct PeekabooBridgeCaptureScreenRequest: Codable, Sendable {
    public let displayIndex: Int?
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference
}

public struct PeekabooBridgeCaptureWindowRequest: Codable, Sendable {
    public let appIdentifier: String
    public let windowIndex: Int?
    public let windowId: Int?
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference

    public init(
        appIdentifier: String,
        windowIndex: Int?,
        windowId: Int? = nil,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference)
    {
        self.appIdentifier = appIdentifier
        self.windowIndex = windowIndex
        self.windowId = windowId
        self.visualizerMode = visualizerMode
        self.scale = scale
    }
}

public struct PeekabooBridgeCaptureFrontmostRequest: Codable, Sendable {
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference

    public init(visualizerMode: CaptureVisualizerMode, scale: CaptureScalePreference) {
        self.visualizerMode = visualizerMode
        self.scale = scale
    }
}

public struct PeekabooBridgeCaptureAreaRequest: Codable, Sendable {
    public let rect: CGRect
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference
}

public struct PeekabooBridgeDetectElementsRequest: Codable, Sendable {
    public let imageData: Data
    public let snapshotId: String?
    public let windowContext: WindowContext?
}

public struct PeekabooBridgeClickRequest: Codable, Sendable {
    public let target: ClickTarget
    public let clickType: ClickType
    public let snapshotId: String?

    public init(target: ClickTarget, clickType: ClickType, snapshotId: String? = nil) {
        self.target = target
        self.clickType = clickType
        self.snapshotId = snapshotId
    }
}

public struct PeekabooBridgeTypeRequest: Codable, Sendable {
    public let text: String
    public let target: String?
    public let clearExisting: Bool
    public let typingDelay: Int
    public let snapshotId: String?
}

public struct PeekabooBridgeTypeActionsRequest: Codable, Sendable {
    public let actions: [TypeAction]
    public let cadence: TypingCadence
    public let snapshotId: String?
}

public struct PeekabooBridgeScrollRequest: Codable, Sendable {
    public let request: ScrollRequest
}

public struct PeekabooBridgeHotkeyRequest: Codable, Sendable {
    public let keys: String
    public let holdDuration: Int
}

public struct PeekabooBridgeSwipeRequest: Codable, Sendable {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let profile: MouseMovementProfile
}

public struct PeekabooBridgeDragRequest: Codable, Sendable {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let modifiers: String?
    public let profile: MouseMovementProfile
}

public struct PeekabooBridgeMoveMouseRequest: Codable, Sendable {
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let profile: MouseMovementProfile
}

public struct PeekabooBridgeWaitRequest: Codable, Sendable {
    public let target: ClickTarget
    public let timeout: TimeInterval
    public let snapshotId: String?
}

public struct PeekabooBridgeWindowTargetRequest: Codable, Sendable {
    public let target: WindowTarget
}

public struct PeekabooBridgeWindowMoveRequest: Codable, Sendable {
    public let target: WindowTarget
    public let position: CGPoint
}

public struct PeekabooBridgeWindowResizeRequest: Codable, Sendable {
    public let target: WindowTarget
    public let size: CGSize
}

public struct PeekabooBridgeWindowBoundsRequest: Codable, Sendable {
    public let target: WindowTarget
    public let bounds: CGRect
}

public struct PeekabooBridgeAppIdentifierRequest: Codable, Sendable {
    public let identifier: String
}

public struct PeekabooBridgeQuitAppRequest: Codable, Sendable {
    public let identifier: String
    public let force: Bool
}

public struct PeekabooBridgeMenuListRequest: Codable, Sendable {
    public let appIdentifier: String

    public init(appIdentifier: String) {
        self.appIdentifier = appIdentifier
    }
}

public struct PeekabooBridgeMenuClickRequest: Codable, Sendable {
    public let appIdentifier: String
    public let itemPath: String
}

public struct PeekabooBridgeMenuClickByNameRequest: Codable, Sendable {
    public let appIdentifier: String
    public let itemName: String
}

public struct PeekabooBridgeMenuBarClickByNameRequest: Codable, Sendable {
    public let name: String
}

public struct PeekabooBridgeMenuBarClickByIndexRequest: Codable, Sendable {
    public let index: Int
}

public struct PeekabooBridgeMenuExtraOpenRequest: Codable, Sendable {
    public let title: String
    public let ownerPID: pid_t?
}

public struct PeekabooBridgeDockListRequest: Codable, Sendable {
    public let includeAll: Bool
}

public struct PeekabooBridgeDockLaunchRequest: Codable, Sendable {
    public let appName: String
}

public struct PeekabooBridgeDockRightClickRequest: Codable, Sendable {
    public let appName: String
    public let menuItem: String?
}

public struct PeekabooBridgeDockFindRequest: Codable, Sendable {
    public let name: String
}

public struct PeekabooBridgeDialogFindRequest: Codable, Sendable {
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooBridgeDialogClickButtonRequest: Codable, Sendable {
    public let buttonText: String
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooBridgeDialogEnterTextRequest: Codable, Sendable {
    public let text: String
    public let fieldIdentifier: String?
    public let clearExisting: Bool
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooBridgeDialogHandleFileRequest: Codable, Sendable {
    public let path: String?
    public let filename: String?
    public let actionButton: String?
    public let ensureExpanded: Bool?
    public let appName: String?
}

public struct PeekabooBridgeDialogDismissRequest: Codable, Sendable {
    public let force: Bool
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooBridgeCreateSnapshotRequest: Codable, Sendable {}

public struct PeekabooBridgeStoreDetectionRequest: Codable, Sendable {
    public let snapshotId: String
    public let result: ElementDetectionResult
}

public struct PeekabooBridgeGetDetectionRequest: Codable, Sendable {
    public let snapshotId: String
}

public struct PeekabooBridgeStoreScreenshotRequest: Codable, Sendable {
    public let snapshotId: String
    public let screenshotPath: String
    public let applicationBundleId: String?
    public let applicationProcessId: Int32?
    public let applicationName: String?
    public let windowTitle: String?
    public let windowBounds: CGRect?
}

public struct PeekabooBridgeStoreAnnotatedScreenshotRequest: Codable, Sendable {
    public let snapshotId: String
    public let annotatedScreenshotPath: String
}

public struct PeekabooBridgeGetMostRecentSnapshotRequest: Codable, Sendable {
    public let applicationBundleId: String?

    public init(applicationBundleId: String?) {
        self.applicationBundleId = applicationBundleId
    }
}

public struct PeekabooBridgeCleanSnapshotRequest: Codable, Sendable {
    public let snapshotId: String
}

public struct PeekabooBridgeCleanSnapshotsOlderRequest: Codable, Sendable {
    public let days: Int
}

public enum PeekabooBridgeRequest: Codable, Sendable {
    case handshake(PeekabooBridgeHandshake)
    case permissionsStatus
    case daemonStatus
    case daemonStop
    case captureScreen(PeekabooBridgeCaptureScreenRequest)
    case captureWindow(PeekabooBridgeCaptureWindowRequest)
    case captureFrontmost(PeekabooBridgeCaptureFrontmostRequest)
    case captureArea(PeekabooBridgeCaptureAreaRequest)
    case detectElements(PeekabooBridgeDetectElementsRequest)
    case click(PeekabooBridgeClickRequest)
    case type(PeekabooBridgeTypeRequest)
    case typeActions(PeekabooBridgeTypeActionsRequest)
    case scroll(PeekabooBridgeScrollRequest)
    case hotkey(PeekabooBridgeHotkeyRequest)
    case swipe(PeekabooBridgeSwipeRequest)
    case drag(PeekabooBridgeDragRequest)
    case moveMouse(PeekabooBridgeMoveMouseRequest)
    case waitForElement(PeekabooBridgeWaitRequest)
    case listWindows(PeekabooBridgeWindowTargetRequest)
    case focusWindow(PeekabooBridgeWindowTargetRequest)
    case moveWindow(PeekabooBridgeWindowMoveRequest)
    case resizeWindow(PeekabooBridgeWindowResizeRequest)
    case setWindowBounds(PeekabooBridgeWindowBoundsRequest)
    case closeWindow(PeekabooBridgeWindowTargetRequest)
    case minimizeWindow(PeekabooBridgeWindowTargetRequest)
    case maximizeWindow(PeekabooBridgeWindowTargetRequest)
    case getFocusedWindow
    case listApplications
    case findApplication(PeekabooBridgeAppIdentifierRequest)
    case getFrontmostApplication
    case isApplicationRunning(PeekabooBridgeAppIdentifierRequest)
    case launchApplication(PeekabooBridgeAppIdentifierRequest)
    case activateApplication(PeekabooBridgeAppIdentifierRequest)
    case quitApplication(PeekabooBridgeQuitAppRequest)
    case hideApplication(PeekabooBridgeAppIdentifierRequest)
    case unhideApplication(PeekabooBridgeAppIdentifierRequest)
    case hideOtherApplications(PeekabooBridgeAppIdentifierRequest)
    case showAllApplications
    case listMenus(PeekabooBridgeMenuListRequest)
    case listFrontmostMenus
    case clickMenuItem(PeekabooBridgeMenuClickRequest)
    case clickMenuItemByName(PeekabooBridgeMenuClickByNameRequest)
    case listMenuExtras
    case clickMenuExtra(PeekabooBridgeMenuBarClickByNameRequest)
    case menuExtraOpenMenuFrame(PeekabooBridgeMenuExtraOpenRequest)
    case listMenuBarItems(Bool)
    case clickMenuBarItemNamed(PeekabooBridgeMenuBarClickByNameRequest)
    case clickMenuBarItemIndex(PeekabooBridgeMenuBarClickByIndexRequest)
    case listDockItems(PeekabooBridgeDockListRequest)
    case launchDockItem(PeekabooBridgeDockLaunchRequest)
    case rightClickDockItem(PeekabooBridgeDockRightClickRequest)
    case hideDock
    case showDock
    case isDockHidden
    case findDockItem(PeekabooBridgeDockFindRequest)
    case dialogFindActive(PeekabooBridgeDialogFindRequest)
    case dialogClickButton(PeekabooBridgeDialogClickButtonRequest)
    case dialogEnterText(PeekabooBridgeDialogEnterTextRequest)
    case dialogHandleFile(PeekabooBridgeDialogHandleFileRequest)
    case dialogDismiss(PeekabooBridgeDialogDismissRequest)
    case dialogListElements(PeekabooBridgeDialogFindRequest)
    case createSnapshot(PeekabooBridgeCreateSnapshotRequest)
    case storeDetectionResult(PeekabooBridgeStoreDetectionRequest)
    case getDetectionResult(PeekabooBridgeGetDetectionRequest)
    case storeScreenshot(PeekabooBridgeStoreScreenshotRequest)
    case storeAnnotatedScreenshot(PeekabooBridgeStoreAnnotatedScreenshotRequest)
    case listSnapshots
    case getMostRecentSnapshot(PeekabooBridgeGetMostRecentSnapshotRequest)
    case cleanSnapshot(PeekabooBridgeCleanSnapshotRequest)
    case cleanSnapshotsOlderThan(PeekabooBridgeCleanSnapshotsOlderRequest)
    case cleanAllSnapshots
    case appleScriptProbe
}

extension PeekabooBridgeRequest {
    public var operation: PeekabooBridgeOperation {
        switch self {
        case .handshake: .permissionsStatus
        case .permissionsStatus: .permissionsStatus
        case .daemonStatus: .daemonStatus
        case .daemonStop: .daemonStop
        case .captureScreen: .captureScreen
        case .captureWindow: .captureWindow
        case .captureFrontmost: .captureFrontmost
        case .captureArea: .captureArea
        case .detectElements: .detectElements
        case .click: .click
        case .type: .type
        case .typeActions: .typeActions
        case .scroll: .scroll
        case .hotkey: .hotkey
        case .swipe: .swipe
        case .drag: .drag
        case .moveMouse: .moveMouse
        case .waitForElement: .waitForElement
        case .listWindows: .listWindows
        case .focusWindow: .focusWindow
        case .moveWindow: .moveWindow
        case .resizeWindow: .resizeWindow
        case .setWindowBounds: .setWindowBounds
        case .closeWindow: .closeWindow
        case .minimizeWindow: .minimizeWindow
        case .maximizeWindow: .maximizeWindow
        case .getFocusedWindow: .getFocusedWindow
        case .listApplications: .listApplications
        case .findApplication: .findApplication
        case .getFrontmostApplication: .getFrontmostApplication
        case .isApplicationRunning: .isApplicationRunning
        case .launchApplication: .launchApplication
        case .activateApplication: .activateApplication
        case .quitApplication: .quitApplication
        case .hideApplication: .hideApplication
        case .unhideApplication: .unhideApplication
        case .hideOtherApplications: .hideOtherApplications
        case .showAllApplications: .showAllApplications
        case .listMenus: .listMenus
        case .listFrontmostMenus: .listFrontmostMenus
        case .clickMenuItem: .clickMenuItem
        case .clickMenuItemByName: .clickMenuItemByName
        case .listMenuExtras: .listMenuExtras
        case .clickMenuExtra: .clickMenuExtra
        case .menuExtraOpenMenuFrame: .menuExtraOpenMenuFrame
        case .listMenuBarItems: .listMenuBarItems
        case .clickMenuBarItemNamed: .clickMenuBarItemNamed
        case .clickMenuBarItemIndex: .clickMenuBarItemIndex
        case .listDockItems: .listDockItems
        case .launchDockItem: .launchDockItem
        case .rightClickDockItem: .rightClickDockItem
        case .hideDock: .hideDock
        case .showDock: .showDock
        case .isDockHidden: .isDockHidden
        case .findDockItem: .findDockItem
        case .dialogFindActive: .dialogFindActive
        case .dialogClickButton: .dialogClickButton
        case .dialogEnterText: .dialogEnterText
        case .dialogHandleFile: .dialogHandleFile
        case .dialogDismiss: .dialogDismiss
        case .dialogListElements: .dialogListElements
        case .createSnapshot: .createSnapshot
        case .storeDetectionResult: .storeDetectionResult
        case .getDetectionResult: .getDetectionResult
        case .storeScreenshot: .storeScreenshot
        case .storeAnnotatedScreenshot: .storeAnnotatedScreenshot
        case .listSnapshots: .listSnapshots
        case .getMostRecentSnapshot: .getMostRecentSnapshot
        case .cleanSnapshot: .cleanSnapshot
        case .cleanSnapshotsOlderThan: .cleanSnapshotsOlderThan
        case .cleanAllSnapshots: .cleanAllSnapshots
        case .appleScriptProbe: ._appleScriptProbe
        }
    }
}

public enum PeekabooBridgeResponse: Codable, Sendable {
    case handshake(PeekabooBridgeHandshakeResponse)
    case permissionsStatus(PermissionsStatus)
    case daemonStatus(PeekabooDaemonStatus)
    case capture(CaptureResult)
    case elementDetection(ElementDetectionResult)
    case ok
    case waitResult(WaitForElementResult)
    case windows([ServiceWindowInfo])
    case window(ServiceWindowInfo?)
    case applications([ServiceApplicationInfo])
    case application(ServiceApplicationInfo)
    case bool(Bool)
    case typeResult(TypeResult)
    case clickResult(ClickResult)
    case menuStructure(MenuStructure)
    case menuExtras([MenuExtraInfo])
    case menuBarItems([MenuBarItemInfo])
    case dockItems([DockItem])
    case dockItem(DockItem?)
    case rect(CGRect?)
    case dialogInfo(DialogInfo)
    case dialogElements(DialogElements)
    case dialogResult(DialogActionResult)
    case snapshotId(String)
    case snapshots([SnapshotInfo])
    case detection(ElementDetectionResult)
    case int(Int)
    case error(PeekabooBridgeErrorEnvelope)
}

public enum PeekabooBridgeErrorCode: String, Codable, Sendable {
    case permissionDenied
    case notFound
    case timeout
    case invalidRequest
    case operationNotSupported
    case serverBusy
    case versionMismatch
    case unauthorizedClient
    case decodingFailed
    case internalError
}

public struct PeekabooBridgeErrorEnvelope: Codable, Sendable, Error {
    public let code: PeekabooBridgeErrorCode
    public let message: String
    public let details: String?

    public init(code: PeekabooBridgeErrorCode, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

extension PermissionsStatus: Codable {
    private enum CodingKeys: String, CodingKey {
        case screenRecording
        case accessibility
        case appleScript
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let screenRecording = try container.decode(Bool.self, forKey: .screenRecording)
        let accessibility = try container.decode(Bool.self, forKey: .accessibility)
        let appleScript = try container.decodeIfPresent(Bool.self, forKey: .appleScript) ?? false
        self.init(screenRecording: screenRecording, accessibility: accessibility, appleScript: appleScript)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.screenRecording, forKey: .screenRecording)
        try container.encode(self.accessibility, forKey: .accessibility)
        try container.encode(self.appleScript, forKey: .appleScript)
    }
}
