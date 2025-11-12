//
//  InspectorPreset.swift
//  PeekabooUICore
//
//  Inspector-style visualization preset with circle indicators
//

import CoreGraphics
import Foundation
import PeekabooCore

/// Inspector-style visualization with circle indicators and hover effects
@MainActor
public struct InspectorVisualizationPreset: ElementStyleProvider {
    public let indicatorStyle: IndicatorStyle = .circle(
        diameter: 30,
        position: .topLeft)

    public let showsLabels: Bool = false // Labels shown on hover
    public let supportsHoverState: Bool = true

    /// Circle opacity when not hovered
    private let normalOpacity: Double = 0.5

    /// Circle opacity when hovered
    private let hoverOpacity: Double = 1.0

    public init() {}

    public func style(for category: ElementCategory, state: ElementVisualizationState) -> ElementStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        switch state {
        case .normal:
            return self.normalStyle(baseColor: baseColor)
        case .hovered:
            return self.hoverStyle(baseColor: baseColor)
        case .selected:
            return self.selectedStyle(baseColor: baseColor)
        case .disabled:
            return self.disabledStyle()
        }
    }
}

// MARK: - Inspector-Specific Extensions

extension InspectorVisualizationPreset {
    /// Special style for the circle indicator itself
    public func circleStyle(for category: ElementCategory, isHovered: Bool) -> ElementStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        return ElementStyle(
            primaryColor: baseColor,
            fillOpacity: isHovered ? self.hoverOpacity : self.normalOpacity,
            strokeWidth: 0,
            strokeOpacity: 0,
            cornerRadius: 15,
            shadow: nil,
            labelStyle: LabelStyle(
                fontSize: 8,
                fontWeight: .bold,
                backgroundColor: nil,
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 0, vertical: 0)))
    }

    /// Style for the hover frame overlay
    public func frameOverlayStyle(for category: ElementCategory) -> ElementStyle {
        let baseColor = PeekabooColorPalette.color(for: category)

        return ElementStyle(
            primaryColor: baseColor,
            fillOpacity: 0,
            strokeWidth: 2,
            strokeOpacity: 1.0,
            cornerRadius: 0,
            shadow: nil,
            labelStyle: .default)
    }

    /// Style for the info bubble shown on hover
    public func infoBubbleStyle() -> ElementStyle {
        ElementStyle(
            primaryColor: CGColor(gray: 0, alpha: 1),
            fillOpacity: 0.8,
            strokeWidth: 0,
            strokeOpacity: 0,
            cornerRadius: 4,
            shadow: nil,
            labelStyle: LabelStyle(
                fontSize: 10,
                fontWeight: .regular,
                backgroundColor: nil,
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 6, vertical: 3)))
    }
}

// MARK: - Private Helpers

private extension InspectorVisualizationPreset {
    func normalStyle(baseColor: CGColor) -> ElementStyle {
        ElementStyle(
            primaryColor: baseColor,
            fillOpacity: self.normalOpacity,
            strokeWidth: 0,
            strokeOpacity: 0,
            cornerRadius: 15,
            shadow: nil,
            labelStyle: LabelStyle(
                fontSize: 8,
                fontWeight: .bold,
                backgroundColor: nil,
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 0, vertical: 0)))
    }

    func hoverStyle(baseColor: CGColor) -> ElementStyle {
        ElementStyle(
            primaryColor: baseColor,
            fillOpacity: 0,
            strokeWidth: 2,
            strokeOpacity: 1.0,
            cornerRadius: 0,
            shadow: nil,
            labelStyle: LabelStyle(
                fontSize: 10,
                fontWeight: .regular,
                backgroundColor: CGColor(gray: 0, alpha: 0.8),
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 6, vertical: 3)))
    }

    func selectedStyle(baseColor: CGColor) -> ElementStyle {
        ElementStyle(
            primaryColor: baseColor,
            fillOpacity: 0.3,
            strokeWidth: 3,
            strokeOpacity: 1.0,
            cornerRadius: 0,
            shadow: ShadowStyle(
                color: baseColor.copy(alpha: 0.5)!,
                radius: 8,
                offsetX: 0,
                offsetY: 0),
            labelStyle: LabelStyle(
                fontSize: 10,
                fontWeight: .bold,
                backgroundColor: baseColor,
                textColor: CGColor(gray: 1, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 8, vertical: 4)))
    }

    func disabledStyle() -> ElementStyle {
        ElementStyle(
            primaryColor: PeekabooColorPalette.control,
            fillOpacity: 0.3,
            strokeWidth: 0,
            strokeOpacity: 0,
            cornerRadius: 15,
            shadow: nil,
            labelStyle: LabelStyle(
                fontSize: 8,
                fontWeight: .regular,
                backgroundColor: nil,
                textColor: CGColor(gray: 0.7, alpha: 1),
                padding: LabelStyle.EdgeInsets(horizontal: 0, vertical: 0)))
    }
}
