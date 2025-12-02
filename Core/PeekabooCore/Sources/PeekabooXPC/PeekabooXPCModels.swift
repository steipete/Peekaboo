import Foundation
import PeekabooAutomation
import PeekabooFoundation

public struct PeekabooXPCProtocolVersion: Codable, Sendable, Comparable, Hashable {
    public let major: Int
    public let minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public static func < (lhs: PeekabooXPCProtocolVersion, rhs: PeekabooXPCProtocolVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        return lhs.minor < rhs.minor
    }
}

public enum PeekabooXPCHostKind: String, Codable, Sendable, CaseIterable {
    case gui
    case helper
    case onDemand
    case inProcess
}

public enum PeekabooXPCOperation: String, Codable, Sendable, CaseIterable {
    case permissionsStatus
    case captureScreen
    case captureWindow
    case captureFrontmost
    case captureArea
    case detectElements
    case click
    case type
    case typeActions
    case scroll
    case hotkey
    case swipe
    case drag
    case moveMouse
    case waitForElement
    case listWindows
    case focusWindow
    case moveWindow
    case resizeWindow
    case setWindowBounds
    case closeWindow
    case minimizeWindow
    case maximizeWindow
    case getFocusedWindow
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
    case listMenus
    case listFrontmostMenus
    case clickMenuItem
    case clickMenuItemByName
    case listMenuExtras
    case clickMenuExtra
    case listMenuBarItems
    case clickMenuBarItemNamed
    case clickMenuBarItemIndex
    case listDockItems
    case launchDockItem
    case rightClickDockItem
    case hideDock
    case showDock
    case isDockHidden
    case findDockItem
    case dialogFindActive
    case dialogClickButton
    case dialogEnterText
    case dialogHandleFile
    case dialogDismiss
    case dialogListElements

    /// Operations enabled by default for remote helper hosts.
    /// Menu/Dock/Dialog stay local until we harden those surfaces.
    public static let remoteDefaultAllowlist: Set<PeekabooXPCOperation> = [
        .permissionsStatus,
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
    ]
}

public struct PeekabooXPCClientIdentity: Codable, Sendable {
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

public struct PeekabooXPCHandshake: Codable, Sendable {
    public let protocolVersion: PeekabooXPCProtocolVersion
    public let client: PeekabooXPCClientIdentity
    public let requestedHostKind: PeekabooXPCHostKind?

    public init(
        protocolVersion: PeekabooXPCProtocolVersion,
        client: PeekabooXPCClientIdentity,
        requestedHostKind: PeekabooXPCHostKind? = nil)
    {
        self.protocolVersion = protocolVersion
        self.client = client
        self.requestedHostKind = requestedHostKind
    }
}

public struct PeekabooXPCHandshakeResponse: Codable, Sendable {
    public let negotiatedVersion: PeekabooXPCProtocolVersion
    public let hostKind: PeekabooXPCHostKind
    public let build: String?
    public let supportedOperations: [PeekabooXPCOperation]

