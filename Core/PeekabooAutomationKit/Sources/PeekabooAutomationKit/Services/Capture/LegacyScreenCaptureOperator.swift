import Foundation
import PeekabooFoundation

@MainActor
final class LegacyScreenCaptureOperator: LegacyScreenCaptureOperating, @unchecked Sendable {
    let logger: CategoryLogger

    init(logger: CategoryLogger) {
        self.logger = logger
    }
}
