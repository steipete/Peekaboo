//
//  SmartLabelPlacer.swift
//  PeekabooCore
//

import AppKit
import Foundation
import PeekabooCore

/// Handles intelligent label placement for UI element annotations
final class SmartLabelPlacer {
    
    // MARK: - Properties
    
    private let image: NSImage
    private let imageSize: NSSize
    private let textDetector: AcceleratedTextDetector
    private let fontSize: CGFloat
    private let labelSpacing: CGFloat = 3
    private let cornerInset: CGFloat = 2
    
    // Label placement debugging
    private let debugMode: Bool
    
    // MARK: - Initialization
    
    init(image: NSImage, fontSize: CGFloat = 8, debugMode: Bool = false) {
        self.image = image
        self.imageSize = image.size
        self.textDetector = AcceleratedTextDetector()
        self.fontSize = fontSize
        self.debugMode = debugMode
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
        allElements: [(element: DetectedElement, rect: NSRect)]
    ) -> (labelRect: NSRect, connectionPoint: NSPoint?)? {
        
        if debugMode {
            Logger.shared.verbose("Finding position for \(element.id) (\(element.type)) with \(element.label ?? "no label")", category: "LabelPlacement")
        }
        
        // Check if element is horizontally constrained (has neighbors on sides)
        let isHorizontallyConstrained = isElementHorizontallyConstrained(
            element: element,
            elementRect: elementRect,
            allElements: allElements
        )
        
        // Generate candidate positions based on element type and constraints
        let candidates = generateCandidatePositions(
            for: element,
            elementRect: elementRect,
            labelSize: labelSize,
            prioritizeVertical: isHorizontallyConstrained
        )
        
        // Filter out positions that overlap with other elements or labels
        let validPositions = filterValidPositions(
            candidates: candidates,
            element: element,
            existingLabels: existingLabels,
            allElements: allElements,
            logRejections: debugMode
        )
        
        if debugMode {
            Logger.shared.verbose("Found \(validPositions.count) valid external positions out of \(candidates.count) candidates", category: "LabelPlacement")
        }
        
        // If no valid positions, try with relaxed constraints before falling back to internal
        if validPositions.isEmpty {
            if debugMode {
                Logger.shared.verbose("No valid positions with strict constraints, trying relaxed constraints", category: "LabelPlacement")
            }
            
            // Try with relaxed constraints (allow slight boundary overflow)
            let relaxedCandidates = generateCandidatePositions(
                for: element,
                elementRect: elementRect,
                labelSize: labelSize,
                prioritizeVertical: isHorizontallyConstrained,
                relaxedSpacing: true
            )
            
            let relaxedValidPositions = filterValidPositions(
                candidates: relaxedCandidates,
                element: element,
                existingLabels: existingLabels,
                allElements: allElements,
                allowBoundaryOverflow: true,
                logRejections: debugMode
            )
            
            if !relaxedValidPositions.isEmpty {
                if debugMode {
                    Logger.shared.verbose("Found \(relaxedValidPositions.count) valid positions with relaxed constraints", category: "LabelPlacement")
                }
                
                // Score and pick best relaxed position
                let scoredRelaxed = scorePositions(relaxedValidPositions, elementRect: elementRect)
                if let best = scoredRelaxed.max(by: { $0.score < $1.score }) {
                    let connectionPoint = calculateConnectionPoint(
                        for: best.index,
                        elementRect: elementRect,
                        isExternal: true
                    )
                    return (labelRect: best.rect, connectionPoint: connectionPoint)
                }
            }
            
            // Only use internal placement as absolute last resort
            if debugMode {
                Logger.shared.info("No valid external positions even with relaxed constraints, falling back to internal placement", category: "LabelPlacement")
            }
            return findInternalPosition(
                for: element,
                elementRect: elementRect,
                labelSize: labelSize
            )
        }
        
        // Score each valid position using edge detection
        let scoredPositions = scorePositions(validPositions, elementRect: elementRect)
        
        // Pick the best scoring position
        guard let best = scoredPositions.max(by: { $0.score < $1.score }) else {
            if debugMode {
                Logger.shared.verbose("No scored positions available", category: "LabelPlacement")
            }
            return nil
        }
        
        if debugMode {
            Logger.shared.verbose("Best position for \(element.id): type \(best.type) with score \(best.score) (higher = better, 1.0 = clear area, 0.0 = text/edges)", category: "LabelPlacement", metadata: [
                "elementId": element.id,
                "positionType": best.type.rawValue,
                "score": best.score
            ])
        }
        
        // Calculate connection point if needed
        let connectionPoint = calculateConnectionPoint(
            for: best.index,
            elementRect: elementRect,
            isExternal: best.index < candidates.count
        )
        
        return (labelRect: best.rect, connectionPoint: connectionPoint)
    }
    
