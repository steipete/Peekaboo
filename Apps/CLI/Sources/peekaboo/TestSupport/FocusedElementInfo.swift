import Foundation

// Test-specific type for focused element information
public struct FocusedElementInfo {
    public let role: String
    public let title: String?
    public let value: String?
    public let isTextField: Bool
    
    public init(role: String, title: String? = nil, value: String? = nil, isTextField: Bool = false) {
        self.role = role
        self.title = title
        self.value = value
        self.isTextField = isTextField
    }
}