import Foundation
import PeekabooAutomationKit

extension PeekabooBridgeClient {
    public func desktopObservation(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult {
        let response = try await self.send(.desktopObservation(request))
        switch response {
        case let .desktopObservation(result):
            return result
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(
                code: .invalidRequest,
                message: "Unexpected desktop observation response")
        }
    }
}
