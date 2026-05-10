import Foundation
import PeekabooAutomationKit
import PeekabooBridge

@MainActor
public final class RemoteDesktopObservationService: DesktopObservationServiceProtocol {
    private let client: PeekabooBridgeClient

    public init(client: PeekabooBridgeClient) {
        self.client = client
    }

    public func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult {
        try await self.client.desktopObservation(request)
    }
}
