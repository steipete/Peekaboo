//
//  UIAutomationToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for UI automation tools with comprehensive result formatting
public class UIAutomationToolFormatter: BaseToolFormatter {
    
    public override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .click:
            return formatClickResult(result)
        case .type:
            return formatTypeResult(result)
        case .hotkey:
            return formatHotkeyResult(result)
        case .press:
            return formatPressResult(result)
        case .scroll:
            return formatScrollResult(result)
        
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    private func formatClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Basic click confirmation
        parts.append("→ Clicked")
        
        // Element details
        if let element = ToolResultExtractor.string("element", from: result) {
            let truncated = element.count > 40 
                ? String(element.prefix(40)) + "..."
                : element
            parts.append("on \"\(truncated)\"")
        } else if let description = ToolResultExtractor.string("description", from: result) {
            let truncated = description.count > 40
                ? String(description.prefix(40)) + "..."
                : description
            parts.append("on \(truncated)")
        }
        
        // Position
        if let position = ToolResultExtractor.dictionary("position", from: result) {
            if let x = position["x"] as? Int,
               let y = position["y"] as? Int {
                parts.append("at (\(x), \(y))")
            }
        } else if let x = ToolResultExtractor.int("x", from: result),
                  let y = ToolResultExtractor.int("y", from: result) {
            parts.append("at (\(x), \(y))")
        }
        
        // Click details
        var details: [String] = []
        
        if let clickCount = ToolResultExtractor.int("clickCount", from: result), clickCount > 1 {
            details.append("\(clickCount) clicks")
        }
        
        if let button = ToolResultExtractor.string("button", from: result), button != "left" {
            details.append("\(button) button")
        }
        
        if let modifiers: [String] = ToolResultExtractor.array("modifiers", from: result), !modifiers.isEmpty {
            let modifierStr = FormattingUtilities.formatKeyboardShortcut(modifiers.joined(separator: "+"))
            details.append("with \(modifierStr)")
        }
        
        // Element info
        if let elementType = ToolResultExtractor.string("elementType", from: result) {
            details.append(elementType)
        }
        
        if let role = ToolResultExtractor.string("role", from: result) {
            details.append("role: \(role)")
        }
        
