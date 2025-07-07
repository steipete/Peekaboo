import Foundation

// Temporary models until we integrate PeekabooCore

public struct ToolExecutionResult: Codable {
    public let toolName: String
    public let success: Bool
    public let output: String?
    public let error: String?
    public let timestamp: Date

    public init(toolName: String, success: Bool, output: String? = nil, error: String? = nil) {
        self.toolName = toolName
        self.success = success
        self.output = output
        self.error = error
        self.timestamp = Date()
    }
}
