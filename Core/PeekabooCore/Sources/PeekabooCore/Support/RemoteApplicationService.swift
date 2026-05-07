import CoreGraphics
import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooBridge
import PeekabooFoundation

@MainActor
public final class RemoteApplicationService: ApplicationServiceProtocol {
    private let client: PeekabooBridgeClient

    public init(client: PeekabooBridgeClient) {
        self.client = client
    }

    public func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        let apps = try await self.client.listApplications()
        return UnifiedToolOutput(
            data: ServiceApplicationListData(applications: apps),
            summary: .init(brief: "Found \(apps.count) apps", status: .success, counts: ["applications": apps.count]),
            metadata: .init(duration: 0))
    }

    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await self.client.findApplication(identifier: identifier)
    }

    public func listWindows(for appIdentifier: String, timeout: Float?) async throws
        -> UnifiedToolOutput<ServiceWindowListData>
    {
        // Reuse window listing filtered by application via WindowTarget.application
        let windows = try await self.client.listWindows(target: .application(appIdentifier))
        let data = ServiceWindowListData(windows: windows, targetApplication: nil)
        return UnifiedToolOutput(
            data: data,
            summary: .init(
                brief: "Found \(windows.count) windows",
                status: .success,
                counts: ["windows": windows.count]),
            metadata: .init(duration: 0))
    }

    public func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        try await self.client.getFrontmostApplication()
    }

    public func isApplicationRunning(identifier: String) async -> Bool {
        await (try? self.client.isApplicationRunning(identifier: identifier)) ?? false
    }

    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await self.client.launchApplication(identifier: identifier)
    }

    public func activateApplication(identifier: String) async throws {
        try await self.client.activateApplication(identifier: identifier)
    }

    public func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        try await self.client.quitApplication(identifier: identifier, force: force)
    }

    public func hideApplication(identifier: String) async throws {
        try await self.client.hideApplication(identifier: identifier)
    }

    public func unhideApplication(identifier: String) async throws {
        try await self.client.unhideApplication(identifier: identifier)
    }

    public func hideOtherApplications(identifier: String) async throws {
        try await self.client.hideOtherApplications(identifier: identifier)
    }

    public func showAllApplications() async throws {
        try await self.client.showAllApplications()
    }
}
