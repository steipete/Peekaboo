import AppKit
import Foundation
import PeekabooFoundation

extension SmartLabelPlacer {
    func filterValidPositions(
        candidates: [LabelPlacementCandidate],
        element: DetectedElement,
        existingLabels: [(rect: NSRect, element: DetectedElement)],
        allElements: [(element: DetectedElement, rect: NSRect)],
        allowBoundaryOverflow: Bool = false,
        logRejections: Bool = false) -> [LabelPlacementCandidate]
    {
        candidates.filter { candidate in
            if !allowBoundaryOverflow, !self.isWithinImageBounds(candidate.rect) {
                self.logPositionRejected(
                    "Position \(candidate.type) rejected: outside image bounds",
                    logRejections: logRejections,
                    metadata: [
                        "rect": "\(candidate.rect)",
                        "imageBounds": "0,0 \(self.imageSize.width)x\(self.imageSize.height)",
                    ])
                return false
            }

            for (otherElement, otherRect) in allElements {
                if otherElement.id != element.id, candidate.rect.intersects(otherRect) {
                    self.logPositionRejected(
                        "Position \(candidate.type) rejected: overlaps with element \(otherElement.id)",
                        logRejections: logRejections,
                        metadata: [
                            "candidateRect": "\(candidate.rect)",
                            "elementRect": "\(otherRect)",
                        ])
                    return false
                }
            }

            for (existingLabel, labelElement) in existingLabels where candidate.rect.intersects(existingLabel) {
                self.logPositionRejected(
                    "Position \(candidate.type) rejected: overlaps with label for \(labelElement.id)",
                    logRejections: logRejections,
                    metadata: [
                        "candidateRect": "\(candidate.rect)",
                        "existingLabelRect": "\(existingLabel)",
                    ])
                return false
            }

            return true
        }
    }

    private func isWithinImageBounds(_ rect: NSRect) -> Bool {
        rect.minX >= -5 &&
            rect.maxX <= self.imageSize.width + 5 &&
            rect.minY >= -5 &&
            rect.maxY <= self.imageSize.height + 5
    }

    private func logPositionRejected(
        _ message: String,
        logRejections: Bool,
        metadata: [String: Any])
    {
        guard logRejections else { return }

        self.logger.verbose(
            message,
            category: "LabelPlacement",
            metadata: metadata)
    }
}
