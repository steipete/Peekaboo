import Foundation

@MainActor
public protocol DesktopStateSnapshotProviding: Sendable {
    func snapshot(for target: DesktopObservationTargetRequest) async throws -> DesktopStateSnapshot
}

@MainActor
public final class DesktopStateSnapshotProvider: DesktopStateSnapshotProviding {
    private let applications: any ApplicationServiceProtocol

    public init(applications: any ApplicationServiceProtocol) {
        self.applications = applications
    }

    public func snapshot(for target: DesktopObservationTargetRequest) async throws -> DesktopStateSnapshot {
        switch target {
        case .allScreens, .area, .menubar, .menubarPopover, .screen, .windowID:
            return DesktopStateSnapshot()

        case .app, .pid:
            return try await self.snapshotWithRunningApplications(frontmost: nil)

        case .frontmost:
            let frontmost = try await self.applications.getFrontmostApplication()
            return try await self.snapshotWithRunningApplications(frontmost: frontmost)
        }
    }

    private func snapshotWithRunningApplications(
        frontmost: ServiceApplicationInfo?) async throws -> DesktopStateSnapshot
    {
        let applications = try await self.applications.listApplications().data.applications
        return DesktopStateSnapshot(
            runningApplications: applications.map(ApplicationIdentity.init),
            frontmostApplication: frontmost.map(ApplicationIdentity.init))
    }
}

@MainActor
public final class EmptyDesktopStateSnapshotProvider: DesktopStateSnapshotProviding {
    public init() {}

    public func snapshot(for _: DesktopObservationTargetRequest) async throws -> DesktopStateSnapshot {
        DesktopStateSnapshot()
    }
}
