//
//  SystemToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for system-related tools (shell, wait, etc.)
struct SystemToolFormatter: MacToolFormatterProtocol {
    let handledTools: Set<String> = ["shell", "wait", "list_spaces", "switch_space", "move_window_to_space", "list_screens"]
    
    func formatSummary(toolName: String, arguments: [String: Any]) -> String? {
        switch toolName {
        case "shell":
            return formatShellSummary(arguments)
        case "wait":
            return formatWaitSummary(arguments)
        case "list_spaces":
            return "List desktop spaces"
        case "switch_space":
            return formatSwitchSpaceSummary(arguments)
        case "move_window_to_space":
            return formatMoveWindowToSpaceSummary(arguments)
        case "list_screens":
            return "List displays"
        default:
            return nil
        }
    }
    
    func formatResult(toolName: String, result: [String: Any]) -> String? {
        switch toolName {
        case "shell":
            return formatShellResult(result)
        case "wait":
            return formatWaitResult(result)
        case "list_spaces":
            return formatListSpacesResult(result)
        case "switch_space":
            return formatSwitchSpaceResult(result)
        case "move_window_to_space":
            return formatMoveWindowResult(result)
        case "list_screens":
            return formatListScreensResult(result)
        default:
            return nil
        }
    }
    
    // MARK: - Shell
    
    private func formatShellSummary(_ args: [String: Any]) -> String {
        if let cmd = args["command"] as? String {
            // Truncate long commands
            let displayCmd = cmd.count > 50 
                ? String(cmd.prefix(50)) + "..."
                : cmd
            return "Run: \(displayCmd)"
        }
        return "Run shell command"
    }
    
    private func formatShellResult(_ result: [String: Any]) -> String? {
        if let exitCode = result["exitCode"] as? Int {
            if exitCode == 0 {
                if let output = result["output"] as? String, !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines)
                    return "→ \(lines.count) line\(lines.count == 1 ? "" : "s") output"
                }
                return "→ Command succeeded"
            } else {
                return "→ Exit code \(exitCode)"
            }
        }
        return nil
    }
    
    // MARK: - Wait
    
    private func formatWaitSummary(_ args: [String: Any]) -> String {
        if let seconds = args["seconds"] as? Double {
            if seconds < 1 {
                let ms = Int(seconds * 1000)
                return "Wait \(ms)ms"
            } else {
                return "Wait \(Int(seconds))s"
            }
        }
        return "Wait"
    }
    
    private func formatWaitResult(_ result: [String: Any]) -> String? {
        if let waited = result["waited"] as? Double {
            if waited < 1 {
                let ms = Int(waited * 1000)
                return "Waited \(ms)ms"
            } else {
                return "Waited \(Int(waited))s"
            }
        }
        return nil
    }
    
    // MARK: - Spaces
    
    private func formatSwitchSpaceSummary(_ args: [String: Any]) -> String {
        if let space = args["space"] as? Int {
            return "Switch to space \(space)"
        } else if let direction = args["direction"] as? String {
            return "Switch space \(direction)"
        }
        return "Switch space"
    }
    
    private func formatSwitchSpaceResult(_ result: [String: Any]) -> String? {
        if let space = result["currentSpace"] as? Int {
            return "→ Now on space \(space)"
        }
        return nil
    }
    
    private func formatMoveWindowToSpaceSummary(_ args: [String: Any]) -> String {
        var parts = ["Move"]
        
        if let app = args["app"] as? String {
            parts.append(app)
        } else {
            parts.append("window")
        }
        
        if let space = args["space"] as? Int {
            parts.append("to space \(space)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatMoveWindowResult(_ result: [String: Any]) -> String? {
        if let space = result["movedToSpace"] as? Int {
            return "→ Moved to space \(space)"
        }
        return nil
    }
    
    private func formatListSpacesResult(_ result: [String: Any]) -> String? {
        if let spaces = result["spaces"] as? [[String: Any]] {
            let activeCount = spaces.filter { $0["hasWindows"] as? Bool == true }.count
            return "→ \(spaces.count) spaces (\(activeCount) with windows)"
        }
        return nil
    }
    
    // MARK: - Screens
    
    private func formatListScreensResult(_ result: [String: Any]) -> String? {
        if let screens = result["screens"] as? [[String: Any]] {
            if screens.count == 1 {
                if let screen = screens.first,
                   let width = screen["width"] as? Int,
                   let height = screen["height"] as? Int {
                    return "→ 1 display (\(width)×\(height))"
                }
                return "→ 1 display"
            } else {
                return "→ \(screens.count) displays"
            }
        }
        return nil
    }
}