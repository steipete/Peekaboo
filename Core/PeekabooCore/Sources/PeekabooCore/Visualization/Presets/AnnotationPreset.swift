//
//  AnnotationPreset.swift
//  PeekabooCore
//
//  Annotation-style visualization preset with rectangle overlays
//

import CoreGraphics
import Foundation

/// Annotation-style visualization with rectangle overlays and persistent labels
@MainActor
public struct AnnotationVisualizationPreset: ElementStyleProvider {
    public let indicatorStyle: IndicatorStyle = .rectangle

    public let showsLabels: Bool = true // Always show labels
    public let supportsHoverState: Bool = false // No hover effects

    /// Base fill opacity for rectangles
    private let fillOpacity: Double = 0.15

    /// Enhanced fill opacity for selected elements
    private let selectedFillOpacity: Double = 0.25

    public init() {}

    public func style(for category: ElementCategory, state: ElementVisualizationState) -> ElementStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        switch state {
        case .normal:
            // Semi-transparent rectangle with solid border
            return ElementStyle(
                primaryColor: baseColor,
                fillOpacity: self.fillOpacity,
                strokeWidth: 2.5,
                strokeOpacity: 1.0,
                cornerRadius: 4.0,
                shadow: nil,
                labelStyle: LabelStyle(
                    fontSize: 12,
                    fontWeight: .bold,
                    backgroundColor: baseColor,
                    textColor: CGColor(gray: 1, alpha: 1),
                    padding: LabelStyle.EdgeInsets(horizontal: 8, vertical: 4)))

        case .hovered:
            // Same as normal since we don't support hover
            return self.style(for: category, state: .normal)

        case .selected:
            // Enhanced visibility for selected elements
            return ElementStyle(
                primaryColor: baseColor,
                fillOpacity: self.selectedFillOpacity,
                strokeWidth: 3.0,
                strokeOpacity: 1.0,
                cornerRadius: 4.0,
                shadow: ShadowStyle(
                    color: baseColor.copy(alpha: 0.4)!,
                    radius: 6,
                    offsetX: 0,
                    offsetY: 2),
                labelStyle: LabelStyle(
                    fontSize: 13,
                    fontWeight: .bold,
                    backgroundColor: baseColor,
                    textColor: CGColor(gray: 1, alpha: 1),
                    padding: LabelStyle.EdgeInsets(horizontal: 10, vertical: 5)))

        case .disabled:
            // Reduced visibility for disabled elements
            return ElementStyle(
                primaryColor: PeekabooColorPalette.control,
                fillOpacity: 0.1,
                strokeWidth: 1.5,
                strokeOpacity: 0.5,
                cornerRadius: 4.0,
                shadow: nil,
                labelStyle: LabelStyle(
                    fontSize: 11,
                    fontWeight: .medium,
                    backgroundColor: CGColor(gray: 0.5, alpha: 0.8),
                    textColor: CGColor(gray: 1, alpha: 0.9),
                    padding: LabelStyle.EdgeInsets(horizontal: 6, vertical: 3)))
        }
    }
}

// MARK: - Annotation-Specific Extensions

extension AnnotationVisualizationPreset {
    /// Style specifically for the label badge
    public func labelBadgeStyle(for category: ElementCategory, isSelected: Bool = false) -> ElementStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        return ElementStyle(
            primaryColor: baseColor,
            fillOpacity: 1.0, // Solid fill for label background
            strokeWidth: 0,
            strokeOpacity: 0,
            cornerRadius: 6.0, // Rounded corners for badge
            shadow: ShadowStyle(
                color: CGColor(gray: 0, alpha: 0.3),
                radius: 3,
                offsetX: 0,
                offsetY: 2),
            labelStyle: LabelStyle(
                fontSize: isSelected ? 13 : 12,
                fontWeight: .bold,
                backgroundColor: nil, // Background handled by element style
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(
                    horizontal: isSelected ? 10 : 8,
                    vertical: isSelected ? 5 : 4)))
    }

    /// Alternative monospaced style for IDs
    public func monospacedLabelStyle(for category: ElementCategory) -> LabelStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        return LabelStyle(
            fontSize: 12,
            fontWeight: .bold,
            backgroundColor: baseColor,
            textColor: CGColor(gray: 1, alpha: 1),
            padding: LabelStyle.EdgeInsets(horizontal: 8, vertical: 4))
    }

    /// Compact style for dense element layouts
    public func compactStyle(for category: ElementCategory) -> ElementStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        return ElementStyle(
            primaryColor: baseColor,
            fillOpacity: 0.1,
            strokeWidth: 1.5,
            strokeOpacity: 0.8,
            cornerRadius: 2.0,
            shadow: nil,
            labelStyle: LabelStyle(
                fontSize: 10,
                fontWeight: .medium,
                backgroundColor: baseColor.copy(alpha: 0.9),
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 4, vertical: 2)))
    }
}
