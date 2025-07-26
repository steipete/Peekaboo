import Foundation

// Test-specific type for accessibility element
public struct AXElement {
    public let identifier: String
    public let role: String
    public let title: String?
    
    public init(identifier: String, role: String, title: String? = nil) {
        self.identifier = identifier
        self.role = role
        self.title = title
    }
}