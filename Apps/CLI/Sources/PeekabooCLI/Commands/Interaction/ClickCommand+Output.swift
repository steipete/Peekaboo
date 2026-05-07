import CoreGraphics
import Foundation

struct ClickResult: Codable {
    let success: Bool
    let clickedElement: String?
    let clickLocation: [String: Double]
    let waitTime: Double
    let executionTime: TimeInterval
    let targetApp: String
    let targetPoint: InteractionTargetPointDiagnostics?

    init(
        success: Bool,
        clickedElement: String?,
        clickLocation: CGPoint,
        waitTime: Double,
        executionTime: TimeInterval,
        targetApp: String,
        targetPoint: InteractionTargetPointDiagnostics? = nil
    ) {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
        self.targetApp = targetApp
        self.targetPoint = targetPoint
    }
}
