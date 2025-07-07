import Foundation
import AXorcist

/// Service for executing Peekaboo automation scripts
@available(macOS 14.0, *)
public protocol ProcessServiceProtocol: Sendable {
    /// Load and validate a Peekaboo script from file
    /// - Parameter path: Path to the script file (.peekaboo.json)
    /// - Returns: The loaded script structure
    /// - Throws: ProcessServiceError if the script cannot be loaded or is invalid
    func loadScript(from path: String) async throws -> PeekabooScript
    
    /// Execute a Peekaboo script
    /// - Parameters:
    ///   - script: The script to execute
    ///   - failFast: Whether to stop execution on first error (default: true)
    ///   - verbose: Whether to provide detailed step execution information
    /// - Returns: Array of step results
    /// - Throws: ProcessServiceError if execution fails
    func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool
    ) async throws -> [StepResult]
    
    /// Execute a single step from a script
    /// - Parameters:
    ///   - step: The step to execute
    ///   - sessionId: Optional session ID to use for the step
    /// - Returns: The result of the step execution
    /// - Throws: ProcessServiceError if the step fails
    func executeStep(
        _ step: ScriptStep,
        sessionId: String?
    ) async throws -> StepExecutionResult
}

/// Script structure for Peekaboo automation
public struct PeekabooScript: Codable, Sendable {
    public let description: String?
    public let steps: [ScriptStep]
    
    public init(description: String?, steps: [ScriptStep]) {
        self.description = description
        self.steps = steps
    }
}

/// Individual step in a script
public struct ScriptStep: Codable, Sendable {
    public let stepId: String
    public let comment: String?
    public let command: String
    public let params: [String: AnyCodable]?
    
    public init(
        stepId: String,
        comment: String?,
        command: String,
        params: [String: AnyCodable]?
    ) {
        self.stepId = stepId
        self.comment = comment
        self.command = command
        self.params = params
    }
}

/// Result of executing a script step
public struct StepResult: Codable, Sendable {
    public let stepId: String
    public let stepNumber: Int
    public let command: String
    public let success: Bool
    public let output: AnyCodable?
    public let error: String?
    public let executionTime: TimeInterval
    
    public init(
        stepId: String,
        stepNumber: Int,
        command: String,
        success: Bool,
        output: AnyCodable?,
        error: String?,
        executionTime: TimeInterval
    ) {
        self.stepId = stepId
        self.stepNumber = stepNumber
        self.command = command
        self.success = success
        self.output = output
        self.error = error
        self.executionTime = executionTime
    }
}

/// Detailed result from step execution
public struct StepExecutionResult: Sendable {
    public let output: AnyCodable?
    public let sessionId: String?
    
    public init(output: Any?, sessionId: String?) {
        self.output = output.map { AnyCodable($0) }
        self.sessionId = sessionId
    }
}

/// Errors that can occur during script processing
public enum ProcessServiceError: LocalizedError, Sendable {
    case scriptNotFound(String)
    case invalidScriptFormat(String)
    case unknownCommand(String)
    case stepExecutionFailed(String)
    case missingRequiredParameter(command: String, parameter: String)
    case invalidParameterValue(command: String, parameter: String, value: String)
    
    public var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "Script file not found: \(path)"
        case .invalidScriptFormat(let reason):
            return "Invalid script format: \(reason)"
        case .unknownCommand(let command):
            return "Unknown command: \(command)"
        case .stepExecutionFailed(let reason):
            return "Step execution failed: \(reason)"
        case .missingRequiredParameter(let command, let parameter):
            return "Missing required parameter '\(parameter)' for command '\(command)'"
        case .invalidParameterValue(let command, let parameter, let value):
            return "Invalid value '\(value)' for parameter '\(parameter)' in command '\(command)'"
        }
    }
}