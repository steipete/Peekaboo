import Foundation

// MARK: - Tool Execution Types

/// Represents a single tool execution in the history
public struct ToolExecution: Identifiable, Sendable {
    public let id = UUID()
    public let toolName: String
    public let arguments: String
    public let timestamp: Date
    public var status: ToolExecutionStatus
    public var result: String?
    public var duration: TimeInterval?
    public var metadata: [String: String]
    
    public init(
        toolName: String,
        arguments: String,
        timestamp: Date = Date(),
        status: ToolExecutionStatus = .running,
        result: String? = nil,
        duration: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.timestamp = timestamp
        self.status = status
        self.result = result
        self.duration = duration
        self.metadata = metadata
    }
}

/// Status of a tool execution
public enum ToolExecutionStatus: String, Sendable {
    case running
    case completed
    case failed
    case cancelled
    
    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    public var isTerminal: Bool {
        switch self {
        case .running: return false
        case .completed, .failed, .cancelled: return true
        }
    }
}

/// Result from executing a tool
public struct ToolExecutionResult: Sendable {
    public let output: ToolOutput
    public let metadata: [String: String]
    public let duration: TimeInterval
    public let status: ToolExecutionStatus
    
    public init(
        output: ToolOutput,
        metadata: [String: String] = [:],
        duration: TimeInterval = 0,
        status: ToolExecutionStatus = .completed
    ) {
        self.output = output
        self.metadata = metadata
        self.duration = duration
        self.status = status
    }
}

/// History of tool executions for a session
public struct ToolExecutionHistory: Sendable {
    public private(set) var executions: [ToolExecution] = []
    
    public init(executions: [ToolExecution] = []) {
        self.executions = executions
    }
    
    /// Add a new execution to the history
    public mutating func add(_ execution: ToolExecution) {
        executions.append(execution)
    }
    
    /// Update an existing execution
    public mutating func update(id: UUID, with update: (inout ToolExecution) -> Void) {
        if let index = executions.firstIndex(where: { $0.id == id }) {
            update(&executions[index])
        }
    }
    
    /// Get executions filtered by status
    public func executions(with status: ToolExecutionStatus) -> [ToolExecution] {
        executions.filter { $0.status == status }
    }
    
    /// Get the currently running execution if any
    public var runningExecution: ToolExecution? {
        executions.first { $0.status == .running }
    }
    
    /// Total duration of all completed executions
    public var totalDuration: TimeInterval {
        executions
            .filter { $0.status == .completed }
            .compactMap { $0.duration }
            .reduce(0, +)
    }
}

// MARK: - Tool Executor Protocol

/// Protocol for executing tools with services context
public protocol ToolExecutor: Sendable {
    /// Execute a tool with given input and services context
    func execute(input: ToolInput, services: PeekabooServices) async throws -> ToolOutput
}

// MARK: - Tool Builder for Convenience

/// Convenience builder for creating tools
public struct ToolBuilder {
    public static func tool<Context>(
        name: String,
        description: String,
        parameters: ToolParameters,
        execute: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput
    ) -> Tool<Context> {
        Tool(
            name: name,
            description: description,
            parameters: parameters,
            execute: execute
        )
    }
    
    /// Build a tool specifically for PeekabooServices context
    public static func peekabooTool(
        name: String,
        description: String,
        parameters: ToolParameters,
        execute: @escaping @Sendable (ToolInput, PeekabooServices) async throws -> ToolOutput
    ) -> Tool<PeekabooServices> {
        tool(
            name: name,
            description: description,
            parameters: parameters,
            execute: execute
        )
    }
}