//
//  ElementVisualization.swift
//  PeekabooInspector
//
//  Core visualization types for the Inspector
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Element Category

enum ElementCategory: String, CaseIterable {
    case button
    case textField
    case link
    case image
    case staticText
    case group
    case slider
    case checkbox
    case radioButton
    case menu
    case popUpButton
    case tableView
    case scrollView
    case other
}

// MARK: - Visualization State

enum ElementVisualizationState {
    case normal
    case hover
    case selected
    case disabled
}

// MARK: - Style Types

struct ElementVisualizationStyle {
    let primaryColor: CGColor
    let strokeWidth: CGFloat
    let strokeOpacity: CGFloat
    let fillOpacity: CGFloat
    let cornerRadius: CGFloat
    let labelStyle: LabelStyle?
    let shadow: ShadowStyle?
}

struct LabelStyle {
    let fontSize: CGFloat
    let fontWeight: FontWeight
    let textColor: CGColor
    let backgroundColor: CGColor?
    let padding: (horizontal: CGFloat, vertical: CGFloat)
    
    enum FontWeight {
        case regular
        case bold
    }
}

struct ShadowStyle {
    let color: CGColor
    let radius: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
}

// MARK: - Color Palette

struct InspectorColorPalette {
    static let interactive = CGColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0) // Blue
    static let input = CGColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0) // Green
    static let control = CGColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0) // Gray
    static let `default` = CGColor(red: 1.0, green: 0.584, blue: 0, alpha: 1.0) // Orange
    static let disabled = CGColor(gray: 0.5, alpha: 0.5)
}

// MARK: - Style Provider

class InspectorStyleProvider {
    func style(for category: ElementCategory, state: ElementVisualizationState) -> ElementVisualizationStyle {
        let baseColor = colorForCategory(category)
        
        switch state {
        case .normal:
            return ElementVisualizationStyle(
                primaryColor: baseColor,
                strokeWidth: 2.0,
                strokeOpacity: 0.8,
                fillOpacity: 0.1,
                cornerRadius: 4.0,
                labelStyle: LabelStyle(
                    fontSize: 8,
                    fontWeight: .bold,
                    textColor: .white,
                    backgroundColor: baseColor,
                    padding: (horizontal: 4, vertical: 2)
                ),
                shadow: nil
            )
            
        case .hover:
            return ElementVisualizationStyle(
                primaryColor: baseColor,
                strokeWidth: 3.0,
                strokeOpacity: 1.0,
                fillOpacity: 0.2,
                cornerRadius: 4.0,
                labelStyle: LabelStyle(
                    fontSize: 10,
                    fontWeight: .bold,
                    textColor: .white,
                    backgroundColor: baseColor,
                    padding: (horizontal: 6, vertical: 3)
                ),
                shadow: ShadowStyle(
                    color: baseColor,
                    radius: 8.0,
                    offsetX: 0,
                    offsetY: 2
                )
            )
            
        case .selected:
            return ElementVisualizationStyle(
                primaryColor: baseColor,
                strokeWidth: 4.0,
                strokeOpacity: 1.0,
                fillOpacity: 0.3,
                cornerRadius: 4.0,
                labelStyle: LabelStyle(
                    fontSize: 10,
                    fontWeight: .bold,
                    textColor: .white,
                    backgroundColor: baseColor,
                    padding: (horizontal: 6, vertical: 3)
                ),
                shadow: ShadowStyle(
                    color: baseColor,
                    radius: 12.0,
                    offsetX: 0,
                    offsetY: 4
                )
            )
            
        case .disabled:
            return ElementVisualizationStyle(
                primaryColor: InspectorColorPalette.disabled,
                strokeWidth: 1.0,
                strokeOpacity: 0.5,
                fillOpacity: 0.05,
                cornerRadius: 4.0,
                labelStyle: LabelStyle(
                    fontSize: 8,
                    fontWeight: .regular,
                    textColor: .white,
                    backgroundColor: InspectorColorPalette.disabled,
                    padding: (horizontal: 4, vertical: 2)
                ),
                shadow: nil
            )
        }
    }
    
    private func colorForCategory(_ category: ElementCategory) -> CGColor {
        switch category {
        case .button, .link, .menu:
            return InspectorColorPalette.interactive
        case .textField, .popUpButton:
            return InspectorColorPalette.input
        case .checkbox, .radioButton, .slider:
            return InspectorColorPalette.control
        default:
            return InspectorColorPalette.default
        }
    }
}

// MARK: - ID Generator

class ElementIDGenerator {
    static let shared = ElementIDGenerator()
    
    private var counters: [ElementCategory: Int] = [:]
    
    private init() {}
    
    func generateID(for category: ElementCategory, index: Int? = nil) -> String {
        let prefix = prefixForCategory(category)
        
        if let index = index {
            return "\(prefix)\(index + 1)"
        }
        
        let count = counters[category, default: 0]
        counters[category] = count + 1
        return "\(prefix)\(count + 1)"
    }
    
    func reset() {
        counters.removeAll()
    }
    
    private func prefixForCategory(_ category: ElementCategory) -> String {
        switch category {
        case .button: return "B"
        case .textField: return "T"
        case .link: return "L"
        case .image: return "I"
        case .staticText: return "St"
        case .group: return "G"
        case .slider: return "S"
        case .checkbox: return "C"
        case .radioButton: return "R"
        case .menu: return "M"
        case .popUpButton: return "P"
        case .tableView: return "Tb"
        case .scrollView: return "Sc"
        case .other: return "E"
        }
    }
}

// MARK: - Coordinate Transformation

class CoordinateTransformer {
    func transform(_ rect: CGRect, from: CoordinateSpace, to: CoordinateSpace) -> CGRect {
        // For Inspector, we're always working in screen coordinates
        // So we just return the rect as-is
        return rect
    }
}

enum CoordinateSpace {
    case screen
    case window(CGRect)
    case view(CGSize)
}

// MARK: - View Extension

extension View {
    /// Conditionally apply a modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}