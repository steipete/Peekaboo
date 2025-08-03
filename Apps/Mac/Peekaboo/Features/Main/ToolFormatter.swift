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
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
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
            var parts = ["Screenshot"]

            let target: String = if let mode = args["mode"] as? String {
                mode == "window" ? "active window" : mode
            } else if let app = args["app"] as? String {
                app
            } else {
                "full screen"
            }
            parts.append(target)

            // Add format if specified
            if let format = args["format"] as? String {
                parts.append("as \(format.uppercased())")
            }

            // Add path info if available
            if let path = args["path"] as? String {
                let filename = (path as NSString).lastPathComponent
                parts.append("→ \(filename)")
            }

            return parts.joined(separator: " ")

        case "window_capture":
            var parts = ["Capture"]

            if let appName = args["appName"] as? String {
                parts.append(appName)
            } else {
                parts.append("active window")
            }

            // Add window title if available
            if let windowTitle = args["windowTitle"] as? String {
                parts.append("- '\(windowTitle)'")
            } else if let windowIndex = args["windowIndex"] as? Int {
                parts.append("(window #\(windowIndex))")
            }

            return parts.joined(separator: " ")

        case "click":
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

        case "type":
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

        case "scroll":
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

        case "focus_window":
            var parts = ["Focus"]

            if let app = args["appName"] as? String {
                parts.append(app)
            } else {
                parts.append("window")
            }

            // Add window details
            if let windowTitle = args["windowTitle"] as? String {
                let truncated = windowTitle.count > 30 ? String(windowTitle.prefix(30)) + "..." : windowTitle
                parts.append("- '\(truncated)'")
            } else if let windowIndex = args["windowIndex"] as? Int {
                parts.append("(window #\(windowIndex))")
            }

            return parts.joined(separator: " ")

        case "resize_window":
            var parts = ["Resize"]
            if let app = args["appName"] as? String {
                parts.append(app)
            }
            if let width = args["width"], let height = args["height"] {
                parts.append("to \(width)×\(height)")
            }
            return parts.joined(separator: " ")

        case "launch_app":
            var parts = ["Launch"]

            if let app = args["appName"] as? String {
                parts.append(app)
            } else if let bundleId = args["bundleId"] as? String {
                parts.append("app with ID \(bundleId)")
            } else {
                parts.append("application")
            }

            // Add launch options if present
            if let background = args["background"] as? Bool, background {
                parts.append("(in background)")
            }
            if let hide = args["hide"] as? Bool, hide {
                parts.append("(hidden)")
            }

            return parts.joined(separator: " ")

        case "hotkey":
            if let keys = args["keys"] as? String {
                let formatted = self.formatKeyboardShortcut(keys)
                return "Press \(formatted)"
            }
            return "Press hotkey"

        case "shell":
            var parts = ["Run"]

            if let command = args["command"] as? String {
                // Truncate long commands
                let truncated = command.count > 50 ? String(command.prefix(50)) + "..." : command
                parts.append("'\(truncated)'")
            } else {
                parts.append("command")
            }

            // Show working directory if specified
            if let cwd = args["cwd"] as? String {
                let dirName = (cwd as NSString).lastPathComponent
                parts.append("in \(dirName)")
            }

            // Only show timeout if different from default (30s)
            if let timeout = args["timeout"] as? Double, timeout != 30.0 {
                parts.append("(timeout: \(Int(timeout))s)")
            }

            // Show if running in background
            if let background = args["background"] as? Bool, background {
                parts.append("(background)")
            }

            return parts.joined(separator: " ")

        case "menu_click":
            var parts = ["Click menu"]

            if let menuPath = args["menuPath"] as? String {
                // Show the full menu path with proper formatting
                let components = menuPath.components(separatedBy: " > ")
                if components.count > 1 {
                    let menuName = components.first ?? ""
                    let itemName = components.last ?? ""
                    parts.append("\(menuName) → \(itemName)")
                } else {
                    parts.append("'\(menuPath)'")
                }
            } else if let path = args["path"] as? String {
                // Show the full menu path with proper formatting
                let components = path.components(separatedBy: " > ")
                if components.count > 1 {
                    let menuName = components.first ?? ""
                    let itemName = components.last ?? ""
                    parts.append("\(menuName) → \(itemName)")
                } else {
                    parts.append("'\(path)'")
                }
            }

            // Add app context if available
            if let app = args["app"] as? String {
                parts.append("in \(app)")
            } else if let appName = args["appName"] as? String {
                parts.append("in \(appName)")
            }

            return parts.joined(separator: " ")

        case "list_windows":
            if let app = args["appName"] as? String {
                return "List windows for \(app)"
            }
            return "List all windows"

        case "find_element":
            var parts = ["Find"]

            if let text = args["text"] as? String {
                let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                parts.append("'\(truncated)'")
            } else if let elementId = args["elementId"] as? String {
                parts.append("element \(elementId)")
            } else if let query = args["query"] as? String {
                let truncated = query.count > 30 ? String(query.prefix(30)) + "..." : query
                parts.append("'\(truncated)'")
            } else {
                parts.append("element")
            }

            // Add search scope
            if let app = args["app"] as? String {
                parts.append("in \(app)")
            }

            // Add element type if specified
            if let type = args["type"] as? String {
                parts.append("(type: \(type))")
            }

            return parts.joined(separator: " ")

        case "list_apps":
            return "List running applications"

        case "list_elements":
            var parts = ["List"]

            if let type = args["type"] as? String {
                parts.append("\(type) elements")
            } else {
                parts.append("UI elements")
            }

            // Add scope/app context
            if let app = args["app"] as? String {
                parts.append("in \(app)")
            } else if let window = args["window"] as? String {
                parts.append("in '\(window)'")
            }

            // Add filter info
            if let role = args["role"] as? String {
                parts.append("(role: \(role))")
            }

            return parts.joined(separator: " ")

        case "focused":
            var parts = ["Get focused element"]

            // Add app context if available
            if let app = args["app"] as? String {
                parts.append("in \(app)")
            }

            return parts.joined(separator: " ")

        case "list_menus":
            if let app = args["app"] as? String {
                return "List menus for \(app)"
            } else if let appName = args["appName"] as? String {
                return "List menus for \(appName)"
            }
            return "List menu structure"

        case "list_dock":
            return "List dock items"

        case "dialog_click":
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

        case "dialog_input":
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

        case "list_spaces":
            return "List Mission Control spaces"

        case "switch_space":
            if let to = args["to"] as? Int {
                return "Switch to space \(to)"
            }
            return "Switch space"

        case "move_window_to_space":
            var parts = ["Move"]
            if let app = args["app"] as? String {
                parts.append(app)
            }
            if let to = args["to"] as? Int {
                parts.append("to space \(to)")
            }
            return parts.joined(separator: " ")

        case "wait":
            var parts = ["Wait"]

            if let seconds = args["seconds"] as? Double {
                parts.append("\(seconds)s")
            } else if let seconds = args["seconds"] as? Int {
                parts.append("\(seconds)s")
            } else if let time = args["time"] as? Double {
                parts.append("\(time)s")
            } else {
                parts.append("1s")
            }

            // Add wait reason if available
            if let reason = args["reason"] as? String {
                parts.append("for \(reason)")
            } else if let waitFor = args["for"] as? String {
                parts.append("for \(waitFor)")
            }

            return parts.joined(separator: " ")

        case "dock_launch":
            var parts = ["Launch"]

            if let app = args["appName"] as? String {
                parts.append(app)
            } else if let app = args["app"] as? String {
                parts.append(app)
            } else {
                parts.append("app")
            }

            parts.append("from dock")

            // Add position info if available
            if let position = args["position"] as? Int {
                parts.append("(position #\(position))")
            }

            return parts.joined(separator: " ")

        case "task_completed":
            return "Task completed"

        case "need_more_information":
            return "Need more information"

        case "drag":
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

        case "swipe":
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

        default:
            return toolName.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Get summary of tool result
    static func toolResultSummary(toolName: String, result: String?) -> String? {
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

        switch toolName {
        case "launch_app":
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

        case "list_apps":
            var appCount: Int?

            // Check for count value first (tool result format)
            if let countValue = actualResult["count"] as? [String: Any],
               let count = countValue["value"] as? String,
               let intCount = Int(count)
            {
                appCount = intCount
            }
            // Direct count field
            else if let count = actualResult["count"] as? Int {
                appCount = count
            }
            // Check nested structure
            else if let data = actualResult["data"] as? [String: Any],
                    let apps = data["applications"] as? [[String: Any]]
            {
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

        case "list_dock":
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

        case "see":
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

        case "type":
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

        case "hotkey":
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

        case "screenshot":
            var parts = ["Screenshot"]

            // Add target info
            if let app = actualResult["app"] as? String {
                parts.append("of \(app)")
            } else if let mode = actualResult["mode"] as? String {
                parts.append("(\(mode))")
            }

            // Add resolution if available
            if let width = actualResult["width"] as? Int,
               let height = actualResult["height"] as? Int
            {
                parts.append("\(width)×\(height)")
            }

            // Add file info
            if let path = actualResult["path"] as? String {
                let filename = (path as NSString).lastPathComponent
                parts.append("→ \(filename)")

                // Add file size if available
                if let size = actualResult["fileSize"] as? Int {
                    let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                    parts.append("(\(sizeStr))")
                }
            }

            return parts.joined(separator: " ")

        case "window_capture":
            var parts: [String] = []

            if let captured = actualResult["captured"] as? Bool, captured {
                parts.append("Captured")

                // Add app name
                if let app = actualResult["app"] as? String {
                    parts.append(app)
                }

                // Add window title
                if let windowTitle = actualResult["windowTitle"] as? String {
                    let truncated = windowTitle.count > 30 ? String(windowTitle.prefix(30)) + "..." : windowTitle
                    parts.append("- '\(truncated)'")
                }

                // Add window dimensions if available
                if let width = actualResult["width"] as? Int,
                   let height = actualResult["height"] as? Int
                {
                    parts.append("(\(width)×\(height))")
                }
            } else {
                parts.append("Capture failed")
            }

            return parts.joined(separator: " ")

        case "shell":
            var parts: [String] = []

            // Check exit code
            if let exitCode = actualResult["exitCode"] as? Int {
                if exitCode == 0 {
                    parts.append("✓ Completed")
                } else {
                    parts.append("✗ Failed (exit \(exitCode))")
                }
            }

            // Add command if available
            if let command = actualResult["command"] as? String {
                let truncated = command.count > 40 ? String(command.prefix(40)) + "..." : command
                parts.append("'\(truncated)'")
            }

            // Add execution time if available
            if let duration = actualResult["duration"] as? Double {
                parts.append("in \(String(format: "%.2f", duration))s")
            }

            // Add output preview if available and command succeeded
            if let output = actualResult["output"] as? String,
               !output.isEmpty,
               let exitCode = actualResult["exitCode"] as? Int,
               exitCode == 0
            {
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                if !lines.isEmpty {
                    let preview = lines.first!.count > 30 ? String(lines.first!.prefix(30)) + "..." : lines.first!
                    parts.append("→ \(preview)")
                }
            }

            return parts.joined(separator: " ")

        case "scroll":
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

        case "menu_click":
            var parts = ["Clicked"]

            // Get the menu path with better formatting
            if let menuPath = actualResult["menuPath"] as? String {
                let components = menuPath.components(separatedBy: " > ")
                if components.count > 1 {
                    let menuName = components.first ?? ""
                    let itemName = components.last ?? ""
                    parts.append("\(menuName) → \(itemName)")
                } else {
                    parts.append("'\(menuPath)'")
                }
            } else if let path = actualResult["path"] as? String {
                let components = path.components(separatedBy: " > ")
                if components.count > 1 {
                    let menuName = components.first ?? ""
                    let itemName = components.last ?? ""
                    parts.append("\(menuName) → \(itemName)")
                } else {
                    parts.append("'\(path)'")
                }
            }

            // Add app if available
            if let app = actualResult["app"] as? String {
                parts.append("in \(app)")
            }

            // Add keyboard shortcut if the menu item had one
            if let shortcut = actualResult["shortcut"] as? String {
                parts.append("(\(self.formatKeyboardShortcut(shortcut)))")
            }

            return parts.joined(separator: " ")

        case "dialog_click":
            var parts = ["Clicked"]

            if let button = actualResult["button"] as? String {
                parts.append("'\(button)'")
            }

            if let window = actualResult["window"] as? String {
                parts.append("in \(window)")
            }

            return parts.joined(separator: " ")

        case "dialog_input":
            var parts = ["Entered"]

            if let text = actualResult["text"] as? String {
                let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                parts.append("'\(truncated)'")
            }

            if let field = actualResult["field"] as? String {
                parts.append("in \(field)")
            }

            return parts.joined(separator: " ")

        case "find_element":
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
                parts.append("✓ Found")

                // Get element details
                if let element = actualResult["element"] as? String {
                    let truncated = element.count > 30 ? String(element.prefix(30)) + "..." : element
                    parts.append("'\(truncated)'")
                } else if let elementWrapper = actualResult["element"] as? [String: Any],
                          let elementValue = elementWrapper["value"] as? String
                {
                    let truncated = elementValue.count > 30 ? String(elementValue.prefix(30)) + "..." : elementValue
                    parts.append("'\(truncated)'")
                } else if let text = actualResult["text"] as? String {
                    let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                    parts.append("'\(truncated)'")
                }

                // Add element type if available
                if let type = actualResult["type"] as? String {
                    parts.append("(\(type))")
                }

                // Add location if available
                if let elementId = actualResult["elementId"] as? String {
                    parts.append("as \(elementId)")
                }

                // Add coordinates if available
                if let x = actualResult["x"] as? Int,
                   let y = actualResult["y"] as? Int
                {
                    parts.append("at (\(x), \(y))")
                }

                // Add app context
                if let app = actualResult["app"] as? String {
                    parts.append("in \(app)")
                }
            } else {
                parts.append("✗ Not found")

                // Add what was searched for
                if let query = actualResult["query"] as? String {
                    let truncated = query.count > 30 ? String(query.prefix(30)) + "..." : query
                    parts.append("'\(truncated)'")
                } else if let text = actualResult["text"] as? String {
                    let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                    parts.append("'\(truncated)'")
                }

                // Add search scope if available
                if let app = actualResult["app"] as? String {
                    parts.append("in \(app)")
                }
            }

            return parts.joined(separator: " ")

        case "focused":
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

        case "resize_window":
            var parts = ["Resized"]

            if let app = actualResult["app"] as? String {
                parts.append(app)
            }

            if let width = actualResult["width"], let height = actualResult["height"] {
                parts.append("to \(width)×\(height)")
            }

            return parts.joined(separator: " ")

        case "focus_window":
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

        case "list_windows":
            // Check for count in various formats
            var windowCount: Int?

            // Direct count field
            if let count = actualResult["count"] as? Int {
                windowCount = count
            }
            // Wrapped count field
            else if let countWrapper = actualResult["count"] as? [String: Any],
                    let value = countWrapper["value"] as? Int
            {
                windowCount = value
            }
            // Count from windows array
            else if let windows = actualResult["windows"] as? [[String: Any]] {
                windowCount = windows.count
            }
            // Count from data.windows array
            else if let data = actualResult["data"] as? [String: Any],
                    let windows = data["windows"] as? [[String: Any]]
            {
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

        case "list_elements":
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

        case "list_menus":
            var parts: [String] = []

            // Check for menu count
            var menuCount: Int?
            if let count = actualResult["menuCount"] as? Int {
                menuCount = count
            } else if let menus = actualResult["menus"] as? [[String: Any]] {
                menuCount = menus.count
            }

            if let count = menuCount {
                parts.append("Found \(count) menu\(count == 1 ? "" : "s")")
            } else {
                parts.append("Listed menus")
            }

            // Add app name
            if let app = actualResult["app"] as? String {
                parts.append("for \(app)")
            } else if let appName = actualResult["appName"] as? String {
                parts.append("for \(appName)")
            }

            // Add total items count if available
            if let totalItems = actualResult["totalItems"] as? Int {
                parts.append("with \(totalItems) total item\(totalItems == 1 ? "" : "s")")
            }

            return parts.joined(separator: " ")

        case "list_spaces":
            if let spaces = actualResult["spaces"] as? [[String: Any]] {
                return "Found \(spaces.count) spaces"
            } else if let count = actualResult["count"] as? Int {
                return "Found \(count) spaces"
            }
            return "Listed spaces"

        case "switch_space":
            if let to = actualResult["to"] as? Int {
                return "Switched to space \(to)"
            } else if let space = actualResult["space"] as? Int {
                return "Switched to space \(space)"
            }
            return "Switched space"

        case "move_window_to_space":
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

        case "wait":
            if let seconds = actualResult["seconds"] as? Double {
                return "Waited \(seconds)s"
            } else if let seconds = actualResult["seconds"] as? Int {
                return "Waited \(seconds)s"
            }
            return "Waited"

        case "dock_launch":
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
