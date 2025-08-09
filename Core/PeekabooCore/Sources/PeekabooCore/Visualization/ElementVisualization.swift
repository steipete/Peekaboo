//
import PeekabooFoundation
//  ElementVisualization.swift
//  PeekabooCore
//
//  Core types and protocols for unified element visualization
//

import CoreGraphics
import Foundation

// MARK: - Core Types

/// Represents an element that can be visualized
public struct VisualizableElement: Sendable {
    /// Unique identifier for the element
    public let id: String

    /// Category of the element for styling
    public let category: ElementCategory

    /// Bounds of the element in screen coordinates
    public let bounds: CGRect

    /// Optional label or text content
    public let label: String?

    /// Whether the element is enabled/interactive
    public let isEnabled: Bool

    /// Whether the element is currently selected
    public let isSelected: Bool

    /// Additional metadata for custom visualization
    public let metadata: [String: String]

    public init(
        id: String,
        category: ElementCategory,
        bounds: CGRect,
        label: String? = nil,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        metadata: [String: String] = [:])
    {
        self.id = id
        self.category = category
        self.bounds = bounds
        self.label = label
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        self.metadata = metadata
    }
}

/// Categories of UI elements for consistent styling
public enum ElementCategory: Sendable, Equatable, Hashable {
    case button
    case textInput
    case link
    case checkbox
    case radioButton
    case slider
    case menu
    case image
    case container
    case text
    case custom(String)

    /// Initialize from AX role
    public init(axRole: String) {
        switch axRole {
        case "AXButton", "AXPopUpButton":
            self = .button
        case "AXTextField", "AXTextArea", "AXSearchField":
            self = .textInput
        case "AXLink":
            self = .link
        case "AXCheckBox":
            self = .checkbox
        case "AXRadioButton":
            self = .radioButton
        case "AXSlider":
            self = .slider
        case "AXMenu", "AXMenuBar", "AXMenuItem":
            self = .menu
        case "AXImage":
            self = .image
        case "AXGroup", "AXScrollArea", "AXWindow":
            self = .container
        case "AXStaticText", "AXHeading":
            self = .text
        default:
            self = .custom(axRole)
        }
    }

    /// Initialize from ElementType
    public init(elementType: ElementType) {
        switch elementType {
        case .button:
            self = .button
        case .textField:
            self = .textInput
        case .link:
            self = .link
        case .checkbox:
            self = .checkbox
        case .slider:
            self = .slider
        case .menu, .menuItem:
            self = .menu
        case .image:
            self = .image
        case .group:
            self = .container
        case .staticText:
            self = .text
        case .radioButton:
            self = .radioButton
        case .window, .dialog:
            self = .container
        case .other:
            self = .text
        }
    }

    /// Get ID prefix for this category
    public var idPrefix: String {
        switch self {
        case .button:
            "B"
        case .textInput:
            "T"
        case .link:
            "L"
        case .checkbox:
            "C"
        case .radioButton:
            "R"
        case .slider:
            "S"
        case .menu:
            "M"
        case .image:
            "I"
        case .container:
            "G"
        case .text:
            "X"
        case .custom:
            "U"
        }
    }
}

// MARK: - Style Types

/// Visual style for an element
public struct ElementStyle: Sendable {
    /// Primary color for the element
    public let primaryColor: CGColor

    /// Fill opacity (0.0 - 1.0)
    public let fillOpacity: Double

    /// Stroke width in points
    public let strokeWidth: Double

    /// Stroke opacity (0.0 - 1.0)
    public let strokeOpacity: Double

    /// Corner radius for rounded elements
    public let cornerRadius: Double

    /// Shadow configuration
    public let shadow: ShadowStyle?

    /// Label style
    public let labelStyle: LabelStyle

    public init(
        primaryColor: CGColor,
        fillOpacity: Double = 0.2,
        strokeWidth: Double = 2.0,
        strokeOpacity: Double = 1.0,
        cornerRadius: Double = 4.0,
        shadow: ShadowStyle? = nil,
        labelStyle: LabelStyle = .default)
    {
        self.primaryColor = primaryColor
        self.fillOpacity = fillOpacity
        self.strokeWidth = strokeWidth
        self.strokeOpacity = strokeOpacity
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.labelStyle = labelStyle
    }
}

/// Shadow configuration
public struct ShadowStyle: Sendable {
    public let color: CGColor
    public let radius: Double
    public let offsetX: Double
    public let offsetY: Double

    public init(color: CGColor, radius: Double, offsetX: Double = 0, offsetY: Double = 2) {
        self.color = color
        self.radius = radius
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// Label style configuration
public struct LabelStyle: Sendable {
    public let fontSize: Double
    public let fontWeight: FontWeight
    public let backgroundColor: CGColor?
    public let textColor: CGColor
    public let padding: EdgeInsets

    public enum FontWeight: Sendable {
        case regular
        case medium
        case bold
    }

    public struct EdgeInsets: Sendable {
        public let horizontal: Double
        public let vertical: Double

        public init(horizontal: Double = 6, vertical: Double = 3) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
    }

    public init(
        fontSize: Double = 11,
        fontWeight: FontWeight = .medium,
        backgroundColor: CGColor? = nil,
        textColor: CGColor,
        padding: EdgeInsets = EdgeInsets())
    {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.padding = padding
    }

    public static let `default` = LabelStyle(
        fontSize: 11,
        fontWeight: .medium,
        backgroundColor: CGColor(gray: 0, alpha: 0.85),
        textColor: CGColor(gray: 1, alpha: 1),
        padding: EdgeInsets(horizontal: 6, vertical: 3))
}

// MARK: - Visualization State

/// Current state of an element for visualization
public enum ElementVisualizationState: Sendable {
    case normal
    case hovered
    case selected
    case disabled
}

// MARK: - Coordinate Spaces

/// Coordinate space for element bounds
public enum CoordinateSpace: Sendable {
    /// Screen coordinates with origin at top-left
    case screen

    /// Window coordinates relative to window origin
    case window(CGRect)

    /// View coordinates relative to container
    case view(CGSize)

    /// Normalized coordinates (0.0 - 1.0)
    case normalized
}
