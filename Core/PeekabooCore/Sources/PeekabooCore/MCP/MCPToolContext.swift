import Foundation
import PeekabooFoundation

/// Lightweight dependency container for MCP tools so they no longer reach for
/// global singletons directly. Each tool can receive the subset of
/// services it needs, which keeps tests deterministic and unlocks DI.
public struct MCPToolContext: @unchecked Sendable {
    public let automation: any UIAutomationServiceProtocol
    public let menu: any MenuServiceProtocol
    public let windows: any WindowManagementServiceProtocol
    public let applications: any ApplicationServiceProtocol
    public let dialogs: any DialogServiceProtocol
    public let dock: any DockServiceProtocol
    public let screenCapture: any ScreenCaptureServiceProtocol
    public let sessions: any SessionManagerProtocol
    public let screens: any ScreenServiceProtocol
    public let agent: (any AgentServiceProtocol)?
    public let permissions: PermissionsService

    @TaskLocal
    private static var taskOverride: MCPToolContext?

    private static let defaultShared: MCPToolContext = MainActor.assumeIsolated {
        MCPToolContext(services: PeekabooServices())
    }

    /// Default context backed by a process-local `PeekabooServices` instance.
    public static var shared: MCPToolContext { self.taskOverride ?? self.defaultShared }

    /// Temporarily override the shared context for the lifetime of `operation`.
    public static func withContext<T>(
        _ context: MCPToolContext,
        perform operation: () async throws -> T) async rethrows -> T
    {
        try await self.$taskOverride.withValue(context) {
            try await operation()
        }
    }

    /// Produce a fresh context using the process-wide services locator.
    @MainActor
    public static func makeDefault() -> MCPToolContext {
        MCPToolContext(services: PeekabooServices())
    }

    public init(
        automation: any UIAutomationServiceProtocol,
        menu: any MenuServiceProtocol,
        windows: any WindowManagementServiceProtocol,
        applications: any ApplicationServiceProtocol,
        dialogs: any DialogServiceProtocol,
        dock: any DockServiceProtocol,
        screenCapture: any ScreenCaptureServiceProtocol,
        sessions: any SessionManagerProtocol,
        screens: any ScreenServiceProtocol,
        agent: (any AgentServiceProtocol)?,
        permissions: PermissionsService)
    {
        self.automation = automation
        self.menu = menu
        self.windows = windows
        self.applications = applications
        self.dialogs = dialogs
        self.dock = dock
        self.screenCapture = screenCapture
        self.sessions = sessions
        self.screens = screens
        self.agent = agent
        self.permissions = permissions
    }

    @MainActor
    public init(services: any PeekabooServiceProviding) {
        self.init(
            automation: services.automation,
            menu: services.menu,
            windows: services.windows,
            applications: services.applications,
            dialogs: services.dialogs,
            dock: services.dock,
            screenCapture: services.screenCapture,
            sessions: services.sessions,
            screens: services.screens,
            agent: services.agent,
            permissions: services.permissions)
    }
}
