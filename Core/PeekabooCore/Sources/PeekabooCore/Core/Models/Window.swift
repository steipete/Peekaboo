import Foundation
import CoreGraphics

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
        description: String? = nil
    ) {
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
        return element.isTextInput
    }
    
    /// Returns true if the focused element can accept keyboard input
    public var canAcceptKeyboardInput: Bool {
        return element.canAcceptKeyboardInput
    }
    
    /// Human-readable description of the focused element
    public var humanDescription: String {
        let elementDesc = element.title ?? element.description ?? "untitled \(element.role)"
        return "\(elementDesc) in \(app)"
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
            "AXSecureTextField"
        ]
        return textInputRoles.contains(role) || subrole == "AXContentEditable"
    }
    
    /// Returns true if this element can accept keyboard input
    public var canAcceptKeyboardInput: Bool {
        // Text input fields
        if isTextInput {
            return isEnabled
        }
        
        // Web areas can accept keyboard input for navigation
        if role == "AXWebArea" {
            return isEnabled
        }
        
        // Some buttons and controls accept keyboard input
        if role == "AXButton" || role == "AXMenuButton" || role == "AXPopUpButton" {
            return isEnabled
        }
        
        return false
    }
    
    /// Returns a human-readable type description
    public var typeDescription: String {
        switch role {
        case "AXTextField": return "text field"
        case "AXTextArea": return "text area"
        case "AXSecureTextField": return "password field"
        case "AXSearchField": return "search field"
        case "AXComboBox": return "combo box"
        case "AXButton": return "button"
        case "AXMenuButton": return "menu button"
        case "AXPopUpButton": return "popup button"
        case "AXWebArea": return "web content"
        case "AXGroup": return "group"
        case "AXStaticText": return "static text"
        case "AXLink": return "link"
        default: return role.replacingOccurrences(of: "AX", with: "").lowercased()
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
            "element": element.toDictionary()
        ]
        
        // Only include bundleId if it's non-nil
        if let bundleId = bundleId {
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
                "y": bounds.origin.y,
                "width": bounds.width,
                "height": bounds.height
            ],
            "isEnabled": isEnabled,
            "isVisible": isVisible,
            "isTextInput": isTextInput,
            "canAcceptKeyboardInput": canAcceptKeyboardInput,
            "typeDescription": typeDescription
        ]
        
        // Only include optional values if they are non-nil
        if let title = title {
            dict["title"] = title
        }
        if let value = value {
            dict["value"] = value
        }
        if let subrole = subrole {
            dict["subrole"] = subrole
        }
        if let description = description {
            dict["description"] = description
        }
        
        return dict
    }
}