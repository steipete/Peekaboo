//
//  ToolFormatterBridge.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Bridge to connect the CLI formatter system to the Mac app
@MainActor
class ToolFormatterBridge {
    
    static let shared = ToolFormatterBridge()
    
    private init() {}
    
    /// Format tool call for display in the Mac app
    func formatToolCall(name: String, arguments: String, result: String? = nil) -> String {
        // Parse tool type
        guard let toolType = ToolType(rawValue: name) else {
            return formatUnknownTool(name: name, arguments: arguments, result: result)
        }
        
        // Get formatter from registry
        let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
        
        // Parse arguments
        let args = parseArguments(arguments)
        
        if let result = result {
            // Format completed tool call
            let resultDict = parseArguments(result)
            let success = (resultDict["success"] as? Bool) ?? true
            
            if success {
                let summary = formatter.formatResultSummary(result: resultDict)
                if !summary.isEmpty {
                    return "✅ \(toolType.displayName): \(summary)"
                } else {
                    return "✅ \(toolType.displayName) completed"
                }
            } else {
                let error = (resultDict["error"] as? String) ?? "Failed"
                return "❌ \(toolType.displayName): \(error)"
            }
        } else {
            // Format tool call in progress
            let summary = formatter.formatCompactSummary(arguments: args)
            if !summary.isEmpty {
                return "🔧 \(toolType.displayName): \(summary)"
            } else {
                return "🔧 \(toolType.displayName)"
            }
        }
    }
    
    /// Format tool arguments for detailed view
    func formatArguments(name: String, arguments: String) -> String {
        guard let toolType = ToolType(rawValue: name) else {
            return arguments
        }
        
        let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
        let args = parseArguments(arguments)
        
        let summary = formatter.formatCompactSummary(arguments: args)
        if !summary.isEmpty {
            return summary
        }
        
        // Fall back to formatted JSON
        return formatJSON(arguments)
    }
    
    /// Format tool result for detailed view
    func formatResult(name: String, result: String) -> String {
        guard let toolType = ToolType(rawValue: name) else {
            return result
        }
        
        let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
        let resultDict = parseArguments(result)
        
        let summary = formatter.formatResultSummary(result: resultDict)
        if !summary.isEmpty {
            return summary
        }
        
        // Fall back to formatted JSON
        return formatJSON(result)
    }
    
    /// Get icon for tool
    func toolIcon(for name: String) -> String {
        if let toolType = ToolType(rawValue: name) {
            return toolType.icon
        }
        
        // Fallback icons for unknown tools
        switch name {
        case let n where n.contains("image") || n.contains("screenshot"):
            return "📷"
        case let n where n.contains("window"):
            return "🪟"
        case let n where n.contains("app"):
            return "📱"
        case let n where n.contains("click") || n.contains("mouse"):
            return "🖱"
        case let n where n.contains("type") || n.contains("keyboard"):
            return "⌨️"
        default:
            return "⚙️"
        }
    }
    
    /// Get display name for tool
    func toolDisplayName(for name: String) -> String {
        if let toolType = ToolType(rawValue: name) {
            return toolType.displayName
        }
        
        // Format unknown tool name
        return name.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    
    // MARK: - Private Helpers
    
    private func parseArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return args
    }
    
    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let result = String(data: formatted, encoding: .utf8) else {
            return json
        }
        return result
    }
    
    private func formatUnknownTool(name: String, arguments: String, result: String?) -> String {
        let displayName = toolDisplayName(for: name)
        
        if let result = result {
            let resultDict = parseArguments(result)
            let success = (resultDict["success"] as? Bool) ?? true
            
            if success {
                return "✅ \(displayName) completed"
            } else {
                let error = (resultDict["error"] as? String) ?? "Failed"
                return "❌ \(displayName): \(error)"
            }
        } else {
            return "🔧 \(displayName)"
        }
    }
}

// MARK: - ToolType Extension for Mac App

extension ToolType {
    /// Icon to use in Mac app UI
    var icon: String {
        switch self {
        // Vision tools
        case .see, .screenshot, .windowCapture, .analyze:
            return "👁"
            
        // Application tools
        case .launchApp, .listApps, .switchApp:
            return "📱"
        case .quitApp:
            return "🚫"
        case .focusApp, .hideApp, .unhideApp:
            return "🎯"
            
        // UI Automation tools
        case .click:
            return "🖱"
        case .type:
            return "⌨️"
        case .scroll:
            return "📜"
        case .hotkey, .press:
            return "⌨️"
        case .move:
            return "↔️"
            
        // Window tools
        case .focusWindow, .resizeWindow, .listWindows:
            return "🪟"
        case .minimizeWindow, .maximizeWindow:
            return "🪟"
        case .listScreens:
            return "🖥"
        case .listSpaces, .switchSpace, .moveWindowToSpace:
            return "🪟"
            
        // Menu tools
        case .menuClick, .listMenus:
            return "📋"
            
        // Dialog tools
        case .dialogInput:
            return "💬"
        case .dialogClick:
            return "🔘"
            
        // Dock tools
        case .dockClick:
            return "📋"
            
        // Element tools
        case .findElement, .listElements:
            return "🔍"
        case .focused:
            return "🎯"
            
        // System tools
        case .shell:
            return "💻"
        case .wait:
            return "⏱"
            
        // Communication tools
        case .taskCompleted:
            return "✅"
        case .needMoreInformation, .needInfo:
            return "❓"
        }
    }
}