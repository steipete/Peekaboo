import PeekabooAutomationKit

/// Narrow service surface required by `PeekabooBridgeServer`.
///
/// Bridge hosts (Peekaboo.app, ClawdBot.app, or in-process callers) provide concrete
/// implementations for these services.
@MainActor
public protocol PeekabooBridgeServiceProviding: AnyObject, Sendable {
    var permissions: PermissionsService { get }
    var screenCapture: any ScreenCaptureServiceProtocol { get }
    var automation: any UIAutomationServiceProtocol { get }
    var windows: any WindowManagementServiceProtocol { get }
    var applications: any ApplicationServiceProtocol { get }
    var menu: any MenuServiceProtocol { get }
    var dock: any DockServiceProtocol { get }
    var dialogs: any DialogServiceProtocol { get }
    var snapshots: any SnapshotManagerProtocol { get }
}
