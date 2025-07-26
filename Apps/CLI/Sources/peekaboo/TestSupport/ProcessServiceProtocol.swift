import Foundation

// Test-specific protocol for process execution
// This is different from PeekabooCore's ProcessServiceProtocol which is for script execution

public protocol TestProcessServiceProtocol: Sendable {
    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        currentDirectory: String?
    ) async throws -> ProcessResult
    
    func executeScript(
        script: String,
        language: ScriptLanguage
    ) async throws -> ProcessResult
}

public struct ProcessResult: Sendable {
    public let output: String
    public let errorOutput: String
    public let exitCode: Int32
    
    public init(output: String, errorOutput: String, exitCode: Int32) {
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
    }
}

public enum ScriptLanguage: String, Sendable {
    case bash = "bash"
    case python = "python"
    case javascript = "javascript"
    case applescript = "applescript"
}