    // MARK: - Private Methods
    
    private func isElementHorizontallyConstrained(
        element: DetectedElement,
        elementRect: NSRect,
        allElements: [(element: DetectedElement, rect: NSRect)]
    ) -> Bool {
        // Check if there are elements close to the left and right
        let horizontalThreshold: CGFloat = 20 // pixels
        
        var hasLeftNeighbor = false
        var hasRightNeighbor = false
        
        for (otherElement, otherRect) in allElements {
            guard otherElement.id != element.id else { continue }
            
            // Check if vertically aligned (similar Y position)
            let verticalOverlap = min(elementRect.maxY, otherRect.maxY) - max(elementRect.minY, otherRect.minY)
            guard verticalOverlap > elementRect.height * 0.5 else { continue }
            
            // Check horizontal proximity
            if otherRect.maxX < elementRect.minX && elementRect.minX - otherRect.maxX < horizontalThreshold {
                hasLeftNeighbor = true
            }
            if otherRect.minX > elementRect.maxX && otherRect.minX - elementRect.maxX < horizontalThreshold {
                hasRightNeighbor = true
            }
        }
        
        return hasLeftNeighbor || hasRightNeighbor
    }
    
    private func generateCandidatePositions(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize,
        prioritizeVertical: Bool = false,
        relaxedSpacing: Bool = false
    ) -> [(rect: NSRect, index: Int, type: PositionType)] {
        
        var positions: [(rect: NSRect, index: Int, type: PositionType)] = []
        let spacing = relaxedSpacing ? labelSpacing * 2 : labelSpacing
        
        // ALWAYS generate above/below positions first for ALL element types
        // This is the key fix - buttons need these positions too!
        positions.append(contentsOf: [
            // Above (priority position for horizontally constrained elements)
            (NSRect(
                x: elementRect.midX - labelSize.width / 2,
                y: elementRect.maxY + spacing,
                width: labelSize.width,
                height: labelSize.height
            ), 0, .externalAbove),
            // Below
            (NSRect(
                x: elementRect.midX - labelSize.width / 2,
                y: elementRect.minY - labelSize.height - spacing,
                width: labelSize.width,
                height: labelSize.height
            ), 1, .externalBelow),
        ])
        
        // For buttons and links, add corner positions
        if element.type == .button || element.type == .link {
            // External corners (less intrusive)
            positions.append(contentsOf: [
                // Top-left external
                (NSRect(
                    x: elementRect.minX - labelSize.width - spacing,
                    y: elementRect.maxY - labelSize.height,
                    width: labelSize.width,
                    height: labelSize.height
                ), 2, .externalTopLeft),
                // Top-right external
                (NSRect(
                    x: elementRect.maxX + spacing,
                    y: elementRect.maxY - labelSize.height,
                    width: labelSize.width,
                    height: labelSize.height
                ), 3, .externalTopRight),
                // Bottom-left external
                (NSRect(
                    x: elementRect.minX - labelSize.width - spacing,
                    y: elementRect.minY,
                    width: labelSize.width,
                    height: labelSize.height
                ), 4, .externalBottomLeft),
                // Bottom-right external
                (NSRect(
                    x: elementRect.maxX + spacing,
                    y: elementRect.minY,
                    width: labelSize.width,
                    height: labelSize.height
                ), 5, .externalBottomRight),
            ])
        }
        
        // Add side positions
        positions.append(contentsOf: [
            // Right side
            (NSRect(
                x: elementRect.maxX + spacing,
                y: elementRect.midY - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height
            ), 6, .externalRight),
            // Left side
            (NSRect(
                x: elementRect.minX - labelSize.width - spacing,
                y: elementRect.midY - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height
            ), 7, .externalLeft),
        ])
        
        // If element is horizontally constrained, prioritize vertical positions
        if prioritizeVertical {
            // Move above/below positions to the front of the array
            positions.sort { a, b in
                let aIsVertical = a.type == .externalAbove || a.type == .externalBelow
                let bIsVertical = b.type == .externalAbove || b.type == .externalBelow
                if aIsVertical && !bIsVertical { return true }
                if !aIsVertical && bIsVertical { return false }
                return a.index < b.index
            }
        }
        
        return positions
    }
    
