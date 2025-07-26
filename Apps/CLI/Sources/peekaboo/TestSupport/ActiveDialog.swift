import Foundation

// Test-specific type for active dialog representation
public struct ActiveDialog {
    public let title: String
    public let buttons: [String]
    public let windowID: Int
    
    public init(title: String, buttons: [String], windowID: Int) {
        self.title = title
        self.buttons = buttons
        self.windowID = windowID
    }
}