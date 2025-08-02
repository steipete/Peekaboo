import Foundation
import Tachikoma

// MARK: - Agent Tool Definition

/// A wrapper around Tachikoma's AITool that provides Peekaboo-specific context
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
    
    /// Convert to Tachikoma's AITool
    public func toTachikomaAITool() -> AITool<Context> {
        return AITool<Context>(
            name: self.definition.function.name,
            description: self.definition.function.description,
            parameters: self.definition.function.parameters,
            execute: self.execute
        )
    }
}

// MARK: - Re-export Tachikoma Types for Agent Use
// Note: Types are imported directly from Tachikoma module, not as nested types

// The types are directly available when importing Tachikoma
// They don't need typealiases since they're already in scope
