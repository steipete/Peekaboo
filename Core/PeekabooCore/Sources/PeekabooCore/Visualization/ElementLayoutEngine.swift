//
import PeekabooFoundation
//  ElementLayoutEngine.swift
//  PeekabooCore
//
//  Layout calculations for element visualization
//

import CoreGraphics
import Foundation

/// Handles layout calculations for element visualization
@MainActor
public final class ElementLayoutEngine {
    public init() {}

    // MARK: - Indicator Positioning

    /// Calculate position for element indicator
    /// - Parameters:
    ///   - bounds: Element bounds
    ///   - style: Indicator style
    /// - Returns: Center point for the indicator
    public func calculateIndicatorPosition(
        for bounds: CGRect,
        style: IndicatorStyle) -> CGPoint
    {
        switch style {
        case let .circle(diameter, position):
            let halfDiameter = diameter / 2
            switch position {
            case .topLeft:
                return CGPoint(
                    x: bounds.minX + halfDiameter,
                    y: bounds.minY + halfDiameter)
            case .topRight:
                return CGPoint(
                    x: bounds.maxX - halfDiameter,
                    y: bounds.minY + halfDiameter)
            case .bottomLeft:
                return CGPoint(
                    x: bounds.minX + halfDiameter,
                    y: bounds.maxY - halfDiameter)
            case .bottomRight:
                return CGPoint(
                    x: bounds.maxX - halfDiameter,
                    y: bounds.maxY - halfDiameter)
            }

        case .rectangle, .custom:
            // Rectangle indicators are centered on the element
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    // MARK: - Label Positioning

    /// Calculate optimal position for element label
    /// - Parameters:
    ///   - bounds: Element bounds
    ///   - containerSize: Size of the container
    ///   - labelSize: Size of the label
    ///   - indicatorStyle: Style of the indicator (affects label placement)
    /// - Returns: Center point for the label
    public func calculateLabelPosition(
        for bounds: CGRect,
        containerSize: CGSize,
        labelSize: CGSize = CGSize(width: 60, height: 20),
        indicatorStyle: IndicatorStyle) -> CGPoint
    {
        let spacing: CGFloat = 4
        let halfLabelHeight = labelSize.height / 2
        let halfLabelWidth = labelSize.width / 2

        // For circle indicators, position label near the indicator
        if case let .circle(diameter, position) = indicatorStyle {
            let indicatorPos = self.calculateIndicatorPosition(for: bounds, style: indicatorStyle)

            switch position {
            case .topLeft:
                // Try to position to the right of the indicator
                let rightX = indicatorPos.x + diameter / 2 + spacing + halfLabelWidth
                if rightX + halfLabelWidth <= containerSize.width {
                    return CGPoint(x: rightX, y: indicatorPos.y)
                }
                // Fall back to below
                return CGPoint(x: indicatorPos.x, y: indicatorPos.y + diameter / 2 + spacing + halfLabelHeight)

            case .topRight:
                // Try to position to the left of the indicator
                let leftX = indicatorPos.x - diameter / 2 - spacing - halfLabelWidth
                if leftX - halfLabelWidth >= 0 {
                    return CGPoint(x: leftX, y: indicatorPos.y)
                }
                // Fall back to below
                return CGPoint(x: indicatorPos.x, y: indicatorPos.y + diameter / 2 + spacing + halfLabelHeight)

            case .bottomLeft, .bottomRight:
                // Position above the indicator
                return CGPoint(x: indicatorPos.x, y: indicatorPos.y - diameter / 2 - spacing - halfLabelHeight)
            }
        }

        // For rectangle indicators, try different positions
        // Priority: above > below > inside center

        // Try above first
        let aboveY = bounds.minY - spacing - halfLabelHeight
        if aboveY - halfLabelHeight >= 0 {
            return CGPoint(x: bounds.midX, y: aboveY)
        }

        // Try below
        let belowY = bounds.maxY + spacing + halfLabelHeight
        if belowY + halfLabelHeight <= containerSize.height {
            return CGPoint(x: bounds.midX, y: belowY)
        }

        // Fall back to center
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Bounds Calculations

    /// Calculate expanded bounds for hover effects
    /// - Parameters:
    ///   - bounds: Original element bounds
    ///   - expansion: Amount to expand in all directions
    /// - Returns: Expanded bounds
    public func expandedBounds(
        for bounds: CGRect,
        expansion: CGFloat = 2) -> CGRect
    {
        bounds.insetBy(dx: -expansion, dy: -expansion)
    }

    /// Calculate bounds for element group
    /// - Parameter elements: Array of elements to group
    /// - Returns: Bounding box containing all elements
    public func groupBounds(for elements: [VisualizableElement]) -> CGRect? {
        guard !elements.isEmpty else { return nil }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for element in elements {
            minX = min(minX, element.bounds.minX)
            minY = min(minY, element.bounds.minY)
            maxX = max(maxX, element.bounds.maxX)
            maxY = max(maxY, element.bounds.maxY)
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY)
    }

    // MARK: - Overlap Detection

    /// Check if two elements overlap
    public func elementsOverlap(_ element1: VisualizableElement, _ element2: VisualizableElement) -> Bool {
        element1.bounds.intersects(element2.bounds)
    }

    /// Find overlapping elements in a collection
    public func findOverlappingElements(in elements: [VisualizableElement]) -> [(
        VisualizableElement,
        VisualizableElement)]
    {
        var overlaps: [(VisualizableElement, VisualizableElement)] = []

        for i in 0..<elements.count {
            for j in (i + 1)..<elements.count {
                if self.elementsOverlap(elements[i], elements[j]) {
                    overlaps.append((elements[i], elements[j]))
                }
            }
        }

        return overlaps
    }

    // MARK: - Layout Optimization

    /// Optimize label positions to avoid overlaps
    public func optimizeLabelPositions(
        for elements: [VisualizableElement],
        containerSize: CGSize,
        labelSize: CGSize = CGSize(width: 60, height: 20),
        indicatorStyle: IndicatorStyle) -> [String: CGPoint]
    {
        var positions: [String: CGPoint] = [:]
        var occupiedRects: [CGRect] = []

        // Sort elements by Y position for top-to-bottom processing
        let sortedElements = elements.sorted { $0.bounds.minY < $1.bounds.minY }

        for element in sortedElements {
            var bestPosition = self.calculateLabelPosition(
                for: element.bounds,
                containerSize: containerSize,
                labelSize: labelSize,
                indicatorStyle: indicatorStyle)

            // Check for overlaps with existing labels
            let labelRect = CGRect(
                x: bestPosition.x - labelSize.width / 2,
                y: bestPosition.y - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height)

            // If overlapping, try alternative positions
            if occupiedRects.contains(where: { $0.intersects(labelRect) }) {
                let alternatives = self.generateAlternativePositions(
                    for: element.bounds,
                    containerSize: containerSize,
                    labelSize: labelSize)

                for altPos in alternatives {
                    let altRect = CGRect(
                        x: altPos.x - labelSize.width / 2,
                        y: altPos.y - labelSize.height / 2,
                        width: labelSize.width,
                        height: labelSize.height)

                    if !occupiedRects.contains(where: { $0.intersects(altRect) }) {
                        bestPosition = altPos
                        occupiedRects.append(altRect)
                        break
                    }
                }
            } else {
                occupiedRects.append(labelRect)
            }

            positions[element.id] = bestPosition
        }

        return positions
    }

    // MARK: - Private Methods

    private func generateAlternativePositions(
        for bounds: CGRect,
        containerSize: CGSize,
        labelSize: CGSize) -> [CGPoint]
    {
        let spacing: CGFloat = 4
        let halfWidth = labelSize.width / 2
        let halfHeight = labelSize.height / 2

        var positions: [CGPoint] = []

        // Try all four sides
        let candidates = [
            CGPoint(x: bounds.midX, y: bounds.minY - spacing - halfHeight), // Above
            CGPoint(x: bounds.midX, y: bounds.maxY + spacing + halfHeight), // Below
            CGPoint(x: bounds.minX - spacing - halfWidth, y: bounds.midY), // Left
            CGPoint(x: bounds.maxX + spacing + halfWidth, y: bounds.midY), // Right
            CGPoint(x: bounds.minX, y: bounds.minY - spacing - halfHeight), // Top-left
            CGPoint(x: bounds.maxX, y: bounds.minY - spacing - halfHeight), // Top-right
            CGPoint(x: bounds.minX, y: bounds.maxY + spacing + halfHeight), // Bottom-left
            CGPoint(x: bounds.maxX, y: bounds.maxY + spacing + halfHeight), // Bottom-right
        ]

        // Filter positions that fit within container
        for candidate in candidates {
            if candidate.x - halfWidth >= 0,
               candidate.x + halfWidth <= containerSize.width,
               candidate.y - halfHeight >= 0,
               candidate.y + halfHeight <= containerSize.height
            {
                positions.append(candidate)
            }
        }

        return positions
    }
}
