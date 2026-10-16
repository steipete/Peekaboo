import Foundation
import PeekabooAutomationKitTestSupport
import Testing
@testable import PeekabooAutomationKit

struct DialogServiceOperationLaneTests {
    @Test
    @MainActor
    func `Cancelled queued dialog action never resolves or dispatches`() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-dialog-lane-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let retryRelease = AsyncStream<Void>.makeStream()
        defer { retryRelease.continuation.finish() }
        let actionQueued = AsyncStream<Void>.makeStream()
        let coordinator = DesktopOperationLaneCoordinator(
            coordinationRootURL: root,
            retrySleep: {
                actionQueued.continuation.yield()
                for await _ in retryRelease.stream {}
                try Task.checkCancellation()
            })
        let ownerStarted = AsyncStream<Void>.makeStream()
        let ownerRelease = AsyncStream<Void>.makeStream()
        defer { ownerRelease.continuation.finish() }
        let service = DialogService(
            syntheticInputDriver: SyntheticInputDriver(),
            operationLaneCoordinator: coordinator)

        try await withTestReleaseWatchdog(
            "Timed out waiting for queued dialog cancellation; releasing the owner",
            release: {
                ownerRelease.continuation.finish()
                retryRelease.continuation.finish()
            }, operation: {
                let owner = Task {
                    defer { ownerStarted.continuation.finish() }
                    try await coordinator.run(scope: .global, access: .write) {
                        ownerStarted.continuation.yield()
                        for await _ in ownerRelease.stream {}
                    }
                }
                var ownerStarts = ownerStarted.stream.makeAsyncIterator()
                try #require(await ownerStarts.next() != nil, "Owner completed before acquiring its lane")
                let dialogAction = Task { @MainActor in
                    defer { actionQueued.continuation.finish() }
                    return try await service.clickButton(
                        buttonText: "Never dispatch",
                        windowTitle: "Missing dialog",
                        appName: nil)
                }
                var retries = actionQueued.stream.makeAsyncIterator()
                #expect(await retries.next() != nil, "Dialog action completed before reporting contention")
                dialogAction.cancel()
                await #expect(throws: CancellationError.self) {
                    try await dialogAction.value
                }
                ownerRelease.continuation.finish()
                try await owner.value
            })
    }
}