        // App context
        if let app = ToolResultExtractor.string("app", from: result) {
            details.append("in \(app)")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        // Action triggered
        if let actionTriggered = ToolResultExtractor.string("actionTriggered", from: result) {
            parts.append("• Triggered: \(actionTriggered)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatDoubleClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Double-clicked")
        
        // Element or description
        if let element = ToolResultExtractor.string("element", from: result) {
            let truncated = element.count > 40
                ? String(element.prefix(40)) + "..."
                : element
            parts.append("on \"\(truncated)\"")
        }
        
        // Position
        if let x = ToolResultExtractor.int("x", from: result),
           let y = ToolResultExtractor.int("y", from: result) {
            parts.append("at (\(x), \(y))")
        }
        
        // Action result
        if let opened = ToolResultExtractor.string("opened", from: result) {
            parts.append("• Opened: \(opened)")
        } else if let action = ToolResultExtractor.string("action", from: result) {
            parts.append("• \(action)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatRightClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Right-clicked")
        
        // Element
        if let element = ToolResultExtractor.string("element", from: result) {
            let truncated = element.count > 40
                ? String(element.prefix(40)) + "..."
                : element
            parts.append("on \"\(truncated)\"")
        }
        
        // Position
        if let x = ToolResultExtractor.int("x", from: result),
           let y = ToolResultExtractor.int("y", from: result) {
            parts.append("at (\(x), \(y))")
        }
        
        // Context menu
        if let menuItems: [String] = ToolResultExtractor.array("contextMenuItems", from: result) {
            let count = menuItems.count
            parts.append("• Menu with \(count) item\(count == 1 ? "" : "s")")
            
            if count <= 5 {
                let itemList = menuItems.joined(separator: ", ")
                parts.append("[\(itemList)]")
            }
        } else if let menuOpened = ToolResultExtractor.bool("menuOpened", from: result), menuOpened {
            parts.append("• Context menu opened")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatTypeResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Typed")
        
        // Text typed
        if let text = ToolResultExtractor.string("text", from: result) {
            let displayText = text.count > 50
                ? String(text.prefix(47)) + "..."
                : text
            // Show text with proper escaping for special characters
            let escaped = displayText
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
            parts.append("\"\(escaped)\"")
        }
        
        // Target field
        if let field = ToolResultExtractor.string("field", from: result) {
            parts.append("in \(field)")
        } else if let element = ToolResultExtractor.string("element", from: result) {
            parts.append("in \(element)")
        }
        
        // Additional details
        var details: [String] = []
        
        if let characterCount = ToolResultExtractor.int("characterCount", from: result) {
            details.append("\(characterCount) chars")
        }
        
        if let wordCount = ToolResultExtractor.int("wordCount", from: result) {
            details.append("\(wordCount) words")
        }
        
        if let cleared = ToolResultExtractor.bool("clearedFirst", from: result), cleared {
            details.append("cleared first")
        }
        
        if let submitted = ToolResultExtractor.bool("submitted", from: result), submitted {
            details.append("submitted")
        }
        
        if let typingSpeed = ToolResultExtractor.string("typingSpeed", from: result) {
            details.append(typingSpeed)
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        // Validation result
        if let validation = ToolResultExtractor.dictionary("validation", from: result) {
            if let isValid = validation["isValid"] as? Bool {
                if isValid {
                    parts.append("✓ Valid")
                } else if let error = validation["error"] as? String {
                    parts.append("✗ \(error)")
                }
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatHotkeyResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Pressed")
        
        // Keyboard shortcut
        if let keys = ToolResultExtractor.string("keys", from: result) {
            let formatted = FormattingUtilities.formatKeyboardShortcut(keys)
            parts.append(formatted)
        } else if let shortcut = ToolResultExtractor.string("shortcut", from: result) {
            let formatted = FormattingUtilities.formatKeyboardShortcut(shortcut)
            parts.append(formatted)
        }
        
        // Action triggered
        if let action = ToolResultExtractor.string("action", from: result) {
            parts.append("• \(action)")
        } else if let triggered = ToolResultExtractor.string("triggered", from: result) {
            parts.append("• \(triggered)")
        }
        
        // App context
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("in \(app)")
        }
        
        // Result details
        var details: [String] = []
        
        if let windowOpened = ToolResultExtractor.string("windowOpened", from: result) {
            details.append("opened: \(windowOpened)")
        }
        
        if let commandExecuted = ToolResultExtractor.string("commandExecuted", from: result) {
            details.append("executed: \(commandExecuted)")
        }
        
        if let modeChanged = ToolResultExtractor.string("modeChanged", from: result) {
            details.append("mode: \(modeChanged)")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatPressResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Pressed")
        
        // Key pressed
        if let key = ToolResultExtractor.string("key", from: result) {
            // Format special keys nicely
            let displayKey = formatSpecialKey(key)
            parts.append(displayKey)
        }
        
        // Repeat count
        if let repeatCount = ToolResultExtractor.int("repeatCount", from: result), repeatCount > 1 {
            parts.append("\(repeatCount) times")
        }
        
        // Context and result
        var details: [String] = []
        
        if let moved = ToolResultExtractor.string("moved", from: result) {
            details.append("moved: \(moved)")
        }
        
        if let selected = ToolResultExtractor.string("selected", from: result) {
            details.append("selected: \(selected)")
        }
        
        if let navigated = ToolResultExtractor.string("navigated", from: result) {
            details.append("navigated: \(navigated)")
        }
        
        if let deleted = ToolResultExtractor.bool("deleted", from: result), deleted {
            details.append("deleted text")
        }
        
        if let inserted = ToolResultExtractor.string("inserted", from: result) {
            details.append("inserted: \(inserted)")
        }
        
        if !details.isEmpty {
            parts.append("• \(details.joined(separator: ", "))")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatScrollResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Scrolled")
        
        // Direction and amount
        if let direction = ToolResultExtractor.string("direction", from: result) {
            parts.append(direction)
        }
        
        if let amount = ToolResultExtractor.int("amount", from: result) {
            parts.append("\(amount) units")
        } else if let pixels = ToolResultExtractor.int("pixels", from: result) {
            parts.append("\(pixels)px")
        } else if let lines = ToolResultExtractor.int("lines", from: result) {
            parts.append("\(lines) lines")
        } else if let pages = ToolResultExtractor.double("pages", from: result) {
            parts.append(String(format: "%.1f pages", pages))
        }
        
        // Target
        if let element = ToolResultExtractor.string("element", from: result) {
            parts.append("in \(element)")
        } else if let container = ToolResultExtractor.string("container", from: result) {
            parts.append("in \(container)")
        }
        
        // Scroll position
        var details: [String] = []
        
        if let position = ToolResultExtractor.dictionary("scrollPosition", from: result) {
            if let x = position["x"] as? Int,
               let y = position["y"] as? Int {
                details.append("position: (\(x), \(y))")
            }
        }
        
        if let percentage = ToolResultExtractor.double("scrollPercentage", from: result) {
            details.append(String(format: "%.0f%%", percentage))
        }
        
        if let atTop = ToolResultExtractor.bool("atTop", from: result), atTop {
            details.append("at top")
        } else if let atBottom = ToolResultExtractor.bool("atBottom", from: result), atBottom {
            details.append("at bottom")
        }
        
        if let revealed = ToolResultExtractor.string("revealed", from: result) {
            details.append("revealed: \(revealed)")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatDragDropResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Dragged")
        
        // Source
        if let source = ToolResultExtractor.string("source", from: result) {
            let truncated = source.count > 30
                ? String(source.prefix(30)) + "..."
                : source
            parts.append("\"\(truncated)\"")
        }
        
        // Destination
        if let destination = ToolResultExtractor.string("destination", from: result) {
            let truncated = destination.count > 30
                ? String(destination.prefix(30)) + "..."
                : destination
            parts.append("to \"\(truncated)\"")
        }
        
        // Positions
        if let startPos = ToolResultExtractor.dictionary("startPosition", from: result),
           let endPos = ToolResultExtractor.dictionary("endPosition", from: result) {
            if let sx = startPos["x"] as? Int,
               let sy = startPos["y"] as? Int,
               let ex = endPos["x"] as? Int,
               let ey = endPos["y"] as? Int {
                parts.append("from (\(sx), \(sy)) to (\(ex), \(ey))")
            }
        }
        
        // Result details
        var details: [String] = []
        
        if let moved = ToolResultExtractor.bool("moved", from: result), moved {
            details.append("moved")
        }
        
        if let copied = ToolResultExtractor.bool("copied", from: result), copied {
            details.append("copied")
        }
        
        if let reordered = ToolResultExtractor.bool("reordered", from: result), reordered {
            details.append("reordered")
        }
        
        if let itemCount = ToolResultExtractor.int("itemCount", from: result) {
            details.append("\(itemCount) item\(itemCount == 1 ? "" : "s")")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatSwipeResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Swiped")
        
        // Direction
        if let direction = ToolResultExtractor.string("direction", from: result) {
            parts.append(direction)
        }
        
        // Distance
        if let distance = ToolResultExtractor.int("distance", from: result) {
            parts.append("\(distance)px")
        } else if let percentage = ToolResultExtractor.double("percentage", from: result) {
            parts.append(String(format: "%.0f%%", percentage))
        }
        
        // Speed
        if let speed = ToolResultExtractor.string("speed", from: result) {
            parts.append("(\(speed))")
        }
        
        // Target
        if let element = ToolResultExtractor.string("element", from: result) {
            parts.append("on \(element)")
        }
        
        // Result
        var details: [String] = []
        
        if let navigated = ToolResultExtractor.string("navigated", from: result) {
            details.append("navigated to: \(navigated)")
        }
        
        if let dismissed = ToolResultExtractor.bool("dismissed", from: result), dismissed {
            details.append("dismissed")
        }
        
        if let revealed = ToolResultExtractor.string("revealed", from: result) {
            details.append("revealed: \(revealed)")
        }
        
        if let gesture = ToolResultExtractor.string("gesture", from: result) {
            details.append("gesture: \(gesture)")
        }
        
        if !details.isEmpty {
            parts.append("• \(details.joined(separator: ", "))")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Helper Methods
    
    private func formatSpecialKey(_ key: String) -> String {
        switch key.lowercased() {
        case "return", "enter": return "⏎ Enter"
        case "tab": return "⇥ Tab"
        case "escape", "esc": return "⎋ Escape"
        case "space": return "␣ Space"
        case "delete", "backspace": return "⌫ Delete"
        case "up", "arrow_up": return "↑ Up"
        case "down", "arrow_down": return "↓ Down"
        case "left", "arrow_left": return "← Left"
        case "right", "arrow_right": return "→ Right"
        case "home": return "↖ Home"
        case "end": return "↘ End"
        case "pageup", "page_up": return "⇞ Page Up"
        case "pagedown", "page_down": return "⇟ Page Down"
        case "f1"..."f12": return "🔘 \(key.uppercased())"
        default: return key
        }
    }
}