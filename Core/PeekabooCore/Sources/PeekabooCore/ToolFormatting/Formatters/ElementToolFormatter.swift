//
//  ElementToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for element query and search tools with comprehensive result formatting
public class ElementToolFormatter: BaseToolFormatter {
    
    public override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .findElement:
            if let text = arguments["text"] as? String {
                return "'\(truncate(text))'"
            } else if let elementId = arguments["elementId"] as? String {
                return "element \(elementId)"
            } else if let query = arguments["query"] as? String {
                return "'\(truncate(query))'"
            }
            return "element"
            
        case .listElements:
            var parts: [String] = []
            
            if let type = arguments["type"] as? String {
                parts.append("\(type) elements")
            } else {
                parts.append("UI elements")
            }
            
            // Add scope/app context
            if let app = arguments["app"] as? String {
                parts.append("in \(app)")
            } else if let window = arguments["window"] as? String {
                parts.append("in '\(window)'")
            }
            
            // Add filter info
            if let role = arguments["role"] as? String {
                parts.append("(role: \(role))")
            }
            
            return parts.joined(separator: " ")
            
        case .focused:
            if let app = arguments["app"] as? String {
                return "in \(app)"
            }
            return ""
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    public override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .findElement:
            return formatFindElementResult(result)
        case .listElements:
            return formatListElementsResult(result)
        case .focused:
            return formatFocusedElementResult(result)
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    // MARK: - Find Element Formatting
    
    private func formatFindElementResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Check if found
        let found = ToolResultExtractor.bool("found", from: result) ?? false
        
