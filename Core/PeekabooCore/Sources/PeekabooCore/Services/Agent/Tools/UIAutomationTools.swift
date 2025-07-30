import Foundation
import CoreGraphics
import AXorcist

// MARK: - UI Automation Tools

/// UI automation tools for clicking, typing, and interacting with elements
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the click tool
    func createClickTool() -> Tool<PeekabooServices> {
        createTool(
            name: "click",
            description: "Click on a UI element (always targets the center) or specific coordinates",
            parameters: .object(
                properties: [
                    "target": ParameterSchema.string(
                        description: "Element to click - can be button text, element label (clicks center), or 'x,y' coordinates"
                    ),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"
                    ),
                    "double_click": ParameterSchema.boolean(
                        description: "Whether to double-click (default: false)"
                    ),
                    "right_click": ParameterSchema.boolean(
                        description: "Whether to right-click (default: false)"
                    )
                ],
                required: ["target"]
            ),
            handler: { params, context in
                let target = try params.string("target")
                let appName = params.string("app", default: nil)
                let doubleClick = params.bool("double_click", default: false)
                let rightClick = params.bool("right_click", default: false)
                
                let startTime = Date()
                
                // Check if target is coordinates (e.g., "100,200")
                if target.contains(","), let coordParts = target.split(separator: ",").map(String.init).map(Double.init) as? [Double], coordParts.count == 2 {
                    let coordinates = CGPoint(x: coordParts[0], y: coordParts[1])
                    let clickType: ClickType = rightClick ? .right : (doubleClick ? .double : .single)
                    
                    try await context.automation.click(
                        target: .coordinates(coordinates),
                        clickType: clickType,
                        sessionId: nil
                    )
                    
                    let duration = Date().timeIntervalSince(startTime)
                    
                    // Get the frontmost app for better feedback
                    let frontmostApp = try? await context.applications.getFrontmostApplication()
                    let targetApp = appName ?? frontmostApp?.name ?? "unknown"
                    
                    let actionType = rightClick ? "Right-clicked" : (doubleClick ? "Double-clicked" : "Clicked")
                    return .success(
                        "\(actionType) at (\(Int(coordinates.x)), \(Int(coordinates.y))) in \(targetApp)",
                        metadata: [
                            "x": String(Int(coordinates.x)),
                            "y": String(Int(coordinates.y)),
                            "type": rightClick ? "right_click" : (doubleClick ? "double_click" : "click"),
                            "app": targetApp,
                            "duration": String(format: "%.2fs", duration)
                        ]
                    )
                }
                
                // Try to click using the target as a query
                let clickType: ClickType = rightClick ? .right : (doubleClick ? .double : .single)
                
                try await context.automation.click(
                    target: .query(target),
                    clickType: clickType,
                    sessionId: nil
                )
                
                let duration = Date().timeIntervalSince(startTime)
                
                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"
                
                let actionType = rightClick ? "Right-clicked" : (doubleClick ? "Double-clicked" : "Clicked")
                return .success(
                    "\(actionType) on '\(target)' in \(targetApp)",
                    metadata: [
                        "element": target,
                        "type": rightClick ? "right_click" : (doubleClick ? "double_click" : "click"),
                        "app": targetApp,
                        "duration": String(format: "%.2fs", duration)
                    ]
                )
            }
        )
    }
    
    /// Create the type tool
    func createTypeTool() -> Tool<PeekabooServices> {
        createTool(
            name: "type",
            description: "Type text at the current cursor position or into a specific field",
            parameters: .object(
                properties: [
                    "text": ParameterSchema.string(
                        description: "Text to type"
                    ),
                    "field": ParameterSchema.string(
                        description: "Optional: Label or identifier of the text field to type into"
                    ),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"
                    ),
                    "clear_first": ParameterSchema.boolean(
                        description: "Whether to clear the field before typing (default: false)"
                    )
                ],
                required: ["text"]
            ),
            handler: { params, context in
                let text = try params.string("text")
                let fieldLabel = params.string("field", default: nil)
                let appName = params.string("app", default: nil)
                let clearFirst = params.bool("clear_first", default: false)
                
                let startTime = Date()
                
                // If a specific field is targeted, click it first
                if let fieldLabel = fieldLabel {
                    // Click on the field to focus it
                    try await context.automation.click(
                        target: .query(fieldLabel),
                        clickType: .single,
                        sessionId: nil
                    )
                    
                    // Small delay to ensure focus
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }
                
                // Type the text using the automation service
                try await context.automation.type(
                    text: text,
                    target: fieldLabel,
                    clearExisting: clearFirst,
                    typingDelay: 0,
                    sessionId: nil
                )
                
                let duration = Date().timeIntervalSince(startTime)
                
                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"
                
                let characterCount = text.count
                var output = "Typed \(characterCount) characters"
                if characterCount <= 20 {
                    output = "Typed \"\(text)\""
                } else {
                    let preview = String(text.prefix(20)) + "..."
                    output = "Typed \"\(preview)\" (\(characterCount) characters)"
                }
                
                if let fieldLabel = fieldLabel {
                    output += " into '\(fieldLabel)'"
                }
                output += " in \(targetApp)"
                
                if clearFirst {
                    output += " (cleared first)"
                }
                
                return .success(
                    output,
                    metadata: [
                        "text": text,
                        "field": fieldLabel ?? "current focus",
                        "cleared": String(clearFirst),
                        "app": targetApp,
                        "characterCount": String(characterCount),
                        "duration": String(format: "%.2fs", duration)
                    ]
                )
            }
        )
    }
    
    /// Create the scroll tool
    func createScrollTool() -> Tool<PeekabooServices> {
        createTool(
            name: "scroll",
            description: "Scroll in a window or element",
            parameters: .object(
                properties: [
                    "direction": ParameterSchema.enumeration(
                        ["up", "down", "left", "right"],
                        description: "Scroll direction"
                    ),
                    "amount": ParameterSchema.integer(
                        description: "Number of scroll units (default: 5)"
                    ),
                    "target": ParameterSchema.string(
                        description: "Optional: Element to scroll within (label or identifier)"
                    ),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name"
                    )
                ],
                required: ["direction"]
            ),
            handler: { params, context in
                let directionStr = try params.string("direction")
                let amount = params.int("amount", default: 5) ?? 5
                let target = params.string("target", default: nil)
                let appName = params.string("app", default: nil)
                
                let startTime = Date()
                
                let direction: ScrollDirection
                switch directionStr.lowercased() {
                case "up": direction = .up
                case "down": direction = .down
                case "left": direction = .left
                case "right": direction = .right
                default:
                    throw PeekabooError.invalidInput("Invalid direction. Use: up, down, left, right")
                }
                
                // Use the automation service scroll method
                try await context.automation.scroll(
                    direction: direction,
                    amount: amount,
                    target: target,
                    smooth: false,
                    delay: 0,
                    sessionId: nil
                )
                
                let duration = Date().timeIntervalSince(startTime)
                
                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"
                
                var output = "Scrolled \(directionStr) by \(amount) units"
                if let target = target {
                    output += " in '\(target)'"
                }
                output += " - \(targetApp)"
                
                return .success(
                    output,
                    metadata: [
                        "direction": directionStr,
                        "amount": String(amount),
                        "target": target ?? "current position",
                        "app": targetApp,
                        "duration": String(format: "%.2fs", duration)
                    ]
                )
            }
        )
    }
    
    /// Create the hotkey tool
    func createHotkeyTool() -> Tool<PeekabooServices> {
        createTool(
            name: "hotkey",
            description: "Press a keyboard shortcut or key combination",
            parameters: .object(
                properties: [
                    "key": ParameterSchema.string(
                        description: "Main key to press (e.g., 'a', 'space', 'return', 'escape', 'tab', 'delete', 'arrow_up')"
                    ),
                    "modifiers": ParameterSchema.array(
                        of: ParameterSchema.enumeration(
                            ["command", "control", "option", "shift", "function"],
                            description: "Modifier key"
                        ),
                        description: "Modifier keys to hold (e.g., ['command', 'shift'])"
                    )
                ],
                required: ["key"]
            ),
            handler: { params, context in
                let keyStr = try params.string("key")
                let modifierStrs = params.stringArray("modifiers") ?? []
                
                // Map key names to match what hotkey expects
                let mappedKey: String
                switch keyStr.lowercased() {
                case "return", "enter": mappedKey = "return"
                case "escape", "esc": mappedKey = "escape"
                case "delete", "backspace": mappedKey = "delete"
                case "arrow_up", "up": mappedKey = "up"
                case "arrow_down", "down": mappedKey = "down"
                case "arrow_left", "left": mappedKey = "left"
                case "arrow_right", "right": mappedKey = "right"
                default: mappedKey = keyStr.lowercased()
                }
                
                // Map modifier strings to the expected format
                let mappedModifiers = modifierStrs.map { mod in
                    switch mod.lowercased() {
                    case "command": return "cmd"
                    case "control": return "ctrl"
                    case "option": return "option"
                    case "shift": return "shift"
                    case "function": return "fn"
                    default: return mod
                    }
                }
                
                // Build the keys string for hotkey method
                var keys = [String]()
                keys.append(contentsOf: mappedModifiers)
                keys.append(mappedKey)
                let keysString = keys.joined(separator: ",")
                
                let startTime = Date()
                
                try await context.automation.hotkey(keys: keysString, holdDuration: 0)
                
                let duration = Date().timeIntervalSince(startTime)
                
                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = frontmostApp?.name ?? "unknown"
                
                // Format the shortcut nicely
                var shortcutDisplay = ""
                if !modifierStrs.isEmpty {
                    shortcutDisplay = modifierStrs.map { $0.capitalized }.joined(separator: "+") + "+"
                }
                shortcutDisplay += keyStr.capitalized
                
                return .success(
                    "Pressed \(shortcutDisplay) in \(targetApp)",
                    metadata: [
                        "key": keyStr,
                        "modifiers": modifierStrs.joined(separator: ","),
                        "keys": keysString,
                        "shortcut": shortcutDisplay,
                        "app": targetApp,
                        "duration": String(format: "%.2fs", duration)
                    ]
                )
            }
        )
    }
}