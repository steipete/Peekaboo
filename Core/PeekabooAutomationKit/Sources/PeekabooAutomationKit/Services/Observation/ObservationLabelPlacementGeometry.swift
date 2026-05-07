import AppKit
import PeekabooFoundation

typealias LabelPlacementCandidate = (rect: NSRect, index: Int, type: LabelPlacementPositionType)
typealias ScoredLabelPlacementCandidate = (
    rect: NSRect,
    index: Int,
    type: LabelPlacementPositionType,
    score: Float)

enum LabelPlacementPositionType: String {
    case externalTopLeft
    case externalTopRight
    case externalBottomLeft
    case externalBottomRight
    case externalLeft
    case externalRight
    case externalAbove
    case externalBelow
}

enum LabelPlacementGeometry {
    static func isHorizontallyConstrained(
        element: DetectedElement,
        elementRect: NSRect,
        allElements: [(element: DetectedElement, rect: NSRect)]) -> Bool
    {
        let horizontalThreshold: CGFloat = 20
        var hasLeftNeighbor = false
        var hasRightNeighbor = false

        for (otherElement, otherRect) in allElements {
            guard otherElement.id != element.id else { continue }

            let verticalOverlap = min(elementRect.maxY, otherRect.maxY) - max(elementRect.minY, otherRect.minY)
            guard verticalOverlap > elementRect.height * 0.5 else { continue }

            if otherRect.maxX < elementRect.minX, elementRect.minX - otherRect.maxX < horizontalThreshold {
                hasLeftNeighbor = true
            }
            if otherRect.minX > elementRect.maxX, otherRect.minX - elementRect.maxX < horizontalThreshold {
                hasRightNeighbor = true
            }
        }

        return hasLeftNeighbor || hasRightNeighbor
    }

    static func candidatePositions(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize,
        spacing: CGFloat,
        prioritizeVertical: Bool) -> [LabelPlacementCandidate]
    {
        var positions: [LabelPlacementCandidate] = [
            (
                NSRect(
                    x: elementRect.midX - labelSize.width / 2,
                    y: elementRect.maxY + spacing,
                    width: labelSize.width,
                    height: labelSize.height),
                0,
                .externalAbove),
            (
                NSRect(
                    x: elementRect.midX - labelSize.width / 2,
                    y: elementRect.minY - labelSize.height - spacing,
                    width: labelSize.width,
                    height: labelSize.height),
                1,
                .externalBelow),
        ]

        if element.type == .button || element.type == .link {
            positions.append(contentsOf: [
                (
                    NSRect(
                        x: elementRect.minX - labelSize.width - spacing,
                        y: elementRect.maxY - labelSize.height,
                        width: labelSize.width,
                        height: labelSize.height),
                    2,
                    .externalTopLeft),
                (
                    NSRect(
                        x: elementRect.maxX + spacing,
                        y: elementRect.maxY - labelSize.height,
                        width: labelSize.width,
                        height: labelSize.height),
                    3,
                    .externalTopRight),
                (
                    NSRect(
                        x: elementRect.minX - labelSize.width - spacing,
                        y: elementRect.minY,
                        width: labelSize.width,
                        height: labelSize.height),
                    4,
                    .externalBottomLeft),
                (
                    NSRect(
                        x: elementRect.maxX + spacing,
                        y: elementRect.minY,
                        width: labelSize.width,
                        height: labelSize.height),
                    5,
                    .externalBottomRight),
            ])
        }

        positions.append(contentsOf: [
            (
                NSRect(
                    x: elementRect.maxX + spacing,
                    y: elementRect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height),
                6,
                .externalRight),
            (
                NSRect(
                    x: elementRect.minX - labelSize.width - spacing,
                    y: elementRect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height),
                7,
                .externalLeft),
        ])

        if prioritizeVertical {
            positions.sort { a, b in
                let aIsVertical = a.type == .externalAbove || a.type == .externalBelow
                let bIsVertical = b.type == .externalAbove || b.type == .externalBelow
                if aIsVertical, !bIsVertical { return true }
                if !aIsVertical, bIsVertical { return false }
                return a.index < b.index
            }
        }

        return positions
    }

    static func connectionPoint(
        for positionIndex: Int,
        elementRect: NSRect,
        isExternal: Bool) -> NSPoint?
    {
        guard isExternal else { return nil }

        switch positionIndex {
        case 0:
            return NSPoint(x: elementRect.midX, y: elementRect.maxY)
        case 1:
            return NSPoint(x: elementRect.midX, y: elementRect.minY)
        case 2, 3, 4, 5:
            return NSPoint(x: elementRect.midX, y: elementRect.midY)
        case 6:
            return NSPoint(x: elementRect.maxX, y: elementRect.midY)
        case 7:
            return NSPoint(x: elementRect.minX, y: elementRect.midY)
        default:
            return nil
        }
    }

    static func clampedRect(_ rect: NSRect, within bounds: NSRect) -> NSRect {
        let intersection = rect.intersection(bounds)
        if intersection.isNull {
            return rect
        }
        return intersection
    }
}
