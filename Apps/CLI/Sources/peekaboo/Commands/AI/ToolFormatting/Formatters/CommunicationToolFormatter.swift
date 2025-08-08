//
//  CommunicationToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for communication tools (task_completed, need_more_information, etc.)
class CommunicationToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        // Communication tools typically don't need argument summaries
        return ""
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        // Communication tools don't typically show result summaries
        // Their content is displayed as assistant messages instead
        return ""
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .taskCompleted:
            return "Completing task..."
            
        case .needMoreInformation, .needInfo:
            return "Requesting information..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
    
    override func formatCompleted(result: [String: Any], duration: TimeInterval) -> String {
        // Communication tools typically don't show completion messages
        // since their content is displayed as assistant text
        return ""
    }
}