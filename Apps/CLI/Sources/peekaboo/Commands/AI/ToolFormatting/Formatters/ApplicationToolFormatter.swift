//
//  ApplicationToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for application management tools
class ApplicationToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .launchApp:
            return arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            
        case .listApps:
            return "" // No arguments to summarize
            
        case .quitApp, .focusApp, .hideApp, .unhideApp:
            return arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            
        case .switchApp:
            return arguments["to"] as? String ?? arguments["appName"] as? String ?? ""
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .launchApp:
            let appName = ToolResultExtractor.string("app", from: result) 
                ?? ToolResultExtractor.string("appName", from: result)
                ?? ToolResultExtractor.string("name", from: result)
                ?? "application"
            
            let wasRunning = ToolResultExtractor.bool("wasRunning", from: result) ?? false
            if wasRunning {
                return "→ \(appName) (was already running)"
            }
            return "→ \(appName)"
            
        case .listApps:
            // Try various count locations
            if let count = ToolResultExtractor.int("count", from: result) {
                return "→ \(count) apps running"
            }
            
            // Check for applications array
            if let apps = ToolResultExtractor.array("applications", from: result) as [[String: Any]]? {
                return "→ \(apps.count) apps running"
            }
            
            // Check in data.applications
            if let data = result["data"] as? [String: Any],
               let apps = data["applications"] as? [[String: Any]] {
                return "→ \(apps.count) apps running"
            }
            
            return "→ listed"
            
        case .quitApp:
            let appName = ToolResultExtractor.string("app", from: result) ?? "application"
            return "→ quit \(appName)"
            
        case .focusApp:
            let appName = ToolResultExtractor.string("app", from: result) ?? "application"
            return "→ focused \(appName)"
            
        case .hideApp:
            let appName = ToolResultExtractor.string("app", from: result) ?? "application"
            return "→ hidden \(appName)"
            
        case .unhideApp:
            let appName = ToolResultExtractor.string("app", from: result) ?? "application"
            return "→ shown \(appName)"
            
        case .switchApp:
            let appName = ToolResultExtractor.string("app", from: result) ?? "application"
            return "→ switched to \(appName)"
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .launchApp:
            let appName = arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            return "Launching \(appName)..."
            
        case .listApps:
            return "Listing running applications..."
            
        case .quitApp:
            let appName = arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            return "Quitting \(appName)..."
            
        case .focusApp:
            let appName = arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            return "Focusing \(appName)..."
            
        case .hideApp:
            let appName = arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            return "Hiding \(appName)..."
            
        case .unhideApp:
            let appName = arguments["name"] as? String ?? arguments["appName"] as? String ?? "application"
            return "Showing \(appName)..."
            
        case .switchApp:
            let appName = arguments["to"] as? String ?? arguments["appName"] as? String ?? "application"
            return "Switching to \(appName)..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}