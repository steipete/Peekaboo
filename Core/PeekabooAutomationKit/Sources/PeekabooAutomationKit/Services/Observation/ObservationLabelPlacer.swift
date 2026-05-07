import AppKit
import Foundation
import PeekabooFoundation

/// Handles intelligent label placement for UI element annotations
@MainActor
final class SmartLabelPlacer {
    static let defaultScoreRegionPadding: CGFloat = 6

    // MARK: - Properties

    let image: NSImage
    let imageSize: NSSize
    let textDetector: any SmartLabelPlacerTextDetecting
    let fontSize: CGFloat
    let labelSpacing: CGFloat = 3
    let cornerInset: CGFloat = 2
    let scoreRegionPadding: CGFloat

    // Label placement debugging
    let debugMode: Bool
    let logger: ObservationAnnotationLog

    // MARK: - Initialization

    init(
        image: NSImage,
        fontSize: CGFloat = 8,
        debugMode: Bool = false,
        logger: ObservationAnnotationLog = .disabled,
        textDetector: (any SmartLabelPlacerTextDetecting)? = nil)
    {
        self.image = image
        self.imageSize = image.size
        self.textDetector = textDetector ?? AcceleratedTextDetector(logger: logger)
        self.fontSize = fontSize
        self.debugMode = debugMode
        self.logger = logger
        self.scoreRegionPadding = Self.defaultScoreRegionPadding
    }

    // MARK: - Public Methods

    /// Finds the best position for a label given an element's bounds
    /// - Parameters:
    ///   - element: The detected UI element
    ///   - elementRect: The element's rectangle in drawing coordinates (Y-flipped)
    ///   - labelSize: The size of the label to place
    ///   - existingLabels: Already placed labels to avoid overlapping
    ///   - allElements: All elements to avoid overlapping with
    /// - Returns: Tuple of (labelRect, connectionPoint) or nil if no good position found
    func findBestLabelPosition(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize,
        existingLabels: [(rect: NSRect, element: DetectedElement)],
        allElements: [(element: DetectedElement, rect: NSRect)]) -> (labelRect: NSRect, connectionPoint: NSPoint?)?
    {
        // Finds the best position for a label given an element's bounds
        if self.debugMode {
            self.logger.verbose(
                "Finding position for \(element.id) (\(element.type)) with \(element.label ?? "no label")",
                category: "LabelPlacement")
        }

        // Check if element is horizontally constrained (has neighbors on sides)
        let isHorizontallyConstrained = LabelPlacementGeometry.isHorizontallyConstrained(
            element: element,
            elementRect: elementRect,
            allElements: allElements)

        // Generate candidate positions based on element type and constraints
        let candidates = self.generateCandidatePositions(
            for: element,
            elementRect: elementRect,
            labelSize: labelSize,
            prioritizeVertical: isHorizontallyConstrained)

        // Filter out positions that overlap with other elements or labels
        let validPositions = self.filterValidPositions(
            candidates: candidates,
            element: element,
            existingLabels: existingLabels,
            allElements: allElements,
            logRejections: self.debugMode)

        if self.debugMode {
            self.logger.verbose(
                "Found \(validPositions.count) valid external positions out of \(candidates.count) candidates",
                category: "LabelPlacement")
        }

        // If no valid positions, try with relaxed constraints before falling back to internal
        if validPositions.isEmpty {
            if self.debugMode {
                self.logger.verbose(
                    "No valid positions with strict constraints, trying relaxed constraints",
                    category: "LabelPlacement")
            }

            // Try with relaxed constraints (allow slight boundary overflow)
            let relaxedCandidates = self.generateCandidatePositions(
                for: element,
                elementRect: elementRect,
                labelSize: labelSize,
                prioritizeVertical: isHorizontallyConstrained,
                relaxedSpacing: true)

            let relaxedValidPositions = self.filterValidPositions(
                candidates: relaxedCandidates,
                element: element,
                existingLabels: existingLabels,
                allElements: allElements,
                allowBoundaryOverflow: true,
                logRejections: self.debugMode)

            if !relaxedValidPositions.isEmpty {
                if self.debugMode {
                    self.logger.verbose(
                        "Found \(relaxedValidPositions.count) valid positions with relaxed constraints",
                        category: "LabelPlacement")
                }

                // Score and pick best relaxed position
                let scoredRelaxed = self.scorePositions(relaxedValidPositions, elementRect: elementRect)
                if let best = scoredRelaxed.max(by: { $0.score < $1.score }) {
                    let connectionPoint = LabelPlacementGeometry.connectionPoint(
                        for: best.index,
                        elementRect: elementRect,
                        isExternal: true)
                    return (labelRect: best.rect, connectionPoint: connectionPoint)
                }
            }

            // Only use internal placement as absolute last resort
            if self.debugMode {
                self.logger.info(
                    "No valid external positions even with relaxed constraints, falling back to internal placement",
                    category: "LabelPlacement")
            }
            return self.findInternalPosition(
                for: element,
                elementRect: elementRect,
                labelSize: labelSize)
        }

        // Score each valid position using edge detection
        let scoredPositions = self.scorePositions(validPositions, elementRect: elementRect)

        // Pick the best scoring position
        guard let best = scoredPositions.max(by: { $0.score < $1.score }) else {
            if self.debugMode {
                self.logger.verbose("No scored positions available", category: "LabelPlacement")
            }
            return nil
        }

        if self.debugMode {
            self.logger.verbose(
                """
                Best position for \(element.id): type \(best.type) with score \(best.score) \
                (higher = better, 1.0 = clear area, 0.0 = text/edges)
                """,
                category: "LabelPlacement",
                metadata: [
                    "elementId": element.id,
                    "positionType": best.type.rawValue,
                    "score": best.score,
                ])
        }

        // Calculate connection point if needed
        let connectionPoint = LabelPlacementGeometry.connectionPoint(
            for: best.index,
            elementRect: elementRect,
            isExternal: best.index < candidates.count)

        return (labelRect: best.rect, connectionPoint: connectionPoint)
    }

