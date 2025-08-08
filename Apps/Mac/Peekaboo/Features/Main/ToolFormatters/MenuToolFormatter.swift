//
//  MenuToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for menu and dock-related tools
struct MenuToolFormatter: MacToolFormatterProtocol {
    let handledTools: Set<String> = ["menu_click", "list_menus", "list_dock"]
    
    func formatSummary(toolName: String, arguments: [String: Any]) -> String? {
        switch toolName {
        case "menu_click":
            return formatMenuClickSummary(arguments)
        case "list_menus":
            return formatListMenusSummary(arguments)
        case "list_dock":
            return "List Dock items"
        default:
            return nil
        }
    }
    
    func formatResult(toolName: String, result: [String: Any]) -> String? {
        switch toolName {
        case "menu_click":
            return formatMenuClickResult(result)
        case "list_menus":
            return formatListMenusResult(result)
        case "list_dock":
            return formatListDockResult(result)
        default:
            return nil
        }
    }
    
    // MARK: - Menu Click
    
    private func formatMenuClickSummary(_ args: [String: Any]) -> String {
        var parts = ["Click"]
        
        if let path = args["path"] as? String {
            // Format menu path nicely
            let components = path.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count > 0 {
                parts.append("'\(components.joined(separator: " → "))'")
            } else {
                parts.append("menu '\(path)'")
            }
        } else if let menu = args["menu"] as? String {
            parts.append("menu '\(menu)'")
            if let item = args["item"] as? String {
                parts.append("→ '\(item)'")
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatMenuClickResult(_ result: [String: Any]) -> String? {
        if let clicked = result["clicked"] as? String {
            return "Clicked '\(clicked)'"
        }
        
        if let path = result["path"] as? String {
            let components = path.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count > 0 {
                return "Clicked '\(components.joined(separator: " → "))')"
            }
        }
        
        return nil
    }
    
    // MARK: - List Menus
    
    private func formatListMenusSummary(_ args: [String: Any]) -> String {
        var parts = ["List menus"]
        
        if let app = args["app"] as? String {
            parts.append("for \(app)")
        } else if let appName = args["appName"] as? String {
            parts.append("for \(appName)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatListMenusResult(_ result: [String: Any]) -> String? {
        var parts: [String] = []
        
        // Check for menu count
        var menuCount: Int?
        if let count = result["menuCount"] as? Int {
            menuCount = count
        } else if let menus = result["menus"] as? [[String: Any]] {
            menuCount = menus.count
        }
        
        if let count = menuCount {
            parts.append("Found \(count) menu\(count == 1 ? "" : "s")")
        } else {
            parts.append("Listed menus")
        }
        
        // Add app name
        if let app = result["app"] as? String {
            parts.append("for \(app)")
        } else if let appName = result["appName"] as? String {
            parts.append("for \(appName)")
        }
        
        // Add total items count if available
        if let totalItems = result["totalItems"] as? Int {
            parts.append("with \(totalItems) total item\(totalItems == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - List Dock
    
    private func formatListDockResult(_ result: [String: Any]) -> String? {
        if let items = result["items"] as? [[String: Any]] {
            let appCount = items.filter { ($0["type"] as? String) == "app" }.count
            let otherCount = items.count - appCount
            
            if otherCount > 0 {
                return "→ \(appCount) apps, \(otherCount) other item\(otherCount == 1 ? "" : "s")"
            } else {
                return "→ \(appCount) app\(appCount == 1 ? "" : "s") in Dock"
            }
        }
        
        if let count = result["count"] as? Int {
            return "→ \(count) item\(count == 1 ? "" : "s") in Dock"
        }
        
        return "Listed Dock items"
    }
}