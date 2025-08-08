//
//  CommunicationToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for communication tools (task_completed, need_more_information, etc.)
public class CommunicationToolFormatter: BaseToolFormatter {
    
    public override func formatCompactSummary(arguments: [String: Any]) -> String {
        // Communication tools typically don't need argument summaries
        return ""
    }
    
    public override func formatResultSummary(result: [String: Any]) -> String {
        // Communication tools don't typically show result summaries
        // Their content is displayed as assistant messages instead
        return ""
    }
    
    public override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .taskCompleted:
            return "Completing task..."
            
        case .needMoreInformation, .needInfo:
            return "Requesting information..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
    
    public override func formatCompleted(result: [String: Any], duration: TimeInterval) -> String {
        // Communication tools typically don't show completion messages
        // since their content is displayed as assistant text
        return ""
    }
}