    // MARK: - Private Methods

    private func generateCandidatePositions(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize,
        prioritizeVertical: Bool = false,
        relaxedSpacing: Bool = false) -> [LabelPlacementCandidate]
    {
        let spacing = relaxedSpacing ? self.labelSpacing * 2 : self.labelSpacing
        return LabelPlacementGeometry.candidatePositions(
            for: element,
            elementRect: elementRect,
            labelSize: labelSize,
            spacing: spacing,
            prioritizeVertical: prioritizeVertical)
    }

    private func findInternalPosition(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize) -> (labelRect: NSRect, connectionPoint: NSPoint?)?
    {
        let insidePositions: [NSRect] = if element.type == .button || element.type == .link {
            // For buttons, use corners with small inset
            [
                // Top-left corner
                NSRect(
                    x: elementRect.minX + self.cornerInset,
                    y: elementRect.maxY - labelSize.height - self.cornerInset,
                    width: labelSize.width,
                    height: labelSize.height),
                // Top-right corner
                NSRect(
                    x: elementRect.maxX - labelSize.width - self.cornerInset,
                    y: elementRect.maxY - labelSize.height - self.cornerInset,
                    width: labelSize.width,
                    height: labelSize.height),
            ]
        } else {
            // For other elements
            [
                // Top-left
                NSRect(
                    x: elementRect.minX + 2,
                    y: elementRect.maxY - labelSize.height - 2,
                    width: labelSize.width,
                    height: labelSize.height),
            ]
        }

        // Find first position that fits
        for candidateRect in insidePositions where elementRect.contains(candidateRect) {
            // Score this internal position
            let imageRect = NSRect(
                x: candidateRect.origin.x,
                y: self.imageSize.height - candidateRect.origin.y - candidateRect.height,
                width: candidateRect.width,
                height: candidateRect.height)

            let score = self.textDetector.scoreRegionForLabelPlacement(imageRect, in: self.image)

            // Only use if score is acceptable (low edge density)
            if score > 0.5 {
                return (labelRect: candidateRect, connectionPoint: nil)
            }
        }

        // Ultimate fallback - center
        let centerRect = NSRect(
            x: elementRect.midX - labelSize.width / 2,
            y: elementRect.midY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height)

        return (labelRect: centerRect, connectionPoint: nil)
    }
}
