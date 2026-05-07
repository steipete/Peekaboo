import Foundation
import PeekabooCore

struct SwipeResult: Codable {
    let success: Bool
    let fromLocation: [String: Double]
    let toLocation: [String: Double]
    let distance: Double
    let duration: Int
    let steps: Int
    let profile: String
    let fromTargetPoint: InteractionTargetPointDiagnostics?
    let toTargetPoint: InteractionTargetPointDiagnostics?
    let executionTime: TimeInterval
}