        if found {
            parts.append("→ Found")
            
            // Element text or label
            if let text = ToolResultExtractor.string("text", from: result) {
                let truncated = text.count > 40 ? String(text.prefix(40)) + "..." : text
                parts.append("\"\(truncated)\"")
            } else if let label = ToolResultExtractor.string("label", from: result) {
                parts.append("\"\(label)\"")
            }
            
            // Element type and role
            var typeInfo: [String] = []
            if let type = ToolResultExtractor.string("type", from: result) {
                typeInfo.append(type)
            }
            if let role = ToolResultExtractor.string("role", from: result) {
                typeInfo.append("role: \(role)")
            }
            if !typeInfo.isEmpty {
                parts.append("(\(typeInfo.joined(separator: ", ")))")
            }
            
            // Position and size
            if let frame = ToolResultExtractor.dictionary("frame", from: result) {
                if let x = frame["x"] as? Int,
                   let y = frame["y"] as? Int,
                   let width = frame["width"] as? Int,
                   let height = frame["height"] as? Int {
                    parts.append("[\(width)×\(height) at (\(x), \(y))]")
                }
            } else if let coords = ToolResultExtractor.coordinates(from: result) {
                parts.append("at (\(coords.x), \(coords.y))")
            }
            
            // State information
            var states: [String] = []
            if ToolResultExtractor.bool("enabled", from: result) == false {
                states.append("disabled")
            }
            if ToolResultExtractor.bool("focused", from: result) == true {
                states.append("focused")
            }
            if ToolResultExtractor.bool("selected", from: result) == true {
                states.append("selected")
            }
            if ToolResultExtractor.bool("visible", from: result) == true {
                states.append("visible")
            }
            if !states.isEmpty {
                parts.append("• \(states.joined(separator: ", "))")
            }
            
            // Hierarchy info
            if let depth = ToolResultExtractor.int("depth", from: result) {
                parts.append("depth: \(depth)")
            }
            
            // App context
            if let app = ToolResultExtractor.string("app", from: result) {
                parts.append("in \(app)")
            }
            
            // Match confidence
            if let confidence = ToolResultExtractor.double("confidence", from: result) {
                if confidence < 1.0 {
                    parts.append(String(format: "%.0f%% match", confidence * 100))
                }
            }
            
            // Alternative matches
            if let alternatives = ToolResultExtractor.int("alternativesCount", from: result), alternatives > 0 {
                parts.append("• \(alternatives) similar element\(alternatives == 1 ? "" : "s") also found")
            }
            
        } else {
            parts.append("→ Not found")
            
            // What was searched for
            if let query = ToolResultExtractor.string("query", from: result) {
                let truncated = query.count > 50 ? String(query.prefix(50)) + "..." : query
                parts.append("\"\(truncated)\"")
            } else if let text = ToolResultExtractor.string("text", from: result) {
                let truncated = text.count > 50 ? String(text.prefix(50)) + "..." : text
                parts.append("\"\(truncated)\"")
            }
            
            // Search scope
            if let searchScope = ToolResultExtractor.string("searchScope", from: result) {
                parts.append("in \(searchScope)")
            } else if let app = ToolResultExtractor.string("app", from: result) {
                parts.append("in \(app)")
            }
            
            // Suggestions
            if let suggestions: [String] = ToolResultExtractor.array("suggestions", from: result) {
                if !suggestions.isEmpty {
                    let suggestionList = suggestions.prefix(3).map { "\"\($0)\"" }.joined(separator: ", ")
                    parts.append("• Did you mean: \(suggestionList)?")
                }
            }
            
            // Similar elements found
            if let similarCount = ToolResultExtractor.int("similarElementsCount", from: result), similarCount > 0 {
                parts.append("• \(similarCount) similar element\(similarCount == 1 ? "" : "s") found")
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - List Elements Formatting
    
    private func formatListElementsResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Element count
        var elementCount = 0
        if let count = ToolResultExtractor.int("count", from: result) {
            elementCount = count
        } else if let elements: [[String: Any]] = ToolResultExtractor.array("elements", from: result) {
            elementCount = elements.count
        }
        
        // Type of elements
        if let type = ToolResultExtractor.string("type", from: result) {
            parts.append("→ \(elementCount) \(type) element\(elementCount == 1 ? "" : "s")")
        } else {
            parts.append("→ \(elementCount) element\(elementCount == 1 ? "" : "s")")
        }
        
        // Breakdown by type
        if let elements: [[String: Any]] = ToolResultExtractor.array("elements", from: result) {
            let typeGroups = Dictionary(grouping: elements) { element in
                (element["type"] as? String) ?? "unknown"
            }
            
            if typeGroups.count > 1 {
                let breakdown = typeGroups.map { type, items in
                    "\(type): \(items.count)"
                }.sorted().prefix(5).joined(separator: ", ")
                parts.append("[\(breakdown)]")
            }
            
            // State breakdown
            let enabledCount = elements.filter { ($0["enabled"] as? Bool) == true }.count
            let disabledCount = elements.filter { ($0["enabled"] as? Bool) == false }.count
            let visibleCount = elements.filter { ($0["visible"] as? Bool) == true }.count
            let focusedCount = elements.filter { ($0["focused"] as? Bool) == true }.count
            
            var states: [String] = []
            if enabledCount > 0 { states.append("\(enabledCount) enabled") }
            if disabledCount > 0 { states.append("\(disabledCount) disabled") }
            if visibleCount > 0 && visibleCount != elementCount { states.append("\(visibleCount) visible") }
            if focusedCount > 0 { states.append("\(focusedCount) focused") }
            
            if !states.isEmpty {
                parts.append("(\(states.joined(separator: ", ")))")
            }
            
            // Interactive elements
            let clickableCount = elements.filter { 
                ($0["clickable"] as? Bool) == true || 
                ($0["type"] as? String)?.lowercased().contains("button") == true 
            }.count
            let editableCount = elements.filter { 
                ($0["editable"] as? Bool) == true || 
                ($0["type"] as? String)?.lowercased().contains("field") == true 
            }.count
            
            if clickableCount > 0 || editableCount > 0 {
                var interactive: [String] = []
                if clickableCount > 0 { interactive.append("\(clickableCount) clickable") }
                if editableCount > 0 { interactive.append("\(editableCount) editable") }
                parts.append("• \(interactive.joined(separator: ", "))")
            }
            
            // Sample elements (first 3)
            if elementCount > 0 && elementCount <= 5 {
                let samples = elements.prefix(3).compactMap { element -> String? in
                    if let text = element["text"] as? String, !text.isEmpty {
                        let truncated = text.count > 25 ? String(text.prefix(25)) + "..." : text
                        return "\"\(truncated)\""
                    } else if let type = element["type"] as? String {
                        return type
                    }
                    return nil
                }
                
                if !samples.isEmpty {
                    parts.append("• \(samples.joined(separator: ", "))")
                }
            }
        }
        
        // Filter information
        if let filter = ToolResultExtractor.string("filter", from: result) {
            parts.append("filtered by: \(filter)")
        }
        
        // App/window context
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("in \(app)")
        } else if let window = ToolResultExtractor.string("window", from: result) {
            parts.append("in window: \"\(truncate(window))\"")
        }
        
        // Performance info
        if let scanTime = ToolResultExtractor.double("scanTime", from: result) {
            if scanTime > 1.0 {
                parts.append(String(format: "• Scan time: %.1fs", scanTime))
            }
        }
        
        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }
    
