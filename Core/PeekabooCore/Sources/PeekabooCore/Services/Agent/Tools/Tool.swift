import Foundation
import Tachikoma

// MARK: - Agent Tool Definition

/// A wrapper around Tachikoma's Tool that provides Peekaboo-specific context
public struct Tool<Context> {
    public let definition: ToolDefinition
    public let execute: (ToolInput, Context) async throws -> ToolOutput
    
    public init(
        definition: ToolDefinition,
        execute: @escaping (ToolInput, Context) async throws -> ToolOutput
    ) {
        self.definition = definition
        self.execute = execute
    }
    
    /// Convert to Tachikoma's generic Tool
    public func toTachikomaGenericTool() -> Tachikoma.Tool<Context> {
        return Tachikoma.Tool<Context>(execute: self.execute)
    }
}

// MARK: - Re-export Tachikoma Types for Agent Use

/// Re-export Tachikoma's ToolInput for convenience
public typealias ToolInput = Tachikoma.ToolInput

/// Re-export Tachikoma's ToolOutput for convenience  
public typealias ToolOutput = Tachikoma.ToolOutput

/// Re-export Tachikoma's ToolDefinition for convenience
public typealias ToolDefinition = Tachikoma.ToolDefinition

/// Re-export Tachikoma's FunctionDefinition for convenience
public typealias FunctionDefinition = Tachikoma.FunctionDefinition

/// Re-export Tachikoma's ToolParameters for convenience
public typealias ToolParameters = Tachikoma.ToolParameters

/// Re-export Tachikoma's ParameterSchema for convenience
public typealias ParameterSchema = Tachikoma.ParameterSchema