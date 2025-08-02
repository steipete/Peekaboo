import Foundation
import Tachikoma

// MARK: - Agent Tool Definition

/// A wrapper around Tachikoma's AITool that provides Peekaboo-specific context
public struct Tool<Context> {
    public let definition: ToolDefinition
    public let execute: (ToolInput, Context) async throws -> ToolOutput

    public init(
        definition: ToolDefinition,
        execute: @escaping (ToolInput, Context) async throws -> ToolOutput)
    {
        self.definition = definition
        self.execute = execute
    }

    /// Convert to Tachikoma's Tool with explicit module namespace  
    public func toTachikomaTool() {
        // TODO: Fix Tool<Context> type resolution 
        // The Tachikoma module exports Tool<Context> but we need to resolve the namespace conflict
        // between our local Tool<Context> and Tachikoma's Tool<Context>
    }
}

// MARK: - Re-export Tachikoma Types for Agent Use

// Note: Types are imported directly from Tachikoma module, not as nested types

// The types are directly available when importing Tachikoma
// They don't need typealiases since they're already in scope
