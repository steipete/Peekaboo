import CoreGraphics
import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooFoundation

@MainActor
public final class RemoteApplicationService: ApplicationServiceProtocol {
    private let client: PeekabooBridgeClient
    private let localFallback: (any ApplicationServiceProtocol)?

    public init(client: PeekabooBridgeClient, localFallback: (any ApplicationServiceProtocol)? = nil) {
        self.client = client
        self.localFallback = localFallback
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
        try await self.runWithLifecycleFallback {
            try await self.client.activateApplication(identifier: identifier)
        } fallback: { fallback in
            try await fallback.activateApplication(identifier: identifier)
        }
    }

    public func quitApplication(identifier: String, force: Bool) async throws -> Bool {
        try await self.client.quitApplication(identifier: identifier, force: force)
    }

    public func hideApplication(identifier: String) async throws {
        try await self.runWithLifecycleFallback {
            try await self.client.hideApplication(identifier: identifier)
        } fallback: { fallback in
            try await fallback.hideApplication(identifier: identifier)
        }
    }

    public func unhideApplication(identifier: String) async throws {
        try await self.runWithLifecycleFallback {
            try await self.client.unhideApplication(identifier: identifier)
        } fallback: { fallback in
            try await fallback.unhideApplication(identifier: identifier)
        }
    }

    public func hideOtherApplications(identifier: String) async throws {
        try await self.runWithLifecycleFallback {
            try await self.client.hideOtherApplications(identifier: identifier)
        } fallback: { fallback in
            try await fallback.hideOtherApplications(identifier: identifier)
        }
    }

    public func showAllApplications() async throws {
        try await self.runWithLifecycleFallback {
            try await self.client.showAllApplications()
        } fallback: { fallback in
            try await fallback.showAllApplications()
        }
    }

    private func runWithLifecycleFallback(
        operation: () async throws -> Void,
        fallback: (any ApplicationServiceProtocol) async throws -> Void) async throws
    {
        do {
            try await operation()
        } catch {
            guard let localFallback, Self.shouldUseLocalFallback(for: error) else {
                throw error
            }
            try await fallback(localFallback)
        }
    }

    private static func shouldUseLocalFallback(for error: any Error) -> Bool {
        guard let envelope = error as? PeekabooBridgeErrorEnvelope else {
            return false
        }
        switch envelope.code {
        case .internalError:
            return true
        case .permissionDenied:
            return envelope.permission == .appleScript
        default:
            return false
        }
    }
}
