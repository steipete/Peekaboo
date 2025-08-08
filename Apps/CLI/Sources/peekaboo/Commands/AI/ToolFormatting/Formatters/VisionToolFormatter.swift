//
//  VisionToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for vision and screenshot tools
class VisionToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .see:
            var parts: [String] = []
            if let mode = arguments["mode"] as? String {
                parts.append(mode == "window" ? "active window" : mode)
            } else if let app = arguments["app"] as? String {
                parts.append(app)
            } else {
                parts.append("screen")
            }
            if arguments["analyze"] != nil {
                parts.append("and analyze")
            }
            return parts.joined(separator: " ")
            
        case .screenshot:
            if let mode = arguments["mode"] as? String {
                return mode == "window" ? "active window" : mode
            } else if let app = arguments["app"] as? String {
                return app
            }
            return "full screen"
            
        case .windowCapture:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"
            
        case .analyze:
            if let path = arguments["path"] as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            }
            return ""
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .see:
            var parts: [String] = ["→"]
            
            // Get app/mode context
            if let app = ToolResultExtractor.string("app", from: result), app != "entire screen" {
                parts.append(app)
            } else if let mode = ToolResultExtractor.string("mode", from: result) {
                if mode == "window" {
                    if let windowTitle = ToolResultExtractor.string("windowTitle", from: result) {
                        parts.append(windowTitle)
                    } else {
                        parts.append("active window")
                    }
                } else {
                    parts.append(mode)
                }
            } else {
                parts.append("screen")
            }
            
            // Add element counts if available
            var elementInfo: [String] = []
            
            if let dialogDetected = ToolResultExtractor.bool("dialogDetected", from: result), dialogDetected {
                elementInfo.append("dialog detected")
            }
            
            if let elementCount = ToolResultExtractor.int("elementCount", from: result) {
                elementInfo.append("\(elementCount) elements")
            } else if let resultText = ToolResultExtractor.string("result", from: result) {
                // Extract counts from result text
                let patterns = [
                    (#"(\d+) button"#, "buttons"),
                    (#"(\d+) text"#, "text fields"),
                    (#"(\d+) link"#, "links"),
                    (#"(\d+) image"#, "images"),
                    (#"(\d+) static text"#, "labels")
                ]
                
                for (pattern, label) in patterns {
                    if let range = resultText.range(of: pattern, options: .regularExpression) {
                        let match = String(resultText[range])
                        if let numberRange = match.range(of: #"\d+"#, options: .regularExpression) {
                            let count = String(match[numberRange])
                            elementInfo.append("\(count) \(label)")
                        }
                    }
                }
            }
            
            if !elementInfo.isEmpty {
                parts.append("(\(elementInfo.joined(separator: ", ")))")
            }
            
            return parts.joined(separator: " ")
            
        case .screenshot, .windowCapture:
            if let path = ToolResultExtractor.string("path", from: result) {
                return "→ saved \(URL(fileURLWithPath: path).lastPathComponent)"
            }
            return "→ saved screenshot"
            
        case .analyze:
            if let analysis = ToolResultExtractor.string("analysis", from: result) {
                let preview = truncate(analysis, maxLength: 50)
                return "→ \(preview)"
            }
            return "→ analyzed"
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .see:
            let target = formatCompactSummary(arguments: arguments)
            return "Capturing \(target)..."
            
        case .screenshot:
            let target = formatCompactSummary(arguments: arguments)
            return "Taking screenshot of \(target)..."
            
        case .windowCapture:
            let app = arguments["appName"] as? String ?? "active window"
            return "Capturing \(app) window..."
            
        case .analyze:
            if let path = arguments["path"] as? String {
                return "Analyzing \(URL(fileURLWithPath: path).lastPathComponent)..."
            }
            return "Analyzing image..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}