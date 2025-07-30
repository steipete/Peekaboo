import Foundation
import CoreGraphics

/// Protocol defining dialog and alert management operations
@MainActor
public protocol DialogServiceProtocol: Sendable {
    /// Find and return information about the active dialog
    /// - Parameter windowTitle: Optional specific window title to target
    /// - Returns: Information about the active dialog
    func findActiveDialog(windowTitle: String?) async throws -> DialogInfo
    
    /// Click a button in the active dialog
    /// - Parameters:
    ///   - buttonText: Text of the button to click (e.g., "OK", "Cancel", "Save")
    ///   - windowTitle: Optional specific window title to target
    /// - Returns: Result of the click operation
    func clickButton(buttonText: String, windowTitle: String?) async throws -> DialogActionResult
    
    /// Enter text in a dialog field
    /// - Parameters:
    ///   - text: Text to enter
    ///   - fieldIdentifier: Field label, placeholder, or index to target
    ///   - clearExisting: Whether to clear existing text first
    ///   - windowTitle: Optional specific window title to target
    /// - Returns: Result of the input operation
    func enterText(text: String, fieldIdentifier: String?, clearExisting: Bool, windowTitle: String?) async throws -> DialogActionResult
    
    /// Handle file save/open dialogs
    /// - Parameters:
    ///   - path: Full path to navigate to
    ///   - filename: File name to enter (for save dialogs)
    ///   - actionButton: Button to click after entering path/name (default: "Save")
    /// - Returns: Result of the file dialog operation
    func handleFileDialog(path: String?, filename: String?, actionButton: String) async throws -> DialogActionResult
    
    /// Dismiss the active dialog
    /// - Parameters:
    ///   - force: Use Escape key to force dismiss
    ///   - windowTitle: Optional specific window title to target
    /// - Returns: Result of the dismiss operation
    func dismissDialog(force: Bool, windowTitle: String?) async throws -> DialogActionResult
    
    /// List all elements in the active dialog
    /// - Parameter windowTitle: Optional specific window title to target
    /// - Returns: Information about all dialog elements
    func listDialogElements(windowTitle: String?) async throws -> DialogElements
}

/// Information about a dialog
public struct DialogInfo: Sendable {
    /// Dialog title
    public let title: String
    
    /// Dialog role (e.g., "AXDialog", "AXSheet")
    public let role: String
    
    /// Dialog subrole if available
    public let subrole: String?
    
    /// Whether this is a file dialog
    public let isFileDialog: Bool
    
    /// Dialog bounds in screen coordinates
    public let bounds: CGRect
    
    public init(
        title: String,
        role: String,
        subrole: String? = nil,
        isFileDialog: Bool = false,
        bounds: CGRect
    ) {
        self.title = title
        self.role = role
        self.subrole = subrole
        self.isFileDialog = isFileDialog
        self.bounds = bounds
    }
}

/// Result of a dialog action
public struct DialogActionResult: Sendable {
    /// Whether the action was successful
    public let success: Bool
    
    /// Type of action performed
    public let action: DialogActionType
    
    /// Additional details about the action
    public let details: [String: String]
    
    public init(
        success: Bool,
        action: DialogActionType,
        details: [String: String] = [:]
    ) {
        self.success = success
        self.action = action
        self.details = details
    }
}

/// Type of dialog action performed
public enum DialogActionType: String, Sendable {
    case clickButton = "click_button"
    case enterText = "enter_text"
    case handleFileDialog = "handle_file_dialog"
    case dismiss = "dismiss"
}

/// Information about dialog elements
public struct DialogElements: Sendable {
    /// Dialog information
    public let dialogInfo: DialogInfo
    
    /// Available buttons
    public let buttons: [DialogButton]
    
    /// Text input fields
    public let textFields: [DialogTextField]
    
    /// Static text elements
    public let staticTexts: [String]
    
    /// Other UI elements
    public let otherElements: [DialogElement]
    
    public init(
        dialogInfo: DialogInfo,
        buttons: [DialogButton] = [],
        textFields: [DialogTextField] = [],
        staticTexts: [String] = [],
        otherElements: [DialogElement] = []
    ) {
        self.dialogInfo = dialogInfo
        self.buttons = buttons
        self.textFields = textFields
        self.staticTexts = staticTexts
        self.otherElements = otherElements
    }
}

/// Information about a dialog button
public struct DialogButton: Sendable {
    /// Button text
    public let title: String
    
    /// Whether the button is enabled
    public let isEnabled: Bool
    
    /// Whether this is the default button
    public let isDefault: Bool
    
    public init(
        title: String,
        isEnabled: Bool = true,
        isDefault: Bool = false
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isDefault = isDefault
    }
}

/// Information about a dialog text field
public struct DialogTextField: Sendable {
    /// Field label or title
    public let title: String?
    
    /// Current value
    public let value: String?
    
    /// Placeholder text
    public let placeholder: String?
    
    /// Field index (0-based)
    public let index: Int
    
    /// Whether the field is enabled
    public let isEnabled: Bool
    
    public init(
        title: String? = nil,
        value: String? = nil,
        placeholder: String? = nil,
        index: Int,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.value = value
        self.placeholder = placeholder
        self.index = index
        self.isEnabled = isEnabled
    }
}

/// Generic dialog element
public struct DialogElement: Sendable {
    /// Element role
    public let role: String
    
    /// Element title or label
    public let title: String?
    
    /// Element value
    public let value: String?
    
    public init(
        role: String,
        title: String? = nil,
        value: String? = nil
    ) {
        self.role = role
        self.title = title
        self.value = value
    }
}