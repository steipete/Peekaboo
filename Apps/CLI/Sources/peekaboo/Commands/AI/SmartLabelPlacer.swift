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
        
        // Generate candidate positions based on element type
        let candidates = generateCandidatePositions(
            for: element,
            elementRect: elementRect,
            labelSize: labelSize
        )
        
        // Filter out positions that overlap with other elements or labels
        let validPositions = filterValidPositions(
            candidates: candidates,
            element: element,
            existingLabels: existingLabels,
            allElements: allElements
        )
        
        if debugMode {
            Logger.shared.verbose("Found \(validPositions.count) valid external positions out of \(candidates.count) candidates", category: "LabelPlacement")
        }
        
        guard !validPositions.isEmpty else {
            if debugMode {
                Logger.shared.verbose("No valid external positions, falling back to internal placement", category: "LabelPlacement")
            }
            // Try internal positions as fallback
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
    
    private func generateCandidatePositions(
        for element: DetectedElement,
        elementRect: NSRect,
        labelSize: NSSize
    ) -> [(rect: NSRect, index: Int, type: PositionType)] {
        
        var positions: [(rect: NSRect, index: Int, type: PositionType)] = []
        
        // For buttons and links, prefer corners to avoid centered text
        if element.type == .button || element.type == .link {
            // External corners (less intrusive)
            positions.append(contentsOf: [
                // Top-left external
                (NSRect(
                    x: elementRect.minX - labelSize.width - labelSpacing,
                    y: elementRect.maxY - labelSize.height,
                    width: labelSize.width,
                    height: labelSize.height
                ), 0, .externalTopLeft),
                // Top-right external
                (NSRect(
                    x: elementRect.maxX + labelSpacing,
                    y: elementRect.maxY - labelSize.height,
                    width: labelSize.width,
                    height: labelSize.height
                ), 1, .externalTopRight),
                // Bottom-left external
                (NSRect(
                    x: elementRect.minX - labelSize.width - labelSpacing,
                    y: elementRect.minY,
                    width: labelSize.width,
                    height: labelSize.height
                ), 2, .externalBottomLeft),
                // Bottom-right external
                (NSRect(
                    x: elementRect.maxX + labelSpacing,
                    y: elementRect.minY,
                    width: labelSize.width,
                    height: labelSize.height
                ), 3, .externalBottomRight),
            ])
        }
        
        // For text fields, prefer right side
        if element.type == .textField {
            positions.append((
                NSRect(
                    x: elementRect.maxX + labelSpacing,
                    y: elementRect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                ), 4, .externalRight
            ))
        }
        
        // For checkboxes, prefer left side
        if element.type == .checkbox {
            positions.append((
                NSRect(
                    x: elementRect.minX - labelSize.width - labelSpacing,
                    y: elementRect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                ), 5, .externalLeft
            ))
        }
        
        // Add standard positions as fallbacks
        // For buttons, avoid centered positions (where text usually is)
        if element.type != .button && element.type != .link {
            positions.append(contentsOf: [
                // Above
                (NSRect(
                    x: elementRect.midX - labelSize.width / 2,
                    y: elementRect.maxY + labelSpacing,
                    width: labelSize.width,
                    height: labelSize.height
                ), 6, .externalAbove),
                // Below
                (NSRect(
                    x: elementRect.midX - labelSize.width / 2,
                    y: elementRect.minY - labelSize.height - labelSpacing,
                    width: labelSize.width,
                    height: labelSize.height
                ), 7, .externalBelow),
            ])
        } else {
            // For buttons, prefer side positions
            positions.append(contentsOf: [
                // Right side
                (NSRect(
                    x: elementRect.maxX + labelSpacing,
                    y: elementRect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                ), 6, .externalRight),
                // Left side
                (NSRect(
                    x: elementRect.minX - labelSize.width - labelSpacing,
                    y: elementRect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                ), 7, .externalLeft),
            ])
        }
        
        return positions
    }
    
    private func filterValidPositions(
        candidates: [(rect: NSRect, index: Int, type: PositionType)],
        element: DetectedElement,
        existingLabels: [(rect: NSRect, element: DetectedElement)],
        allElements: [(element: DetectedElement, rect: NSRect)]
    ) -> [(rect: NSRect, index: Int, type: PositionType)] {
        
        return candidates.filter { candidate in
            // Check if within image bounds
            guard candidate.rect.minX >= 0 && candidate.rect.maxX <= imageSize.width &&
                  candidate.rect.minY >= 0 && candidate.rect.maxY <= imageSize.height else {
                return false
            }
            
            // Check overlap with other elements
            for (otherElement, otherRect) in allElements {
                if otherElement.id != element.id && candidate.rect.intersects(otherRect) {
                    return false
                }
            }
            
            // Check overlap with existing labels
            for (existingLabel, _) in existingLabels {
                if candidate.rect.intersects(existingLabel) {
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
            let score = textDetector.scoreRegionForLabelPlacement(imageRect, in: image)
            
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
        switch positionIndex {
        case 0, 1, 2, 3: // Corner positions
            return NSPoint(x: elementRect.midX, y: elementRect.midY)
        case 4: // Right
            return NSPoint(x: elementRect.maxX, y: elementRect.midY)
        case 5: // Left
            return NSPoint(x: elementRect.minX, y: elementRect.midY)
        case 6: // Above
            return NSPoint(x: elementRect.midX, y: elementRect.maxY)
        case 7: // Below
            return NSPoint(x: elementRect.midX, y: elementRect.minY)
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