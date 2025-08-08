//
//  MenuDialogToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for menu and dialog interaction tools
class MenuDialogToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .menuClick:
            if let menuPath = arguments["menuPath"] as? String ?? arguments["path"] as? String {
                let components = menuPath.components(separatedBy: " > ")
                if components.count > 1 {
                    let menuName = components.first ?? ""
                    let itemName = components.last ?? ""
                    return "\(menuName) → \(itemName)"
                }
                return "'\(menuPath)'"
            }
            return ""
            
        case .listMenus:
            if let app = arguments["app"] as? String ?? arguments["appName"] as? String {
                return "for \(app)"
            }
            return ""
            
        case .dialogClick:
            if let button = arguments["button"] as? String {
                return "'\(button)'"
            }
            return "dialog button"
            
        case .dialogInput:
            var parts: [String] = []
            if let text = arguments["text"] as? String {
                let truncated = truncate(text, maxLength: 20)
                parts.append("'\(truncated)'")
            } else {
                parts.append("text")
            }
            if let field = arguments["field"] as? String {
                parts.append("in '\(field)'")
            }
            return parts.joined(separator: " ")
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .menuClick:
            var parts: [String] = ["→ clicked"]
            
            // Get the menu path with better formatting
            if let menuPath = ToolResultExtractor.string("menuPath", from: result) ??
                            ToolResultExtractor.string("path", from: result) {
                let components = menuPath.components(separatedBy: " > ")
                if components.count > 1 {
                    let menuName = components.first ?? ""
                    let itemName = components.last ?? ""
                    parts.append("\(menuName) → \(itemName)")
                } else {
                    parts.append("'\(menuPath)'")
                }
            }
            
            // Add app if available
            if let app = ToolResultExtractor.string("app", from: result) {
                parts.append("in \(app)")
            }
            
            // Add keyboard shortcut if the menu item had one
            if let shortcut = ToolResultExtractor.string("shortcut", from: result) {
                parts.append("(\(formatKeyboardShortcut(shortcut)))")
            }
            
            return parts.joined(separator: " ")
            
        case .listMenus:
            var parts: [String] = []
            
            // Check for menu count
            var menuCount: Int?
            if let count = ToolResultExtractor.int("menuCount", from: result) {
                menuCount = count
            } else if let menus = ToolResultExtractor.array("menus", from: result) as [[String: Any]]? {
                menuCount = menus.count
            }
            
            if let count = menuCount {
                parts.append("→ \(count) menu\(count == 1 ? "" : "s")")
            } else {
                parts.append("→ listed")
            }
            
            // Add app name
            if let app = ToolResultExtractor.string("app", from: result) ??
                       ToolResultExtractor.string("appName", from: result) {
                parts.append("for \(app)")
            }
            
            // Add total items count if available
            if let totalItems = ToolResultExtractor.int("totalItems", from: result) {
                parts.append("with \(totalItems) total item\(totalItems == 1 ? "" : "s")")
            }
            
            return parts.joined(separator: " ")
            
        case .dialogClick:
            var parts: [String] = ["→ clicked"]
            
            if let button = ToolResultExtractor.string("button", from: result) {
                parts.append("'\(button)'")
            }
            
            if let window = ToolResultExtractor.string("window", from: result) {
                parts.append("in \(window)")
            }
            
            return parts.joined(separator: " ")
            
        case .dialogInput:
            var parts: [String] = ["→ entered"]
            
            if let text = ToolResultExtractor.string("text", from: result) {
                let truncated = truncate(text)
                parts.append("'\(truncated)'")
            }
            
            if let field = ToolResultExtractor.string("field", from: result) {
                parts.append("in \(field)")
            }
            
            return parts.joined(separator: " ")
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .menuClick:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Clicking menu \(summary)..."
            }
            return "Clicking menu..."
            
        case .listMenus:
            if let app = arguments["app"] as? String ?? arguments["appName"] as? String {
                return "Listing menus for \(app)..."
            }
            return "Listing menu structure..."
            
        case .dialogClick:
            if let button = arguments["button"] as? String {
                return "Clicking '\(button)' button..."
            }
            return "Clicking dialog button..."
            
        case .dialogInput:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Entering \(summary)..."
            }
            return "Entering dialog input..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}