    private func filterValidPositions(
        candidates: [(rect: NSRect, index: Int, type: PositionType)],
        element: DetectedElement,
        existingLabels: [(rect: NSRect, element: DetectedElement)],
        allElements: [(element: DetectedElement, rect: NSRect)],
        allowBoundaryOverflow: Bool = false,
        logRejections: Bool = false
    ) -> [(rect: NSRect, index: Int, type: PositionType)] {
        
        return candidates.filter { candidate in
            // Check if within image bounds (with optional relaxation)
            if !allowBoundaryOverflow {
                let withinBounds = candidate.rect.minX >= -5 && // Allow slight overflow on edges
                                  candidate.rect.maxX <= imageSize.width + 5 &&
                                  candidate.rect.minY >= -5 &&
                                  candidate.rect.maxY <= imageSize.height + 5
                
                if !withinBounds {
                    if logRejections {
                        Logger.shared.verbose("Position \(candidate.type) rejected: outside image bounds", category: "LabelPlacement", metadata: [
                            "rect": "\(candidate.rect)",
                            "imageBounds": "0,0 \(imageSize.width)x\(imageSize.height)"
                        ])
                    }
                    return false
                }
            }
            
            // Check overlap with other elements
            for (otherElement, otherRect) in allElements {
                if otherElement.id != element.id && candidate.rect.intersects(otherRect) {
                    if logRejections {
                        Logger.shared.verbose("Position \(candidate.type) rejected: overlaps with element \(otherElement.id)", category: "LabelPlacement", metadata: [
                            "candidateRect": "\(candidate.rect)",
                            "elementRect": "\(otherRect)"
                        ])
                    }
                    return false
                }
            }
            
            // Check overlap with existing labels
            for (existingLabel, labelElement) in existingLabels {
                if candidate.rect.intersects(existingLabel) {
                    if logRejections {
                        Logger.shared.verbose("Position \(candidate.type) rejected: overlaps with label for \(labelElement.id)", category: "LabelPlacement", metadata: [
                            "candidateRect": "\(candidate.rect)",
                            "existingLabelRect": "\(existingLabel)"
                        ])
                    }
                    return false
                }
            }
            
            return true
        }
    }
    
    private func scorePositions(
        _ positions: [(rect: NSRect, index: Int, type: PositionType)],
        elementRect: NSRect
    ) -> [(rect: NSRect, index: Int, type: PositionType, score: Float)] {
        
        return positions.map { position in
            // Convert from drawing coordinates to image coordinates for analysis
            // Drawing has Y=0 at top, image has Y=0 at bottom
            let imageRect = NSRect(
                x: position.rect.origin.x,
                y: imageSize.height - position.rect.origin.y - position.rect.height,
                width: position.rect.width,
                height: position.rect.height
            )
            
            // Score using edge detection
            var score = textDetector.scoreRegionForLabelPlacement(imageRect, in: image)
            
            // Boost score for preferred positions
            if position.type == .externalAbove {
                score *= 1.2 // Prefer above position
            } else if position.type == .externalBelow {
                score *= 1.1 // Second preference for below
            }
            
            // Ensure score stays in valid range
            score = min(1.0, score)
            
            if debugMode {
                Logger.shared.verbose("Scoring position \(position.index) (\(position.type))", category: "LabelPlacement", metadata: [
                    "index": position.index,
                    "type": position.type.rawValue,
                    "drawingRect": "\(position.rect)",
                    "imageRect": "\(imageRect)",
                    "score": score
                ])
            }
            
            return (rect: position.rect, index: position.index, type: position.type, score: score)
        }
    }
    
