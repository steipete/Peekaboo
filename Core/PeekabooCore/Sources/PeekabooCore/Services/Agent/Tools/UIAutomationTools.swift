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
            description: "Click on a UI element or specific coordinates",
            parameters: .object(
                properties: [
                    "target": .string(
                        description: "Element to click - can be button text, element label, or 'x,y' coordinates",
                        required: true
                    ),
                    "app": .string(
                        description: "Optional: Application name to search within",
                        required: false
                    ),
                    "double_click": .boolean(
                        description: "Whether to double-click (default: false)",
                        required: false
                    ),
                    "right_click": .boolean(
                        description: "Whether to right-click (default: false)",
                        required: false
                    )
                ],
                required: ["target"]
            ),
            handler: { params, context in
                let target = try params.string("target")
                let appName = params.string("app")
                let doubleClick = params.bool("double_click")
                let rightClick = params.bool("right_click")
                
                // Check if target is coordinates
                if let coordinates = try params.coordinates("target") {
                    if rightClick {
                        try await context.uiAutomation.rightClick(at: coordinates)
                    } else if doubleClick {
                        try await context.uiAutomation.doubleClick(at: coordinates)
                    } else {
                        try await context.uiAutomation.click(at: coordinates)
                    }
                    
                    return .success(
                        "Clicked at coordinates (\(Int(coordinates.x)), \(Int(coordinates.y)))",
                        metadata: "x", String(Int(coordinates.x)),
                        "y", String(Int(coordinates.y)),
                        "type", rightClick ? "right_click" : (doubleClick ? "double_click" : "click")
                    )
                }
                
                // Search for UI element
                let element = try await findElementWithRetry(
                    criteria: .label(target),
                    in: appName,
                    context: context
                )
                
                let bounds = try await element.frame()
                let center = CGPoint(
                    x: bounds.midX,
                    y: bounds.midY
                )
                
                if rightClick {
                    try await context.uiAutomation.rightClick(at: center)
                } else if doubleClick {
                    try await context.uiAutomation.doubleClick(at: center)
                } else {
                    try await element.performAction(.press)
                }
                
                let label = try await element.label()
                return .success(
                    "Clicked on '\(label.isEmpty ? target : label)'",
                    metadata: "element", label,
                    "x", String(Int(center.x)),
                    "y", String(Int(center.y)),
                    "type", rightClick ? "right_click" : (doubleClick ? "double_click" : "click")
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
                    "text": .string(
                        description: "Text to type",
                        required: true
                    ),
                    "field": .string(
                        description: "Optional: Label or identifier of the text field to type into",
                        required: false
                    ),
                    "app": .string(
                        description: "Optional: Application name to search within",
                        required: false
                    ),
                    "clear_first": .boolean(
                        description: "Whether to clear the field before typing (default: false)",
                        required: false
                    )
                ],
                required: ["text"]
            ),
            handler: { params, context in
                let text = try params.string("text")
                let fieldLabel = params.string("field")
                let appName = params.string("app")
                let clearFirst = params.bool("clear_first")
                
                // If a specific field is targeted, click it first
                if let fieldLabel = fieldLabel {
                    let element = try await findElementWithRetry(
                        criteria: .label(fieldLabel),
                        in: appName,
                        context: context
                    )
                    
                    // Click to focus
                    try await element.performAction(.press)
                    
                    // Small delay to ensure focus
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                    
                    if clearFirst {
                        // Select all and delete
                        try await context.uiAutomation.pressKey(
                            key: .a,
                            modifiers: [.command]
                        )
                        try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                        try await context.uiAutomation.pressKey(key: .delete)
                        try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                    }
                }
                
                // Type the text
                try await context.uiAutomation.typeText(text)
                
                var output = "Typed: \"\(text)\""
                if let fieldLabel = fieldLabel {
                    output += " into field '\(fieldLabel)'"
                }
                
                return .success(
                    output,
                    metadata: "text", text,
                    "field", fieldLabel ?? "current focus",
                    "cleared", String(clearFirst)
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
                    "direction": .string(
                        description: "Scroll direction",
                        required: true,
                        enum: ["up", "down", "left", "right"]
                    ),
                    "amount": .integer(
                        description: "Number of scroll units (default: 5)",
                        required: false
                    ),
                    "target": .string(
                        description: "Optional: Element to scroll within (label or identifier)",
                        required: false
                    ),
                    "app": .string(
                        description: "Optional: Application name",
                        required: false
                    )
                ],
                required: ["direction"]
            ),
            handler: { params, context in
                let directionStr = try params.string("direction")
                let amount = params.int("amount", default: 5) ?? 5
                let target = params.string("target")
                let appName = params.string("app")
                
                let direction: ScrollDirection
                switch directionStr.lowercased() {
                case "up": direction = .up
                case "down": direction = .down
                case "left": direction = .left
                case "right": direction = .right
                default:
                    throw PeekabooError.invalidInput("Invalid direction. Use: up, down, left, right")
                }
                
                if let target = target {
                    // Scroll within specific element
                    let element = try await findElementWithRetry(
                        criteria: .label(target),
                        in: appName,
                        context: context
                    )
                    
                    let bounds = try await element.frame()
                    let center = CGPoint(x: bounds.midX, y: bounds.midY)
                    
                    try await context.uiAutomation.scroll(
                        direction: direction,
                        amount: amount,
                        at: center
                    )
                    
                    return .success(
                        "Scrolled \(directionStr) by \(amount) units in '\(target)'",
                        metadata: "direction", directionStr,
                        "amount", String(amount),
                        "target", target
                    )
                } else {
                    // Scroll at current mouse position
                    try await context.uiAutomation.scroll(
                        direction: direction,
                        amount: amount
                    )
                    
                    return .success(
                        "Scrolled \(directionStr) by \(amount) units",
                        metadata: "direction", directionStr,
                        "amount", String(amount)
                    )
                }
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
                    "key": .string(
                        description: "Main key to press (e.g., 'a', 'space', 'return', 'escape', 'tab', 'delete', 'arrow_up')",
                        required: true
                    ),
                    "modifiers": .array(
                        items: .string(
                            description: "Modifier key",
                            enum: ["command", "control", "option", "shift", "function"]
                        ),
                        description: "Modifier keys to hold (e.g., ['command', 'shift'])",
                        required: false
                    )
                ],
                required: ["key"]
            ),
            handler: { params, context in
                let keyStr = try params.string("key")
                let modifierStrs = params.stringArray("modifiers") ?? []
                
                // Map key string to VirtualKey
                let key: VirtualKey
                switch keyStr.lowercased() {
                case "a": key = .a
                case "c": key = .c
                case "v": key = .v
                case "x": key = .x
                case "z": key = .z
                case "space": key = .space
                case "return", "enter": key = .return
                case "escape", "esc": key = .escape
                case "tab": key = .tab
                case "delete", "backspace": key = .delete
                case "arrow_up", "up": key = .upArrow
                case "arrow_down", "down": key = .downArrow
                case "arrow_left", "left": key = .leftArrow
                case "arrow_right", "right": key = .rightArrow
                default:
                    // Try to map single character
                    if keyStr.count == 1,
                       let firstChar = keyStr.lowercased().first,
                       let virtualKey = VirtualKey(character: firstChar) {
                        key = virtualKey
                    } else {
                        throw PeekabooError.invalidInput("Unknown key: \(keyStr)")
                    }
                }
                
                // Map modifier strings
                var modifiers: CGEventFlags = []
                for modStr in modifierStrs {
                    switch modStr.lowercased() {
                    case "command", "cmd": modifiers.insert(.maskCommand)
                    case "control", "ctrl": modifiers.insert(.maskControl)
                    case "option", "opt", "alt": modifiers.insert(.maskAlternate)
                    case "shift": modifiers.insert(.maskShift)
                    case "function", "fn": modifiers.insert(.maskSecondaryFn)
                    default:
                        throw PeekabooError.invalidInput("Unknown modifier: \(modStr)")
                    }
                }
                
                try await context.uiAutomation.pressKey(key: key, modifiers: modifiers)
                
                var output = "Pressed"
                if !modifierStrs.isEmpty {
                    output += " \(modifierStrs.joined(separator: "+"))+"
                }
                output += " \(keyStr)"
                
                return .success(
                    output,
                    metadata: "key", keyStr,
                    "modifiers", modifierStrs.joined(separator: ",")
                )
            }
        )
    }
}