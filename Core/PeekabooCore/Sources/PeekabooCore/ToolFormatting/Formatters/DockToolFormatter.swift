//
//  DockToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for dock-related tools
public class DockToolFormatter: BaseToolFormatter {
    
    public override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .listDock:
            return ""
            
        case .dockClick:
            if let app = arguments["app"] as? String ?? arguments["appName"] as? String {
                return app
            } else if let position = arguments["position"] as? Int {
                return "position #\(position)"
            }
            return ""
            
        case .dockLaunch:
            if let app = arguments["appName"] as? String ?? arguments["app"] as? String {
                return app
            } else if let position = arguments["position"] as? Int {
                return "position #\(position)"
            }
            return "app"
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    public override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .listDock:
            // Check for totalCount in various formats
            if let totalCount = ToolResultExtractor.string("totalCount", from: result) {
                return "→ \(totalCount) items"
            } else if let totalCount = ToolResultExtractor.int("totalCount", from: result) {
                return "→ \(totalCount) items"
            } else if let count = ToolResultExtractor.int("count", from: result) {
                return "→ \(count) items"
            } else if let items = ToolResultExtractor.array("items", from: result) as [[String: Any]]? {
                return "→ \(items.count) items"
            }
            return "→ listed"
            
        case .dockClick:
            var parts: [String] = ["→ clicked"]
            
            if let app = ToolResultExtractor.string("app", from: result) ?? 
                       ToolResultExtractor.string("appName", from: result) {
                parts.append(app)
            } else if let position = ToolResultExtractor.int("position", from: result) {
                parts.append("position #\(position)")
            }
            
            parts.append("in dock")
            return parts.joined(separator: " ")
            
        case .dockLaunch:
            var parts: [String] = ["→ launched"]
            
            if let app = ToolResultExtractor.string("app", from: result) ?? 
                       ToolResultExtractor.string("appName", from: result) {
                parts.append(app)
            }
            
            parts.append("from dock")
            return parts.joined(separator: " ")
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    public override func formatStarting(arguments: [String: Any]) -> String
        switch toolType {
        case .listDock:
            return "Listing dock items..."
            
        case .dockClick:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Clicking \(summary) in dock..."
            }
            return "Clicking dock item..."
            
        case .dockLaunch:
            let app = arguments["appName"] as? String ?? arguments["app"] as? String ?? "app"
            return "Launching \(app) from dock..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}