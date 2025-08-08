//
//  SystemToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for system tools (shell, wait, spaces, etc.)
public class SystemToolFormatter: BaseToolFormatter {
    
    public override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .shell:
            var parts: [String] = []
            if let command = arguments["command"] as? String {
                parts.append("'\(command)'")
            } else {
                parts.append("command")
            }
            
            // Only show timeout if different from default (30s)
            if let timeout = arguments["timeout"] as? Double, timeout != 30.0 {
                parts.append("(timeout: \(Int(timeout))s)")
            }
            
            return parts.joined(separator: " ")
            
        case .wait:
            var parts: [String] = []
            
            if let seconds = arguments["seconds"] as? Double {
                parts.append("\(seconds)s")
            } else if let seconds = arguments["seconds"] as? Int {
                parts.append("\(seconds)s")
            } else if let time = arguments["time"] as? Double {
                parts.append("\(time)s")
            } else {
                parts.append("1s")
            }
            
            // Add wait reason if available
            if let reason = arguments["reason"] as? String {
                parts.append("for \(reason)")
            } else if let waitFor = arguments["for"] as? String {
                parts.append("for \(waitFor)")
            }
            
            return parts.joined(separator: " ")
            
        case .listSpaces:
            return ""
            
        case .switchSpace:
            if let to = arguments["to"] as? Int {
                return "to space \(to)"
            }
            return ""
            
        case .moveWindowToSpace:
            var parts: [String] = []
            if let app = arguments["app"] as? String {
                parts.append(app)
            }
            if let to = arguments["to"] as? Int {
                parts.append("to space \(to)")
            }
            return parts.joined(separator: " ")
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    public override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .shell:
            var parts: [String] = []
            
            // Check exit code
            if let exitCode = ToolResultExtractor.int("exitCode", from: result) {
                if exitCode == 0 {
                    parts.append("→ success")
                } else {
                    parts.append("→ exit code \(exitCode)")
                }
            }
            
            // Add execution time if available
            if let duration = ToolResultExtractor.int("duration", from: result) ?? 
                             (result["duration"] as? Double).map({ Int($0) }) {
                parts.append("(\(formatDuration(TimeInterval(duration))))")
            }
            
            // Add output preview if available and command succeeded
            if let output = ToolResultExtractor.string("output", from: result),
               !output.isEmpty,
               let exitCode = ToolResultExtractor.int("exitCode", from: result),
               exitCode == 0 {
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                if !lines.isEmpty {
                    let preview = truncate(lines.first!)
                    parts.append("- \(preview)")
                }
            }
            
            return parts.joined(separator: " ")
            
        case .wait:
            if let seconds = ToolResultExtractor.int("seconds", from: result) ??
                           (result["seconds"] as? Double).map({ Int($0) }) {
                return "→ waited \(seconds)s"
            }
            return "→ waited"
            
        case .listSpaces:
            if let spaces = ToolResultExtractor.array("spaces", from: result) as [[String: Any]]? {
                return "→ \(spaces.count) spaces"
            } else if let count = ToolResultExtractor.int("count", from: result) {
                return "→ \(count) spaces"
            }
            return "→ listed"
            
        case .switchSpace:
            if let to = ToolResultExtractor.int("to", from: result) ?? ToolResultExtractor.int("space", from: result) {
                return "→ switched to space \(to)"
            }
            return "→ switched"
            
        case .moveWindowToSpace:
            var parts: [String] = ["→ moved"]
            
            if let app = ToolResultExtractor.string("app", from: result) {
                parts.append(app)
            }
            
            if let to = ToolResultExtractor.int("to", from: result) ?? ToolResultExtractor.int("space", from: result) {
                parts.append("to space \(to)")
            }
            
            if let followed = ToolResultExtractor.bool("followed", from: result), followed {
                parts.append("(followed)")
            }
            
            return parts.joined(separator: " ")
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    public override func formatStarting(arguments: [String: Any]) -> String
        switch toolType {
        case .shell:
            if let command = arguments["command"] as? String {
                return "Running '\(truncate(command, maxLength: 50))'..."
            }
            return "Running command..."
            
        case .wait:
            let summary = formatCompactSummary(arguments: arguments)
            return "Waiting \(summary)..."
            
        case .listSpaces:
            return "Listing Mission Control spaces..."
            
        case .switchSpace:
            if let to = arguments["to"] as? Int {
                return "Switching to space \(to)..."
            }
            return "Switching space..."
            
        case .moveWindowToSpace:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Moving \(summary)..."
            }
            return "Moving window to space..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
    
    public override func formatError(error: String, result: [String: Any]) -> String
        if toolType == .shell {
            // Show command output for shell errors
            var parts: [String] = []
            
            if let output = ToolResultExtractor.string("output", from: result), !output.isEmpty {
                parts.append("Output: \(truncate(output.trimmingCharacters(in: .whitespacesAndNewlines)))")
            }
            
            let exitCode = ToolResultExtractor.int("exitCode", from: result) ?? 0
            let errorMsg = error.trimmingCharacters(in: .whitespacesAndNewlines)
            parts.append("Error (Exit code: \(exitCode)): \(errorMsg)")
            
            return parts.joined(separator: "\n   ")
        }
        
        return super.formatError(error: error, result: result)
    }
}