    public init(
        negotiatedVersion: PeekabooXPCProtocolVersion,
        hostKind: PeekabooXPCHostKind,
        build: String?,
        supportedOperations: [PeekabooXPCOperation])
    {
        self.negotiatedVersion = negotiatedVersion
        self.hostKind = hostKind
        self.build = build
        self.supportedOperations = supportedOperations
    }
}

// MARK: - Request payloads

public struct PeekabooXPCCaptureScreenRequest: Codable, Sendable {
    public let displayIndex: Int?
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference
}

public struct PeekabooXPCCaptureWindowRequest: Codable, Sendable {
    public let appIdentifier: String
    public let windowIndex: Int?
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference
}

public struct PeekabooXPCCaptureFrontmostRequest: Codable, Sendable {
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference
}

public struct PeekabooXPCCaptureAreaRequest: Codable, Sendable {
    public let rect: CGRect
    public let visualizerMode: CaptureVisualizerMode
    public let scale: CaptureScalePreference
}

public struct PeekabooXPCDetectElementsRequest: Codable, Sendable {
    public let imageData: Data
    public let sessionId: String?
    public let windowContext: WindowContext?
}

public struct PeekabooXPCClickRequest: Codable, Sendable {
    public let target: ClickTarget
    public let clickType: ClickType
    public let sessionId: String?
}

public struct PeekabooXPCTypeRequest: Codable, Sendable {
    public let text: String
    public let target: String?
    public let clearExisting: Bool
    public let typingDelay: Int
    public let sessionId: String?
}

public struct PeekabooXPCTypeActionsRequest: Codable, Sendable {
    public let actions: [TypeAction]
    public let cadence: TypingCadence
    public let sessionId: String?
}

public struct PeekabooXPCScrollRequest: Codable, Sendable {
    public let request: ScrollRequest
}

public struct PeekabooXPCHotkeyRequest: Codable, Sendable {
    public let keys: String
    public let holdDuration: Int
}

public struct PeekabooXPCSwipeRequest: Codable, Sendable {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let profile: MouseMovementProfile
}

public struct PeekabooXPCDragRequest: Codable, Sendable {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let modifiers: String?
    public let profile: MouseMovementProfile
}

public struct PeekabooXPCMoveMouseRequest: Codable, Sendable {
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let profile: MouseMovementProfile
}

public struct PeekabooXPCWaitRequest: Codable, Sendable {
    public let target: ClickTarget
    public let timeout: TimeInterval
    public let sessionId: String?
}

public struct PeekabooXPCWindowTargetRequest: Codable, Sendable {
    public let target: WindowTarget
}

public struct PeekabooXPCWindowMoveRequest: Codable, Sendable {
    public let target: WindowTarget
    public let position: CGPoint
}

public struct PeekabooXPCWindowResizeRequest: Codable, Sendable {
    public let target: WindowTarget
    public let size: CGSize
}

public struct PeekabooXPCWindowBoundsRequest: Codable, Sendable {
    public let target: WindowTarget
    public let bounds: CGRect
}

public struct PeekabooXPCAppIdentifierRequest: Codable, Sendable {
    public let identifier: String
}

public struct PeekabooXPCQuitAppRequest: Codable, Sendable {
    public let identifier: String
    public let force: Bool
}

public struct PeekabooXPCMenuListRequest: Codable, Sendable {
    public let appIdentifier: String
}

public struct PeekabooXPCMenuClickRequest: Codable, Sendable {
    public let appIdentifier: String
    public let itemPath: String
}

public struct PeekabooXPCMenuClickByNameRequest: Codable, Sendable {
    public let appIdentifier: String
    public let itemName: String
}

public struct PeekabooXPCMenuBarClickByNameRequest: Codable, Sendable {
    public let name: String
}

public struct PeekabooXPCMenuBarClickByIndexRequest: Codable, Sendable {
    public let index: Int
}

public struct PeekabooXPCDockListRequest: Codable, Sendable {
    public let includeAll: Bool
}

public struct PeekabooXPCDockLaunchRequest: Codable, Sendable {
    public let appName: String
}

public struct PeekabooXPCDockRightClickRequest: Codable, Sendable {
    public let appName: String
    public let menuItem: String?
}

public struct PeekabooXPCDockFindRequest: Codable, Sendable {
    public let name: String
}

public struct PeekabooXPCDialogFindRequest: Codable, Sendable {
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooXPCDialogClickButtonRequest: Codable, Sendable {
    public let buttonText: String
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooXPCDialogEnterTextRequest: Codable, Sendable {
    public let text: String
    public let fieldIdentifier: String?
    public let clearExisting: Bool
    public let windowTitle: String?
    public let appName: String?
}

public struct PeekabooXPCDialogHandleFileRequest: Codable, Sendable {
    public let path: String?
    public let filename: String?
    public let actionButton: String
    public let appName: String?
}

public struct PeekabooXPCDialogDismissRequest: Codable, Sendable {
    public let force: Bool
    public let windowTitle: String?
    public let appName: String?
}

public enum PeekabooXPCRequest: Codable, Sendable {
    case handshake(PeekabooXPCHandshake)
    case permissionsStatus
    case captureScreen(PeekabooXPCCaptureScreenRequest)
    case captureWindow(PeekabooXPCCaptureWindowRequest)
    case captureFrontmost(PeekabooXPCCaptureFrontmostRequest)
    case captureArea(PeekabooXPCCaptureAreaRequest)
    case detectElements(PeekabooXPCDetectElementsRequest)
    case click(PeekabooXPCClickRequest)
    case type(PeekabooXPCTypeRequest)
    case typeActions(PeekabooXPCTypeActionsRequest)
    case scroll(PeekabooXPCScrollRequest)
    case hotkey(PeekabooXPCHotkeyRequest)
    case swipe(PeekabooXPCSwipeRequest)
    case drag(PeekabooXPCDragRequest)
    case moveMouse(PeekabooXPCMoveMouseRequest)
    case waitForElement(PeekabooXPCWaitRequest)
    case listWindows(PeekabooXPCWindowTargetRequest)
    case focusWindow(PeekabooXPCWindowTargetRequest)
    case moveWindow(PeekabooXPCWindowMoveRequest)
    case resizeWindow(PeekabooXPCWindowResizeRequest)
    case setWindowBounds(PeekabooXPCWindowBoundsRequest)
    case closeWindow(PeekabooXPCWindowTargetRequest)
    case minimizeWindow(PeekabooXPCWindowTargetRequest)
    case maximizeWindow(PeekabooXPCWindowTargetRequest)
    case getFocusedWindow
    case listApplications
    case findApplication(PeekabooXPCAppIdentifierRequest)
    case getFrontmostApplication
    case isApplicationRunning(PeekabooXPCAppIdentifierRequest)
    case launchApplication(PeekabooXPCAppIdentifierRequest)
    case activateApplication(PeekabooXPCAppIdentifierRequest)
    case quitApplication(PeekabooXPCQuitAppRequest)
    case hideApplication(PeekabooXPCAppIdentifierRequest)
    case unhideApplication(PeekabooXPCAppIdentifierRequest)
    case hideOtherApplications(PeekabooXPCAppIdentifierRequest)
    case showAllApplications
    case listMenus(PeekabooXPCMenuListRequest)
    case listFrontmostMenus
    case clickMenuItem(PeekabooXPCMenuClickRequest)
    case clickMenuItemByName(PeekabooXPCMenuClickByNameRequest)
    case listMenuExtras
    case clickMenuExtra(PeekabooXPCMenuBarClickByNameRequest)
    case listMenuBarItems(Bool)
    case clickMenuBarItemNamed(PeekabooXPCMenuBarClickByNameRequest)
    case clickMenuBarItemIndex(PeekabooXPCMenuBarClickByIndexRequest)
    case listDockItems(PeekabooXPCDockListRequest)
    case launchDockItem(PeekabooXPCDockLaunchRequest)
    case rightClickDockItem(PeekabooXPCDockRightClickRequest)
    case hideDock
    case showDock
    case isDockHidden
    case findDockItem(PeekabooXPCDockFindRequest)
    case dialogFindActive(PeekabooXPCDialogFindRequest)
    case dialogClickButton(PeekabooXPCDialogClickButtonRequest)
    case dialogEnterText(PeekabooXPCDialogEnterTextRequest)
    case dialogHandleFile(PeekabooXPCDialogHandleFileRequest)
    case dialogDismiss(PeekabooXPCDialogDismissRequest)
    case dialogListElements(PeekabooXPCDialogFindRequest)
}

extension PeekabooXPCRequest {
    public var operation: PeekabooXPCOperation {
        switch self {
        case .handshake: .permissionsStatus
        case .permissionsStatus: .permissionsStatus
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
        }
    }
}

public enum PeekabooXPCResponse: Codable, Sendable {
    case handshake(PeekabooXPCHandshakeResponse)
    case permissionsStatus(PermissionsStatus)
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
    case dialogInfo(DialogInfo)
    case dialogElements(DialogElements)
    case dialogResult(DialogActionResult)
    case error(PeekabooXPCErrorEnvelope)
}

public enum PeekabooXPCErrorCode: String, Codable, Sendable {
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

public struct PeekabooXPCErrorEnvelope: Codable, Sendable, Error {
    public let code: PeekabooXPCErrorCode
    public let message: String
    public let details: String?

    public init(code: PeekabooXPCErrorCode, message: String, details: String? = nil) {
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