    // MARK: - Focused Element Formatting
    
    private func formatFocusedElementResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Focused:")
        
        // Element details
        if let label = ToolResultExtractor.string("label", from: result) {
            parts.append("\"\(label)\"")
        } else if let text = ToolResultExtractor.string("text", from: result) {
            let truncated = text.count > 40 ? String(text.prefix(40)) + "..." : text
            parts.append("\"\(truncated)\"")
        } else if let placeholder = ToolResultExtractor.string("placeholder", from: result) {
            parts.append("placeholder: \"\(placeholder)\"")
        }
        
        // Element type
        if let elementType = ToolResultExtractor.string("type", from: result) {
            if let role = ToolResultExtractor.string("role", from: result) {
                parts.append("(\(elementType), role: \(role))")
            } else {
                parts.append("(\(elementType))")
            }
        }
        
        // Value/content
        if let value = ToolResultExtractor.string("value", from: result), !value.isEmpty {
            let truncated = value.count > 30 ? String(value.prefix(30)) + "..." : value
            parts.append("value: \"\(truncated)\"")
        }
        
        // State
        var states: [String] = []
        if ToolResultExtractor.bool("enabled", from: result) == false {
            states.append("disabled")
        }
        if ToolResultExtractor.bool("editable", from: result) == true {
            states.append("editable")
        }
        if ToolResultExtractor.bool("selected", from: result) == true {
            states.append("selected")
        }
        if ToolResultExtractor.bool("required", from: result) == true {
            states.append("required")
        }
        
        if !states.isEmpty {
            parts.append("[\(states.joined(separator: ", "))]")
        }
        
        // Position
        if let frame = ToolResultExtractor.dictionary("frame", from: result) {
            if let x = frame["x"] as? Int,
               let y = frame["y"] as? Int,
               let width = frame["width"] as? Int,
               let height = frame["height"] as? Int {
                parts.append("• \(width)×\(height) at (\(x), \(y))")
            }
        }
        
        // App context
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("in \(app)")
        }
        
        // Parent information
        if let parent = ToolResultExtractor.string("parent", from: result) {
            parts.append("• Parent: \(parent)")
        }
        
        // No focus
        if ToolResultExtractor.bool("hasFocus", from: result) == false {
            parts = ["→ No element has focus"]
            if let app = ToolResultExtractor.string("app", from: result) {
                parts.append("in \(app)")
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    public override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .findElement:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "🔍 Searching for \(summary)..."
            }
            return "🔍 Searching for element..."
            
        case .listElements:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "📋 Scanning \(summary)..."
            }
            return "📋 Scanning UI elements..."
            
        case .focused:
            if let app = arguments["app"] as? String {
                return "🎯 Checking focused element in \(app)..."
            }
            return "🎯 Checking focused element..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}