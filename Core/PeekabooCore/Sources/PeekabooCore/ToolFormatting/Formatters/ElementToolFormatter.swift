//
//  ElementToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for element query and search tools
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
            var parts: [String] = []
            
            // Check if found
            let found = ToolResultExtractor.bool("found", from: result) ?? false
            
            if found {
                parts.append("→ found")
                
                // Get element details
                if let element = ToolResultExtractor.string("element", from: result) {
                    let truncated = truncate(element)
                    parts.append("'\(truncated)'")
                } else if let text = ToolResultExtractor.string("text", from: result) {
                    let truncated = truncate(text)
                    parts.append("'\(truncated)'")
                }
                
                // Add element type if available
                if let type = ToolResultExtractor.string("type", from: result) {
                    parts.append("(\(type))")
                }
                
                // Add location if available
                if let elementId = ToolResultExtractor.string("elementId", from: result) {
                    parts.append("as \(elementId)")
                }
                
                // Add coordinates if available
                if let coords = ToolResultExtractor.coordinates(from: result) {
                    parts.append("at (\(coords.x), \(coords.y))")
                }
                
                // Add app context
                if let app = ToolResultExtractor.string("app", from: result) {
                    parts.append("in \(app)")
                }
            } else {
                parts.append("→ not found")
                
                // Add what was searched for
                if let query = ToolResultExtractor.string("query", from: result) {
                    let truncated = truncate(query)
                    parts.append("'\(truncated)'")
                } else if let text = ToolResultExtractor.string("text", from: result) {
                    let truncated = truncate(text)
                    parts.append("'\(truncated)'")
                }
                
                // Add search scope if available
                if let app = ToolResultExtractor.string("app", from: result) {
                    parts.append("in \(app)")
                }
            }
            
            return parts.joined(separator: " ")
            
        case .listElements:
            if let count = ToolResultExtractor.int("count", from: result) {
                if let type = ToolResultExtractor.string("type", from: result) {
                    return "→ \(count) \(type) elements"
                }
                return "→ \(count) elements"
            } else if let elements = ToolResultExtractor.array("elements", from: result) as [[String: Any]]? {
                if let type = ToolResultExtractor.string("type", from: result) {
                    return "→ \(elements.count) \(type) elements"
                }
                return "→ \(elements.count) elements"
            }
            return "→ listed"
            
        case .focused:
            if let label = ToolResultExtractor.string("label", from: result) {
                if let app = ToolResultExtractor.string("app", from: result) {
                    return "→ '\(label)' field in \(app)"
                }
                return "→ '\(label)' field"
            } else if let elementType = ToolResultExtractor.string("type", from: result) {
                if let app = ToolResultExtractor.string("app", from: result) {
                    return "→ \(elementType) in \(app)"
                }
                return "→ \(elementType)"
            }
            return "→ focused element"
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    public override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .findElement:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Finding \(summary)..."
            }
            return "Finding element..."
            
        case .listElements:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Listing \(summary)..."
            }
            return "Listing elements..."
            
        case .focused:
            if let app = arguments["app"] as? String {
                return "Getting focused element in \(app)..."
            }
            return "Getting focused element..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}