import Foundation

/// Placeholder entry point for the future Commander dispatcher.
public struct Program: Sendable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    public func run() {
        // No-op for now; future stages will implement parsing/execution.
    }
}
