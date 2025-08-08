//
//  WindowToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for window management tools
class WindowToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"
            
        case .resizeWindow:
            var parts: [String] = []
            if let app = arguments["appName"] as? String {
                parts.append(app)
            }
            if let width = arguments["width"], let height = arguments["height"] {
                parts.append("to \(width)x\(height)")
            }
            return parts.isEmpty ? "active window" : parts.joined(separator: " ")
            
        case .listWindows:
            if let app = arguments["appName"] as? String {
                return "for \(app)"
            }
            return ""
            
        case .minimizeWindow, .maximizeWindow:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"
            
        case .listScreens:
            return ""
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            var parts: [String] = ["→ focused"]
            
            if let app = ToolResultExtractor.string("app", from: result) ?? 
                       ToolResultExtractor.string("appName", from: result) {
                parts.append(app)
            }
            
            if let title = ToolResultExtractor.string("windowTitle", from: result) {
                parts.append("- \(truncate(title))")
            }
            
            return parts.joined(separator: " ")
            
        case .resizeWindow:
            var parts: [String] = ["→ resized"]
            
            if let app = ToolResultExtractor.string("app", from: result) {
                parts.append(app)
            }
            
            if let width = ToolResultExtractor.int("width", from: result),
               let height = ToolResultExtractor.int("height", from: result) {
                parts.append("to \(width)×\(height)")
            }
            
            return parts.joined(separator: " ")
            
        case .listWindows:
            var windowCount = 0
            
            // Try various count locations
            if let count = ToolResultExtractor.int("count", from: result) {
                windowCount = count
            } else if let windows = ToolResultExtractor.array("windows", from: result) as [[String: Any]]? {
                windowCount = windows.count
            } else if let data = result["data"] as? [String: Any],
                      let windows = data["windows"] as? [[String: Any]] {
                windowCount = windows.count
            }
            
            if windowCount == 0 {
                return "→ no windows"
            } else if windowCount == 1 {
                return "→ 1 window"
            } else {
                var parts = ["→ \(windowCount) windows"]
                
                // Add app name if specified
                if let app = ToolResultExtractor.string("app", from: result) ??
                           ToolResultExtractor.string("appName", from: result) {
                    parts.append("for \(app)")
                }
                
                return parts.joined(separator: " ")
            }
            
        case .minimizeWindow:
            let app = ToolResultExtractor.string("app", from: result) ?? "window"
            return "→ minimized \(app)"
            
        case .maximizeWindow:
            let app = ToolResultExtractor.string("app", from: result) ?? "window"
            return "→ maximized \(app)"
            
        case .listScreens:
            if let screens = ToolResultExtractor.array("screens", from: result) as [[String: Any]]? {
                return "→ \(screens.count) screen\(screens.count == 1 ? "" : "s")"
            }
            return "→ listed"
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Focusing \(app)..."
            
        case .resizeWindow:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Resizing \(summary)..."
            }
            return "Resizing window..."
            
        case .listWindows:
            if let app = arguments["appName"] as? String {
                return "Listing windows for \(app)..."
            }
            return "Listing all windows..."
            
        case .minimizeWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Minimizing \(app)..."
            
        case .maximizeWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Maximizing \(app)..."
            
        case .listScreens:
            return "Listing screens..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}