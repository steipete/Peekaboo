import AppKit
import Foundation
import PeekabooFoundation

extension SmartLabelPlacer {
    func scorePositions(
        _ positions: [LabelPlacementCandidate],
        elementRect _: NSRect) -> [ScoredLabelPlacementCandidate]
    {
        positions.map { position in
            let imageRect = self.imageRect(forDrawingRect: position.rect)
            let scoringRect = self.scoringRect(forImageRect: imageRect)
            var score = self.textDetector.scoreRegionForLabelPlacement(scoringRect, in: self.image)

            if position.type == .externalAbove {
                score *= 1.2
            } else if position.type == .externalBelow {
                score *= 1.1
            }

            score = min(1.0, score)
            self.logScore(position: position, imageRect: imageRect, score: score)

            return (rect: position.rect, index: position.index, type: position.type, score: score)
        }
    }

    func imageRect(forDrawingRect rect: NSRect) -> NSRect {
        NSRect(
            x: rect.origin.x,
            y: self.imageSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height)
    }

    private func scoringRect(forImageRect imageRect: NSRect) -> NSRect {
        // Sample beyond label bounds so busy neighboring text/edges penalize placement.
        LabelPlacementGeometry.clampedRect(
            imageRect.insetBy(dx: -self.scoreRegionPadding, dy: -self.scoreRegionPadding),
            within: NSRect(origin: .zero, size: self.imageSize))
    }

    private func logScore(
        position: LabelPlacementCandidate,
        imageRect: NSRect,
        score: Float)
    {
        guard self.debugMode else { return }

        self.logger.verbose(
            "Scoring position \(position.index) (\(position.type))",
            category: "LabelPlacement",
            metadata: [
                "index": position.index,
                "type": position.type.rawValue,
                "drawingRect": "\(position.rect)",
                "imageRect": "\(imageRect)",
                "score": score,
            ])
    }
}
