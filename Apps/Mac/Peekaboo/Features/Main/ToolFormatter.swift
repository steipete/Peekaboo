import Foundation
import PeekabooCore

/// Formats tool executions to match CLI's compact output format
@MainActor
struct ToolFormatter {
    
    /// Format keyboard shortcuts with proper symbols
    static func formatKeyboardShortcut(_ keys: String) -> String {
        keys.replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "command", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "option", with: "⌥")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "alt", with: "⌥")
            .replacingOccurrences(of: "control", with: "⌃")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "+", with: "")
    }
    
    /// Format duration with clock symbol
    static func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration = duration else { return "" }
        return " ⌖ " + PeekabooCore.formatDuration(duration)
    }
    
    /// Get compact summary of what the tool will do based on arguments
    static func compactToolSummary(toolName: String, arguments: String) -> String {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return toolName
        }
        
        switch toolName {
        case "see":
            var parts: [String] = []
            if let mode = args["mode"] as? String {
                parts.append(mode == "window" ? "active window" : mode)
            } else if let app = args["app"] as? String {
                parts.append(app)
            } else {
                parts.append("screen")
            }
            if args["analyze"] != nil {
                parts.append("and analyze")
            }
            return "Capture \(parts.joined(separator: " "))"
            
        case "screenshot":
            let target: String
            if let mode = args["mode"] as? String {
                target = mode == "window" ? "active window" : mode
            } else if let app = args["app"] as? String {
                target = app
            } else {
                target = "full screen"
            }
            return "Screenshot \(target)"
            
        case "window_capture":
            let target = (args["appName"] as? String) ?? "active window"
            return "Capture \(target)"
            
        case "click":
            if let target = args["target"] as? String {
                // Check if it's an element ID (like B7, O6, etc.) or text
                if target.count <= 3 && target.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    return "Click element \(target)"
                } else {
                    return "Click '\(target)'"
                }
            } else if let element = args["element"] as? String {
                return "Click element \(element)"
            } else if let x = args["x"], let y = args["y"] {
                return "Click at (\(x), \(y))"
            }
            return "Click"
            
        case "type":
            if let text = args["text"] as? String {
                return "Type '\(text)'"
            }
            return "Type text"
            
        case "scroll":
            if let direction = args["direction"] as? String {
                if let amount = args["amount"] as? Int {
                    return "Scroll \(direction) \(amount)px"
                }
                return "Scroll \(direction)"
            }
            return "Scroll"
            
        case "focus_window":
            let app = (args["appName"] as? String) ?? "active window"
            return "Focus \(app)"
            
        case "resize_window":
            var parts: [String] = ["Resize"]
            if let app = args["appName"] as? String {
                parts.append(app)
            }
            if let width = args["width"], let height = args["height"] {
                parts.append("to \(width)×\(height)")
            }
            return parts.joined(separator: " ")
            
        case "launch_app":
            let app = (args["appName"] as? String) ?? "application"
            return "Launch \(app)"
            
        case "hotkey":
            if let keys = args["keys"] as? String {
                let formatted = formatKeyboardShortcut(keys)
                return "Press \(formatted)"
            }
            return "Press hotkey"
            
        case "shell":
            var parts: [String] = ["Run"]
            if let command = args["command"] as? String {
                parts.append("'\(command)'")
            } else {
                parts.append("command")
            }
            
            // Only show timeout if different from default (30s)
            if let timeout = args["timeout"] as? Double, timeout != 30.0 {
                parts.append("(timeout: \(Int(timeout))s)")
            }
            
            return parts.joined(separator: " ")
            
        case "list":
            if let target = args["target"] as? String {
                switch target {
                case "apps": return "List running applications"
                case "windows":
                    if let app = args["appName"] as? String {
                        return "List windows for \(app)"
                    }
                    return "List all windows"
                case "elements":
                    if let type = args["type"] as? String {
                        return "List \(type) elements"
                    }
                    return "List UI elements"
                default: return "List \(target)"
                }
            }
            return "List items"
            
        case "menu":
            if let action = args["action"] as? String {
                if action == "click", let menuPath = args["menuPath"] as? [String] {
                    return "Click menu: \(menuPath.joined(separator: " → "))"
                }
                return "Menu \(action)"
            }
            return "Menu action"
            
        case "menu_click":
            if let menuPath = args["menuPath"] as? String {
                return "Click menu '\(menuPath)'"
            }
            return "Click menu item"
            
        case "list_windows":
            if let app = args["appName"] as? String {
                return "List windows for \(app)"
            }
            return "List all windows"
            
        case "find_element":
            if let text = args["text"] as? String {
                return "Find '\(text)'"
            } else if let elementId = args["elementId"] as? String {
                return "Find element \(elementId)"
            }
            return "Find UI element"
            
        case "list_apps":
            return "List running applications"
            
        case "list_elements":
            if let type = args["type"] as? String {
                return "List \(type) elements"
            }
            return "List UI elements"
            
        case "focused":
            return "Get focused element"
            
        case "list_menus":
            if let app = args["app"] as? String {
                return "List menus for \(app)"
            }
            return "List menu structure"
            
        case "dock_launch":
            if let app = args["appName"] as? String {
                return "Launch \(app) from dock"
            }
            return "Launch dock item"
            
        case "list_dock":
            return "List dock items"
            
        case "dialog_click":
            if let button = args["button"] as? String {
                return "Click dialog button '\(button)'"
            }
            return "Click dialog button"
            
        case "dialog_input":
            if let text = args["text"] as? String {
                return "Enter '\(text)' in dialog"
            }
            return "Enter text in dialog"
            
        default:
            return toolName.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    /// Get summary of tool result
    static func toolResultSummary(toolName: String, result: String?) -> String? {
        guard let result = result,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Handle wrapped results {"type": "object", "value": {...}}
        let actualResult: [String: Any]
        if json["type"] as? String == "object", let value = json["value"] as? [String: Any] {
            actualResult = value
        } else {
            actualResult = json
        }
        
        switch toolName {
        case "launch_app":
            var parts: [String] = ["Launched"]
            
            // Check for app name in various possible locations
            if let app = actualResult["app"] as? String {
                parts.append(app)
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                     let appName = appWrapper["value"] as? String {
                parts.append(appName)
            } else if let metadata = actualResult["metadata"] as? [String: Any],
                     let app = metadata["app"] as? String {
                parts.append(app)
            }
            
            // Add bundle ID if available
            if let bundleId = actualResult["bundleId"] as? String {
                parts.append("(\(bundleId))")
            }
            
            return parts.joined(separator: " ")
            
        case "click":
            var parts: [String] = []
            
            // Get click type
            var clickType = "Clicked"
            if let type = actualResult["type"] as? String {
                if type == "right_click" {
                    clickType = "Right-clicked"
                } else if type == "double_click" {
                    clickType = "Double-clicked"
                }
            }
            parts.append(clickType)
            
            // Get what was clicked
            if let element = actualResult["element"] as? String {
                if element.count <= 3 && element.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    parts.append("element \(element)")
                } else {
                    parts.append("'\(element)'")
                }
            } else if let target = actualResult["target"] as? String {
                parts.append("'\(target)'")
            } else if let coords = actualResult["coords"] as? String {
                parts.append("at \(coords)")
            } else if let x = actualResult["x"], let y = actualResult["y"] {
                parts.append("at (\(x), \(y))")
            }
            
            // Add app context if available
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }
            
            return parts.joined(separator: " ")
            
        case "list_apps":
            // Check for count value first (tool result format)
            if let countValue = actualResult["count"] as? [String: Any],
               let count = countValue["value"] as? String {
                return "Found \(count) apps"
            }
            // Check nested structure
            else if let data = actualResult["data"] as? [String: Any],
               let apps = data["applications"] as? [[String: Any]] {
                return "Found \(apps.count) apps"
            }
            // Fallback to direct structure
            else if let apps = actualResult["apps"] as? [[String: Any]] {
                return "Found \(apps.count) apps"
            }
            
        case "list_dock":
            // Check for totalCount directly in result
            if let totalCount = actualResult["totalCount"] as? String {
                return "Found \(totalCount) items"
            }
            // Check for wrapped totalCount
            else if let totalCountWrapper = actualResult["totalCount"] as? [String: Any],
                    let value = totalCountWrapper["value"] {
                return "Found \(value) items"
            }
            // Fallback to items array
            else if let items = actualResult["items"] as? [[String: Any]] {
                return "Found \(items.count) items"
            }
            
        case "see":
            var parts: [String] = ["Captured"]
            if let elementCounts = actualResult["elementCounts"] as? [String: Int] {
                let counts = elementCounts.compactMap { key, value in
                    value > 0 ? "\(value) \(key)" : nil
                }
                if !counts.isEmpty {
                    parts.append("with \(counts.joined(separator: ", "))")
                }
            }
            return parts.joined(separator: " ")
            
        case "type":
            if let typed = actualResult["typed"] as? String {
                return "Typed '\(typed)'"
            }
            
        case "hotkey":
            var parts: [String] = ["Pressed"]
            
            // Get the keys that were pressed
            if let keys = actualResult["keys"] as? String {
                let formatted = formatKeyboardShortcut(keys)
                parts.append(formatted)
            } else if let key = actualResult["key"] as? String {
                var keyParts: [String] = []
                if let modifiers = actualResult["modifiers"] as? String, !modifiers.isEmpty {
                    // Convert comma-separated modifiers to symbols
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
                parts.append(keyParts.joined(separator: ""))
            }
            
            // Add app context if available
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }
            
            return parts.joined(separator: " ")
            
        case "screenshot":
            var parts: [String] = ["Screenshot"]
            if let path = actualResult["path"] as? String {
                parts.append("saved to \(path)")
            }
            if let app = actualResult["app"] as? String {
                parts.append("of \(app)")
            }
            return parts.joined(separator: " ")
            
        case "window_capture":
            var parts: [String] = []
            if let captured = actualResult["captured"] as? Bool, captured {
                parts.append("Captured window")
                if let app = actualResult["app"] as? String {
                    parts.append("of \(app)")
                }
            }
            return parts.joined(separator: " ")
            
        case "shell":
            var parts: [String] = []
            
            // Check exit code
            if let exitCode = actualResult["exitCode"] as? Int {
                if exitCode == 0 {
                    parts.append("Command completed")
                } else {
                    parts.append("Command failed (exit code: \(exitCode))")
                }
            }
            
            // Add command if available
            if let command = actualResult["command"] as? String {
                let truncated = command.count > 50 ? String(command.prefix(50)) + "..." : command
                parts.append("- '\(truncated)'")
            }
            
            return parts.joined(separator: " ")
            
        case "scroll":
            var parts: [String] = ["Scrolled"]
            if let direction = actualResult["direction"] as? String {
                parts.append(direction)
            }
            if let amount = actualResult["amount"] as? Int {
                parts.append("\(amount) pixels")
            }
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }
            return parts.joined(separator: " ")
            
        case "menu_click":
            var parts: [String] = ["Clicked"]
            
            // Get the menu path
            if let menuPath = actualResult["menuPath"] as? String {
                parts.append("'\(menuPath)'")
            } else if let path = actualResult["path"] as? String {
                parts.append("'\(path)'")
            }
            
            // Add app if available
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }
            
            return parts.joined(separator: " ")
            
        default:
            // For other tools, check if there's a success message
            if let success = actualResult["success"] as? Bool, success {
                return "Completed successfully"
            }
        }
        
        return nil
    }
}