//
//  UIAutomationToolFormatter.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Formatter for UI automation tools (click, type, scroll, hotkey, etc.)
struct UIAutomationToolFormatter: MacToolFormatterProtocol {
    let handledTools: Set<String> = ["click", "type", "scroll", "hotkey", "press", "dialog_click", "dialog_input", "dock_click"]
    
    func formatSummary(toolName: String, arguments: [String: Any]) -> String? {
        switch toolName {
        case "click":
            return formatClickSummary(arguments)
        case "type":
            return formatTypeSummary(arguments)
        case "scroll":
            return formatScrollSummary(arguments)
        case "hotkey":
            return formatHotkeySummary(arguments)
        case "press":
            return formatPressSummary(arguments)
        case "dialog_click":
            return formatDialogClickSummary(arguments)
        case "dialog_input":
            return formatDialogInputSummary(arguments)
        case "dock_click":
            return formatDockClickSummary(arguments)
        default:
            return nil
        }
    }
    
    func formatResult(toolName: String, result: [String: Any]) -> String? {
        switch toolName {
        case "click", "dialog_click", "dock_click":
            return formatClickResult(result)
        case "type", "dialog_input":
            return formatTypeResult(result)
        case "scroll":
            return formatScrollResult(result)
        case "hotkey", "press":
            return formatHotkeyResult(result)
        default:
            return nil
        }
    }
    
    // MARK: - Click Tool
    
    private func formatClickSummary(_ args: [String: Any]) -> String {
        var parts = ["Click"]
        
        // Check for coordinates first (most specific)
        if let coords = args["coords"] as? String {
            parts.append("at \(coords)")
        } else if let x = args["x"], let y = args["y"] {
            parts.append("at (\(x), \(y))")
        }
        // Then check for element description
        else if let element = args["element"] as? String {
            parts.append("on '\(element)'")
        }
        // Check for button type if non-standard
        else if let button = args["button"] as? String {
            parts.append("\(button) button")
        }
        
        // Add click count if double/triple
        if let clickCount = args["clickCount"] as? Int, clickCount > 1 {
            parts.insert(clickCount == 2 ? "Double" : "Triple", at: 0)
            parts.removeFirst() // Remove "Click"
            parts.insert("click", at: 1)
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatClickResult(_ result: [String: Any]) -> String? {
        if let element = result["element"] as? String {
            return "Clicked '\(element)'"
        }
        if let coords = result["coordinates"] as? [String: Any],
           let x = coords["x"], let y = coords["y"] {
            return "Clicked at (\(x), \(y))"
        }
        return nil
    }
    
    // MARK: - Type Tool
    
    private func formatTypeSummary(_ args: [String: Any]) -> String {
        var parts = ["Type"]
        
        if let text = args["text"] as? String {
            // Truncate long text
            let displayText = text.count > 30 
                ? "'\(text.prefix(30))...'"
                : "'\(text)'"
            parts.append(displayText)
        }
        
        if let element = args["element"] as? String {
            parts.append("into '\(element)'")
        }
        
        if args["clear"] as? Bool == true {
            parts.insert("Clear and", at: 0)
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatTypeResult(_ result: [String: Any]) -> String? {
        if let typed = result["typedText"] as? String {
            let displayText = typed.count > 30 
                ? "'\(typed.prefix(30))...'"
                : "'\(typed)'"
            return "Typed \(displayText)"
        }
        return nil
    }
    
    // MARK: - Scroll Tool
    
    private func formatScrollSummary(_ args: [String: Any]) -> String {
        var parts = ["Scroll"]
        
        if let direction = args["direction"] as? String {
            parts.append(direction)
        }
        
        if let amount = args["amount"] as? Int {
            parts.append("by \(amount)")
        }
        
        if let element = args["element"] as? String {
            parts.append("in '\(element)'")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatScrollResult(_ result: [String: Any]) -> String? {
        if let direction = result["direction"] as? String,
           let amount = result["amount"] as? Int {
            return "Scrolled \(direction) by \(amount)"
        }
        return nil
    }
    
    // MARK: - Hotkey Tool
    
    private func formatHotkeySummary(_ args: [String: Any]) -> String {
        if let keys = args["keys"] as? String {
            let formatted = FormattingUtilities.formatKeyboardShortcut(keys)
            return "Press \(formatted)"
        }
        return "Press hotkey"
    }
    
    private func formatHotkeyResult(_ result: [String: Any]) -> String? {
        if let keys = result["keys"] as? String {
            let formatted = FormattingUtilities.formatKeyboardShortcut(keys)
            return "Pressed \(formatted)"
        }
        return nil
    }
    
    // MARK: - Press Tool
    
    private func formatPressSummary(_ args: [String: Any]) -> String {
        if let key = args["key"] as? String {
            return "Press '\(key)'"
        }
        return "Press key"
    }
    
    // MARK: - Dialog Tools
    
    private func formatDialogClickSummary(_ args: [String: Any]) -> String {
        if let button = args["button"] as? String {
            return "Click '\(button)' in dialog"
        }
        return "Click dialog button"
    }
    
    private func formatDialogInputSummary(_ args: [String: Any]) -> String {
        var parts = ["Enter"]
        
        if let text = args["text"] as? String {
            let displayText = text.count > 30 
                ? "'\(text.prefix(30))...'"
                : "'\(text)'"
            parts.append(displayText)
        }
        
        parts.append("in dialog")
        
        if let field = args["field"] as? String {
            parts.append("field '\(field)'")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Dock Tool
    
    private func formatDockClickSummary(_ args: [String: Any]) -> String {
        if let app = args["app"] as? String {
            return "Click '\(app)' in Dock"
        }
        return "Click Dock item"
    }
}