    private func findInternalPosition(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize
    ) -> (labelRect: NSRect, connectionPoint: NSPoint?)? {
        
        let insidePositions: [NSRect]
        
        if element.type == .button || element.type == .link {
            // For buttons, use corners with small inset
            insidePositions = [
                // Top-left corner
                NSRect(
                    x: elementRect.minX + cornerInset,
                    y: elementRect.maxY - labelSize.height - cornerInset,
                    width: labelSize.width,
                    height: labelSize.height
                ),
                // Top-right corner
                NSRect(
                    x: elementRect.maxX - labelSize.width - cornerInset,
                    y: elementRect.maxY - labelSize.height - cornerInset,
                    width: labelSize.width,
                    height: labelSize.height
                ),
            ]
        } else {
            // For other elements
            insidePositions = [
                // Top-left
                NSRect(
                    x: elementRect.minX + 2,
                    y: elementRect.maxY - labelSize.height - 2,
                    width: labelSize.width,
                    height: labelSize.height
                ),
            ]
        }
        
        // Find first position that fits
        for candidateRect in insidePositions {
            if elementRect.contains(candidateRect) {
                // Score this internal position
                let imageRect = NSRect(
                    x: candidateRect.origin.x,
                    y: imageSize.height - candidateRect.origin.y - candidateRect.height,
                    width: candidateRect.width,
                    height: candidateRect.height
                )
                
                let score = textDetector.scoreRegionForLabelPlacement(imageRect, in: image)
                
                // Only use if score is acceptable (low edge density)
                if score > 0.5 {
                    return (labelRect: candidateRect, connectionPoint: nil)
                }
            }
        }
        
        // Ultimate fallback - center
        let centerRect = NSRect(
            x: elementRect.midX - labelSize.width / 2,
            y: elementRect.midY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
        
        return (labelRect: centerRect, connectionPoint: nil)
    }
    
    private func calculateConnectionPoint(
        for positionIndex: Int,
        elementRect: NSRect,
        isExternal: Bool
    ) -> NSPoint? {
        
        guard isExternal else { return nil }
        
        // Connection points for external positions
        // Updated to match new position indices
        switch positionIndex {
        case 0: // Above
            return NSPoint(x: elementRect.midX, y: elementRect.maxY)
        case 1: // Below
            return NSPoint(x: elementRect.midX, y: elementRect.minY)
        case 2, 3, 4, 5: // Corner positions
            return NSPoint(x: elementRect.midX, y: elementRect.midY)
        case 6: // Right
            return NSPoint(x: elementRect.maxX, y: elementRect.midY)
        case 7: // Left
            return NSPoint(x: elementRect.minX, y: elementRect.midY)
        default:
            return nil
        }
    }
    
    // MARK: - Types
    
    private enum PositionType: String {
        case externalTopLeft
        case externalTopRight
        case externalBottomLeft
        case externalBottomRight
        case externalLeft
        case externalRight
        case externalAbove
        case externalBelow
        case internalTopLeft
        case internalTopRight
        case internalCenter
    }
}

// MARK: - Debug Visualization

extension SmartLabelPlacer {
    
    /// Creates a debug image showing edge detection results
    func createDebugVisualization(for rect: NSRect) -> NSImage? {
        // Convert to image coordinates
        let imageRect = NSRect(
            x: rect.origin.x,
            y: imageSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        
        let result = textDetector.analyzeRegion(imageRect, in: image)
        
        // Create visualization showing edge density
        let debugImage = NSImage(size: rect.size)
        debugImage.lockFocus()
        
        // Draw background color based on edge density
        let color: NSColor
        if result.hasText {
            color = NSColor.red.withAlphaComponent(0.5) // Bad for labels
        } else {
            color = NSColor.green.withAlphaComponent(0.5) // Good for labels
        }
        
        color.setFill()
        NSRect(origin: .zero, size: rect.size).fill()
        
        // Draw edge density percentage
        let text = String(format: "%.1f%%", result.density * 100)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white
        ]
        text.draw(at: NSPoint(x: 2, y: 2), withAttributes: attributes)
        
        debugImage.unlockFocus()
        
        return debugImage
    }
}