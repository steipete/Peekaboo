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
        guard let duration else { return "" }
        return " ⌖ " + PeekabooCore.formatDuration(duration)
    }

    /// Get compact summary of what the tool will do based on arguments
    static func compactToolSummary(toolName: String, arguments: String) -> String {
        guard let tool = PeekabooTool(from: toolName) else {
            return toolName.replacingOccurrences(of: "_", with: " ").capitalized
        }

        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return toolName
        }

        switch tool {
        case .see:
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

        case .screenshot:
            let target: String = if let mode = args["mode"] as? String {
                mode == "window" ? "active window" : mode
            } else if let app = args["app"] as? String {
                app
            } else {
                "full screen"
            }
            return "Screenshot \(target)"

        case .windowCapture:
            let target = (args["appName"] as? String) ?? "active window"
            return "Capture \(target)"

        case .click:
            var parts = ["Click"]
            
            // Check for coordinates first (most specific)
            if let coords = args["coords"] as? String {
                parts.append("at \(coords)")
            } else if let x = args["x"], let y = args["y"] {
                parts.append("at (\(x), \(y))")
            }
            
            // Then add element/target info
            if let target = args["target"] as? String {
                // Check if it's an element ID (like B7, O6, etc.) or text
                if target.count <= 3, target.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    parts.append("element \(target)")
                } else {
                    parts.append("'\(target)'")
                }
            } else if let element = args["element"] as? String {
                parts.append("element \(element)")
            } else if let on = args["on"] as? String {
                // Handle the 'on' parameter from newer see/click commands
                parts.append("element \(on)")
            }
            
            return parts.joined(separator: " ")

        case .type:
            var parts = ["Type"]
            
            if let text = args["text"] as? String {
                let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                parts.append("'\(truncated)'")
            }
            
            // Add element context
            if let on = args["on"] as? String {
                parts.append("in element \(on)")
            }
            
            // Add modifiers
            if let clear = args["clear"] as? Bool, clear {
                parts.append("(clear first)")
            }
            if let pressReturn = args["press_return"] as? Bool, pressReturn {
                parts.append("(+ return)")
            }
            
            return parts.joined(separator: " ")

        case .scroll:
            var parts = ["Scroll"]
            
            if let direction = args["direction"] as? String {
                parts.append(direction)
            }
            
            if let amount = args["amount"] as? Int {
                parts.append("\(amount) line\(amount == 1 ? "" : "s")")
            }
            
            if let on = args["on"] as? String {
                parts.append("on element \(on)")
            }
            
            if let smooth = args["smooth"] as? Bool, smooth {
                parts.append("(smooth)")
            }
            
            return parts.joined(separator: " ")

        case .focusWindow:
            let app = (args["appName"] as? String) ?? "active window"
            return "Focus \(app)"

        case .resizeWindow:
            var parts = ["Resize"]
            if let app = args["appName"] as? String {
                parts.append(app)
            }
            if let width = args["width"], let height = args["height"] {
                parts.append("to \(width)×\(height)")
            }
            return parts.joined(separator: " ")

        case .launchApp:
            let app = (args["appName"] as? String) ?? "application"
            return "Launch \(app)"

        case .hotkey:
            if let keys = args["keys"] as? String {
                let formatted = self.formatKeyboardShortcut(keys)
                return "Press \(formatted)"
            }
            return "Press hotkey"

        case .shell:
            var parts = ["Run"]
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

        case .menuClick:
            if let menuPath = args["menuPath"] as? String {
                return "Click menu '\(menuPath)'"
            }
            return "Click menu item"

        case .listWindows:
            if let app = args["appName"] as? String {
                return "List windows for \(app)"
            }
            return "List all windows"

        case .findElement:
            if let text = args["text"] as? String {
                let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                return "Find '\(truncated)'"
            } else if let elementId = args["elementId"] as? String {
                return "Find element \(elementId)"
            } else if let query = args["query"] as? String {
                let truncated = query.count > 30 ? String(query.prefix(30)) + "..." : query
                return "Find '\(truncated)'"
            }
            return "Find UI element"

        case .listApps:
            return "List running applications"

        case .listElements:
            if let type = args["type"] as? String {
                return "List \(type) elements"
            }
            return "List UI elements"

        case .focused:
            return "Get focused element"

        case .listMenus:
            if let app = args["app"] as? String {
                return "List menus for \(app)"
            } else if let appName = args["appName"] as? String {
                return "List menus for \(appName)"
            }
            return "List menu structure"

        case .listDock:
            return "List dock items"

        case .dialogClick:
            var parts = ["Click"]
            if let button = args["button"] as? String {
                parts.append("'\(button)'")
            } else {
                parts.append("dialog button")
            }
            if let window = args["window"] as? String {
                parts.append("in \(window)")
            }
            return parts.joined(separator: " ")

        case .dialogInput:
            var parts: [String] = []
            if let text = args["text"] as? String {
                let truncated = text.count > 20 ? String(text.prefix(20)) + "..." : text
                parts.append("Enter '\(truncated)'")
            } else {
                parts.append("Enter text")
            }
            if let field = args["field"] as? String {
                parts.append("in '\(field)'")
            }
            return parts.joined(separator: " ")

        case .listSpaces:
            return "List Mission Control spaces"

        case .switchSpace:
            if let to = args["to"] as? Int {
                return "Switch to space \(to)"
            }
            return "Switch space"

        case .moveWindowToSpace:
            var parts = ["Move"]
            if let app = args["app"] as? String {
                parts.append(app)
            }
            if let to = args["to"] as? Int {
                parts.append("to space \(to)")
            }
            return parts.joined(separator: " ")

        case .wait:
            if let seconds = args["seconds"] as? Double {
                return "Wait \(seconds)s"
            } else if let seconds = args["seconds"] as? Int {
                return "Wait \(seconds)s"
            }
            return "Wait 1s"

        case .dockLaunch:
            if let app = args["appName"] as? String {
                return "Launch \(app) from dock"
            } else if let app = args["app"] as? String {
                return "Launch \(app) from dock"
            }
            return "Launch dock item"

        case .taskCompleted:
            return "Task completed"

        case .needMoreInformation:
            return "Need more information"

        case .drag:
            var parts = ["Drag"]
            if let from = args["from"] as? String {
                parts.append("from \(from)")
            } else if let fromCoords = args["from_coords"] as? String {
                parts.append("from \(fromCoords)")
            }
            if let to = args["to"] as? String {
                parts.append("to \(to)")
            } else if let toCoords = args["to_coords"] as? String {
                parts.append("to \(toCoords)")
            }
            return parts.joined(separator: " ")

        case .swipe:
            var parts = ["Swipe"]
            if let from = args["from"] as? String {
                parts.append("from \(from)")
            }
            if let to = args["to"] as? String {
                parts.append("to \(to)")
            }
            if let duration = args["duration"] as? Int {
                parts.append("(\(duration)ms)")
            }
            return parts.joined(separator: " ")
        }
    }

    /// Get summary of tool result
    static func toolResultSummary(toolName: String, result: String?) -> String? {
        guard let tool = PeekabooTool(from: toolName) else {
            return nil
        }

        guard let result,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        // Handle wrapped results {"type": "object", "value": {...}}
        let actualResult: [String: Any] = if json["type"] as? String == "object",
                                             let value = json["value"] as? [String: Any]
        {
            value
        } else {
            json
        }

        switch tool {
        case .launchApp:
            var parts = ["Launched"]

            // Check for app name in various possible locations
            if let app = actualResult["app"] as? String {
                parts.append(app)
            } else if let appWrapper = actualResult["app"] as? [String: Any],
                      let appName = appWrapper["value"] as? String
            {
                parts.append(appName)
            } else if let metadata = actualResult["metadata"] as? [String: Any],
                      let app = metadata["app"] as? String
            {
                parts.append(app)
            }

            // Add bundle ID if available
            if let bundleId = actualResult["bundleId"] as? String {
                parts.append("(\(bundleId))")
            }

            return parts.joined(separator: " ")

        case .click:
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

            // Get what was clicked - prioritize showing coordinates
            var hasCoordinates = false
            if let coords = actualResult["coords"] as? String {
                parts.append("at \(coords)")
                hasCoordinates = true
            } else if let x = actualResult["x"], let y = actualResult["y"] {
                parts.append("at (\(x), \(y))")
                hasCoordinates = true
            }
            
            // Add element/target info if available
            if let element = actualResult["element"] as? String {
                if element.count <= 3, element.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    parts.append("element \(element)")
                } else {
                    parts.append("'\(element)'")
                }
            } else if let target = actualResult["target"] as? String, !hasCoordinates {
                // Only show target if we don't already have coordinates
                parts.append("'\(target)'")
            }

            // Add app context if available
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }

            return parts.joined(separator: " ")

        case .listApps:
            var appCount: Int?
            
            // Check for count value first (tool result format)
            if let countValue = actualResult["count"] as? [String: Any],
               let count = countValue["value"] as? String,
               let intCount = Int(count) {
                appCount = intCount
            }
            // Direct count field
            else if let count = actualResult["count"] as? Int {
                appCount = count
            }
            // Check nested structure
            else if let data = actualResult["data"] as? [String: Any],
                    let apps = data["applications"] as? [[String: Any]] {
                appCount = apps.count
            }
            // Fallback to direct structure
            else if let apps = actualResult["apps"] as? [[String: Any]] {
                appCount = apps.count
            }
            // Check for applications array directly
            else if let apps = actualResult["applications"] as? [[String: Any]] {
                appCount = apps.count
            }
            
            if let count = appCount {
                return "Found \(count) running app\(count == 1 ? "" : "s")"
            }
            return "Listed applications"

        case .listDock:
            // Check for totalCount directly in result
            if let totalCount = actualResult["totalCount"] as? String {
                return "Found \(totalCount) items"
            }
            // Check for wrapped totalCount
            else if let totalCountWrapper = actualResult["totalCount"] as? [String: Any],
                    let value = totalCountWrapper["value"]
            {
                return "Found \(value) items"
            }
            // Fallback to items array
            else if let items = actualResult["items"] as? [[String: Any]] {
                return "Found \(items.count) items"
            }

        case .see:
            var parts = ["Captured"]
            
            // Add app context if available
            if let app = actualResult["app"] as? String {
                parts.append(app)
            } else if let appTarget = actualResult["app_target"] as? String {
                parts.append(appTarget)
            }
            
            // Add element counts if available
            if let elementCounts = actualResult["elementCounts"] as? [String: Int] {
                let counts = elementCounts.compactMap { key, value in
                    value > 0 ? "\(value) \(key)" : nil
                }
                if !counts.isEmpty {
                    parts.append("with \(counts.joined(separator: ", "))")
                }
            }
            
            // Add session info if available
            if let sessionId = actualResult["session"] as? String {
                parts.append("(session: \(String(sessionId.prefix(8)))...)")
            }
            
            return parts.joined(separator: " ")

        case .type:
            var parts = ["Typed"]
            
            if let typed = actualResult["typed"] as? String {
                parts.append("'\(typed)'")
            } else if let text = actualResult["text"] as? String {
                parts.append("'\(text)'")
            }
            
            // Add element context if available
            if let element = actualResult["element"] as? String {
                parts.append("in element \(element)")
            } else if let on = actualResult["on"] as? String {
                parts.append("in element \(on)")
            }
            
            // Add clear/return info if available
            if let cleared = actualResult["cleared"] as? Bool, cleared {
                parts.append("(cleared field)")
            }
            if let pressedReturn = actualResult["pressedReturn"] as? Bool, pressedReturn {
                parts.append("(pressed return)")
            }
            
            return parts.joined(separator: " ")

        case .hotkey:
            var parts = ["Pressed"]

            // Get the keys that were pressed
            if let keys = actualResult["keys"] as? String {
                let formatted = self.formatKeyboardShortcut(keys)
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
                parts.append(keyParts.joined())
            }

            // Add app context if available
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }

            return parts.joined(separator: " ")

        case .screenshot:
            var parts = ["Screenshot"]
            if let path = actualResult["path"] as? String {
                parts.append("saved to \(path)")
            }
            if let app = actualResult["app"] as? String {
                parts.append("of \(app)")
            }
            return parts.joined(separator: " ")

        case .windowCapture:
            var parts: [String] = []
            if let captured = actualResult["captured"] as? Bool, captured {
                parts.append("Captured window")
                if let app = actualResult["app"] as? String {
                    parts.append("of \(app)")
                }
            }
            return parts.joined(separator: " ")

        case .shell:
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

        case .scroll:
            var parts = ["Scrolled"]
            
            // Direction
            if let direction = actualResult["direction"] as? String {
                parts.append(direction)
            }
            
            // Amount with proper units
            if let amount = actualResult["amount"] as? Int {
                parts.append("\(amount) line\(amount == 1 ? "" : "s")")
            } else if let pixels = actualResult["pixels"] as? Int {
                parts.append("\(pixels) pixel\(pixels == 1 ? "" : "s")")
            }
            
            // Element context
            if let element = actualResult["element"] as? String {
                parts.append("on element \(element)")
            } else if let on = actualResult["on"] as? String {
                parts.append("on element \(on)")
            }
            
            // App context
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }
            
            // Smooth scrolling indicator
            if let smooth = actualResult["smooth"] as? Bool, smooth {
                parts.append("(smooth)")
            }
            
            return parts.joined(separator: " ")

        case .menuClick:
            var parts = ["Clicked"]

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

        case .dialogClick:
            var parts = ["Clicked"]

            if let button = actualResult["button"] as? String {
                parts.append("'\(button)'")
            }

            if let window = actualResult["window"] as? String {
                parts.append("in \(window)")
            }

            return parts.joined(separator: " ")

        case .dialogInput:
            var parts = ["Entered"]

            if let text = actualResult["text"] as? String {
                let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                parts.append("'\(truncated)'")
            }

            if let field = actualResult["field"] as? String {
                parts.append("in \(field)")
            }

            return parts.joined(separator: " ")

        case .findElement:
            var parts: [String] = []

            // Check if found
            var found = false
            if let f = actualResult["found"] as? Bool {
                found = f
            } else if let foundWrapper = actualResult["found"] as? [String: Any],
                      let foundValue = foundWrapper["value"] as? Bool
            {
                found = foundValue
            }

            if found {
                parts.append("Found")

                // Get element details
                if let element = actualResult["element"] as? String {
                    parts.append("'\(element)'")
                } else if let elementWrapper = actualResult["element"] as? [String: Any],
                          let elementValue = elementWrapper["value"] as? String
                {
                    parts.append("'\(elementValue)'")
                } else if let text = actualResult["text"] as? String {
                    parts.append("'\(text)'")
                }

                // Add element type if available
                if let type = actualResult["type"] as? String {
                    parts.append("(\(type))")
                }

                // Add location if available
                if let elementId = actualResult["elementId"] as? String {
                    parts.append("as \(elementId)")
                }
            } else {
                parts.append("Not found")

                // Add what was searched for
                if let query = actualResult["query"] as? String {
                    parts.append("'\(query)'")
                } else if let text = actualResult["text"] as? String {
                    parts.append("'\(text)'")
                }
            }

            return parts.joined(separator: " ")

        case .focused:
            if let label = actualResult["label"] as? String {
                if let app = actualResult["app"] as? String {
                    return "'\(label)' field in \(app)"
                }
                return "'\(label)' field"
            } else if let elementType = actualResult["type"] as? String {
                if let app = actualResult["app"] as? String {
                    return "\(elementType) in \(app)"
                }
                return elementType
            }
            return "Focused element"

        case .resizeWindow:
            var parts = ["Resized"]

            if let app = actualResult["app"] as? String {
                parts.append(app)
            }

            if let width = actualResult["width"], let height = actualResult["height"] {
                parts.append("to \(width)×\(height)")
            }

            return parts.joined(separator: " ")

        case .focusWindow:
            var parts = ["Focused"]

            if let app = actualResult["app"] as? String {
                parts.append(app)
            } else if let appName = actualResult["appName"] as? String {
                parts.append(appName)
            }

            if let title = actualResult["windowTitle"] as? String {
                parts.append("- \(title)")
            }

            return parts.joined(separator: " ")

        case .listWindows:
            // Check for count in various formats
            var windowCount: Int?
            
            // Direct count field
            if let count = actualResult["count"] as? Int {
                windowCount = count
            }
            // Wrapped count field
            else if let countWrapper = actualResult["count"] as? [String: Any],
                    let value = countWrapper["value"] as? Int {
                windowCount = value
            }
            // Count from windows array
            else if let windows = actualResult["windows"] as? [[String: Any]] {
                windowCount = windows.count
            }
            // Count from data.windows array
            else if let data = actualResult["data"] as? [String: Any],
                    let windows = data["windows"] as? [[String: Any]] {
                windowCount = windows.count
            }
            
            if let count = windowCount {
                if let app = actualResult["app"] as? String {
                    return "Found \(count) window\(count == 1 ? "" : "s") for \(app)"
                } else if let appName = actualResult["appName"] as? String {
                    return "Found \(count) window\(count == 1 ? "" : "s") for \(appName)"
                }
                return "Found \(count) window\(count == 1 ? "" : "s")"
            }
            
            return "Listed windows"

        case .listElements:
            if let count = actualResult["count"] as? Int {
                if let type = actualResult["type"] as? String {
                    return "Found \(count) \(type) elements"
                }
                return "Found \(count) elements"
            } else if let elements = actualResult["elements"] as? [[String: Any]] {
                if let type = actualResult["type"] as? String {
                    return "Found \(elements.count) \(type) elements"
                }
                return "Found \(elements.count) elements"
            }
            return "Listed elements"

        case .listMenus:
            if let app = actualResult["app"] as? String {
                if let menuCount = actualResult["menuCount"] as? Int {
                    return "Found \(menuCount) menus for \(app)"
                }
                return "Listed menus for \(app)"
            }
            return "Listed menus"

        case .listSpaces:
            if let spaces = actualResult["spaces"] as? [[String: Any]] {
                return "Found \(spaces.count) spaces"
            } else if let count = actualResult["count"] as? Int {
                return "Found \(count) spaces"
            }
            return "Listed spaces"

        case .switchSpace:
            if let to = actualResult["to"] as? Int {
                return "Switched to space \(to)"
            } else if let space = actualResult["space"] as? Int {
                return "Switched to space \(space)"
            }
            return "Switched space"

        case .moveWindowToSpace:
            var parts = ["Moved"]

            if let app = actualResult["app"] as? String {
                parts.append(app)
            }

            if let to = actualResult["to"] as? Int {
                parts.append("to space \(to)")
            } else if let space = actualResult["space"] as? Int {
                parts.append("to space \(space)")
            }

            if let followed = actualResult["followed"] as? Bool, followed {
                parts.append("(followed)")
            }

            return parts.joined(separator: " ")

        case .wait:
            if let seconds = actualResult["seconds"] as? Double {
                return "Waited \(seconds)s"
            } else if let seconds = actualResult["seconds"] as? Int {
                return "Waited \(seconds)s"
            }
            return "Waited"

        case .dockLaunch:
            var parts = ["Launched"]

            if let app = actualResult["app"] as? String {
                parts.append(app)
            } else if let appName = actualResult["appName"] as? String {
                parts.append(appName)
            }

            parts.append("from dock")
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
