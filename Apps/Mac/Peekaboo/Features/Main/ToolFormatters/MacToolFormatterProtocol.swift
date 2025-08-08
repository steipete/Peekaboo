//
//  MacToolFormatterProtocol.swift
//  Peekaboo
//

import Foundation

/// Protocol for tool-specific formatters in the Mac app
protocol MacToolFormatterProtocol {
    /// The tool names this formatter handles
    var handledTools: Set<String> { get }
    
    /// Format the tool execution summary from arguments
    func formatSummary(toolName: String, arguments: [String: Any]) -> String?
    
    /// Format the tool result summary
    func formatResult(toolName: String, result: [String: Any]) -> String?
}