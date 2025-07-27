import Foundation

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
    public let params: ProcessCommandParameters?
    
    public init(
        stepId: String,
        comment: String?,
        command: String,
        params: ProcessCommandParameters?
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
    public let output: ProcessCommandOutput?
    public let error: String?
    public let executionTime: TimeInterval
    
    public init(
        stepId: String,
        stepNumber: Int,
        command: String,
        success: Bool,
        output: ProcessCommandOutput?,
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
    public let output: ProcessCommandOutput?
    public let sessionId: String?
    
    public init(output: ProcessCommandOutput?, sessionId: String?) {
        self.output = output
        self.sessionId = sessionId
    }
}