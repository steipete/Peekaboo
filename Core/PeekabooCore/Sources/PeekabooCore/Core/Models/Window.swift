import CoreGraphics
import Foundation

/// Information about a focused UI element
public struct FocusInfo: Codable, Sendable {
    /// Name of the application containing the focused element
    public let app: String

    /// Bundle identifier of the application (if available)
    public let bundleId: String?

    /// Process identifier of the application
    public let processId: Int

    /// Information about the focused element itself
    public let element: ElementInfo

    public init(app: String, bundleId: String?, processId: Int, element: ElementInfo) {
        self.app = app
        self.bundleId = bundleId
        self.processId = processId
        self.element = element
    }
}

/// Detailed information about a UI element
public struct ElementInfo: Codable, Sendable {
    /// Accessibility role of the element (e.g., "AXTextField", "AXButton")
    public let role: String

    /// Title or label of the element (if available)
    public let title: String?

    /// Current value of the element (e.g., text content)
    public let value: String?

    /// Position and size of the element on screen
    public let bounds: CGRect

    /// Whether the element is enabled and can receive input
    public let isEnabled: Bool

    /// Whether the element is currently visible
    public let isVisible: Bool

    /// Subrole of the element for more specific identification
    public let subrole: String?

    /// Element description if available
    public let description: String?

    public init(
        role: String,
        title: String?,
        value: String?,
        bounds: CGRect,
        isEnabled: Bool,
        isVisible: Bool,
        subrole: String? = nil,
        description: String? = nil)
    {
        self.role = role
        self.title = title
        self.value = value
        self.bounds = bounds
        self.isEnabled = isEnabled
        self.isVisible = isVisible
        self.subrole = subrole
        self.description = description
    }
}

// MARK: - Convenience Extensions

extension FocusInfo {
    /// Returns true if the focused element is a text input field
    public var isTextInput: Bool {
        self.element.isTextInput
    }

    /// Returns true if the focused element can accept keyboard input
    public var canAcceptKeyboardInput: Bool {
        self.element.canAcceptKeyboardInput
    }

    /// Human-readable description of the focused element
    public var humanDescription: String {
        let elementDesc = self.element.title ?? self.element.description ?? "untitled \(self.element.role)"
        return "\(elementDesc) in \(self.app)"
    }
}

extension ElementInfo {
    /// Returns true if this element is a text input field
    public var isTextInput: Bool {
        let textInputRoles = [
            "AXTextField",
            "AXTextArea",
            "AXComboBox",
            "AXSearchField",
            "AXSecureTextField",
        ]
        return textInputRoles.contains(self.role) || self.subrole == "AXContentEditable"
    }

    /// Returns true if this element can accept keyboard input
    public var canAcceptKeyboardInput: Bool {
        // Text input fields
        if self.isTextInput {
            return self.isEnabled
        }

        // Web areas can accept keyboard input for navigation
        if self.role == "AXWebArea" {
            return self.isEnabled
        }

        // Some buttons and controls accept keyboard input
        if self.role == "AXButton" || self.role == "AXMenuButton" || self.role == "AXPopUpButton" {
            return self.isEnabled
        }

        return false
    }

    /// Returns a human-readable type description
    public var typeDescription: String {
        switch self.role {
        case "AXTextField": "text field"
        case "AXTextArea": "text area"
        case "AXSecureTextField": "password field"
        case "AXSearchField": "search field"
        case "AXComboBox": "combo box"
        case "AXButton": "button"
        case "AXMenuButton": "menu button"
        case "AXPopUpButton": "popup button"
        case "AXWebArea": "web content"
        case "AXGroup": "group"
        case "AXStaticText": "static text"
        case "AXLink": "link"
        default: self.role.replacingOccurrences(of: "AX", with: "").lowercased()
        }
    }
}

// MARK: - JSON Conversion Helpers

extension FocusInfo {
    /// Convert to dictionary for JSON responses
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "app": app,
            "processId": processId,
            "element": element.toDictionary(),
        ]

        // Only include bundleId if it's non-nil
        if let bundleId {
            dict["bundleId"] = bundleId
        }

        return dict
    }
}

extension ElementInfo {
    /// Convert to dictionary for JSON responses
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "role": role,
            "bounds": [
                "x": bounds.origin.x,
                "y": self.bounds.origin.y,
                "width": self.bounds.width,
                "height": self.bounds.height,
            ],
            "isEnabled": self.isEnabled,
            "isVisible": self.isVisible,
            "isTextInput": self.isTextInput,
            "canAcceptKeyboardInput": self.canAcceptKeyboardInput,
            "typeDescription": self.typeDescription,
        ]

        // Only include optional values if they are non-nil
        if let title {
            dict["title"] = title
        }
        if let value {
            dict["value"] = value
        }
        if let subrole {
            dict["subrole"] = subrole
        }
        if let description {
            dict["description"] = description
        }

        return dict
    }
}
