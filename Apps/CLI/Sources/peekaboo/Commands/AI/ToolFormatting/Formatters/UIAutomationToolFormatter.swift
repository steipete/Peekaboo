//
//  UIAutomationToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for UI automation tools (click, type, scroll, etc.)
class UIAutomationToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .click:
            if let target = arguments["target"] as? String {
                // Check if it's an element ID (like B7, O6, etc.) or text
                if target.count <= 3, target.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    return "element \(target)"
                } else {
                    return "'\(truncate(target))'"
                }
            } else if let element = arguments["element"] as? String {
                return "element \(element)"
            } else if let on = arguments["on"] as? String {
                return "element \(on)"
            } else if let x = arguments["x"], let y = arguments["y"] {
                return "at (\(x), \(y))"
            }
            return ""
            
        case .type:
            if let text = arguments["text"] as? String {
                return "'\(text)'"
            }
            return ""
            
        case .scroll:
            if let direction = arguments["direction"] as? String {
                if let amount = arguments["amount"] as? Int {
                    return "\(direction) \(amount)px"
                }
                return direction
            }
            return "down"
            
        case .hotkey, .press:
            if let keys = arguments["keys"] as? String {
                return formatKeyboardShortcut(keys)
            } else if let key = arguments["key"] as? String {
                var parts: [String] = []
                if let modifiers = arguments["modifiers"] as? [String], !modifiers.isEmpty {
                    for mod in modifiers {
                        switch mod.lowercased() {
                        case "command", "cmd": parts.append("⌘")
                        case "shift": parts.append("⇧")
                        case "option", "opt", "alt": parts.append("⌥")
                        case "control", "ctrl": parts.append("⌃")
                        default: parts.append(mod)
                        }
                    }
                }
                parts.append(key)
                return parts.joined()
            }
            return "keyboard shortcut"
            
        case .drag:
            var parts: [String] = []
            if let from = arguments["from"] as? String {
                parts.append("from \(from)")
            } else if let fromCoords = arguments["from_coords"] as? String {
                parts.append("from \(fromCoords)")
            }
            if let to = arguments["to"] as? String {
                parts.append("to \(to)")
            } else if let toCoords = arguments["to_coords"] as? String {
                parts.append("to \(toCoords)")
            }
            return parts.joined(separator: " ")
            
        case .move:
            if let x = arguments["x"], let y = arguments["y"] {
                return "to (\(x), \(y))"
            }
            return ""
            
        case .swipe:
            var parts: [String] = []
            if let from = arguments["from"] as? String {
                parts.append("from \(from)")
            }
            if let to = arguments["to"] as? String {
                parts.append("to \(to)")
            }
            if let duration = arguments["duration"] as? Int {
                parts.append("(\(duration)ms)")
            }
            return parts.joined(separator: " ")
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .click:
            var parts: [String] = ["→"]
            
            // Get click type
            if let type = ToolResultExtractor.string("type", from: result) {
                switch type {
                case "right_click": parts.append("right-clicked")
                case "double_click": parts.append("double-clicked")
                default: parts.append("clicked")
                }
            } else {
                parts.append("clicked")
            }
            
            // Get what was clicked
            if let coords = ToolResultExtractor.coordinates(from: result) {
                parts.append("at (\(coords.x), \(coords.y))")
            } else if let element = ToolResultExtractor.string("element", from: result) {
                if element.count <= 3, element.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    parts.append("element \(element)")
                } else {
                    parts.append("'\(truncate(element))'")
                }
            } else if let target = ToolResultExtractor.string("target", from: result) {
                parts.append("'\(truncate(target))'")
            }
            
            return parts.joined(separator: " ")
            
        case .type:
            var parts: [String] = ["→ typed"]
            
            if let typed = ToolResultExtractor.string("typed", from: result) ?? ToolResultExtractor.string("text", from: result) {
                parts.append("'\(truncate(typed, maxLength: 20))'")
            }
            
            if let element = ToolResultExtractor.string("element", from: result) ?? ToolResultExtractor.string("on", from: result) {
                parts.append("in element \(element)")
            }
            
            if let cleared = ToolResultExtractor.bool("cleared", from: result), cleared {
                parts.append("(cleared field)")
            }
            
            if let pressedReturn = ToolResultExtractor.bool("pressedReturn", from: result), pressedReturn {
                parts.append("(pressed return)")
            }
            
            return parts.joined(separator: " ")
            
        case .scroll:
            var parts: [String] = ["→ scrolled"]
            
            if let direction = ToolResultExtractor.string("direction", from: result) {
                parts.append(direction)
            }
            
            if let amount = ToolResultExtractor.int("amount", from: result) {
                parts.append("\(amount) line\(amount == 1 ? "" : "s")")
            } else if let pixels = ToolResultExtractor.int("pixels", from: result) {
                parts.append("\(pixels) pixel\(pixels == 1 ? "" : "s")")
            }
            
            if let element = ToolResultExtractor.string("element", from: result) ?? ToolResultExtractor.string("on", from: result) {
                parts.append("on element \(element)")
            }
            
            if let smooth = ToolResultExtractor.bool("smooth", from: result), smooth {
                parts.append("(smooth)")
            }
            
            return parts.joined(separator: " ")
            
        case .hotkey, .press:
            var parts: [String] = ["→ pressed"]
            
            if let keys = ToolResultExtractor.string("keys", from: result) {
                parts.append(formatKeyboardShortcut(keys))
            } else if let key = ToolResultExtractor.string("key", from: result) {
                var keyParts: [String] = []
                if let modifiers = ToolResultExtractor.string("modifiers", from: result), !modifiers.isEmpty {
                    let mods = modifiers.split(separator: ",").map(String.init)
                    for mod in mods {
                        switch mod.lowercased() {
                        case "command", "cmd": keyParts.append("⌘")
                        case "shift": keyParts.append("⇧")
                        case "option", "opt", "alt": keyParts.append("⌥")
                        case "control", "ctrl": keyParts.append("⌃")
                        default: keyParts.append(mod)
                        }
                    }
                }
                keyParts.append(key)
                parts.append(keyParts.joined())
            }
            
            return parts.joined(separator: " ")
            
        case .drag:
            return "→ dragged"
            
        case .move:
            if let x = ToolResultExtractor.int("x", from: result),
               let y = ToolResultExtractor.int("y", from: result) {
                return "→ moved to (\(x), \(y))"
            }
            return "→ moved"
            
        case .swipe:
            return "→ swiped"
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .click:
            let target = formatCompactSummary(arguments: arguments)
            if !target.isEmpty {
                return "Clicking \(target)..."
            }
            return "Clicking..."
            
        case .type:
            if let text = arguments["text"] as? String {
                return "Typing '\(truncate(text))'..."
            }
            return "Typing..."
            
        case .scroll:
            let direction = arguments["direction"] as? String ?? "down"
            return "Scrolling \(direction)..."
            
        case .hotkey, .press:
            let keys = formatCompactSummary(arguments: arguments)
            return "Pressing \(keys)..."
            
        case .drag:
            return "Dragging..."
            
        case .move:
            if let x = arguments["x"], let y = arguments["y"] {
                return "Moving to (\(x), \(y))..."
            }
            return "Moving..."
            
        case .swipe:
            return "Swiping..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}