import AXorcist
import CoreGraphics
import Foundation
import Tachikoma

// MARK: - UI Automation Tools

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct UIAutomationToolDefinitions {
    public static let click = PeekabooToolDefinition(
        name: "click",
        commandName: nil,
        abstract: "Click on UI elements or coordinates",
        discussion: """
            The 'click' command interacts with UI elements captured by 'see'.
            It supports intelligent element finding, actionability checks, and
            automatic waiting for elements to become available.

            FEATURES:
              • Fuzzy matching - Partial text and case-insensitive search
              • Smart waiting - Automatically waits for elements to appear
              • Helpful errors - Clear guidance when elements aren't found
              • Menu bar support - Works with menu bar items

            EXAMPLES:
              peekaboo click "Sign In"              # Click button with text
              peekaboo click "sign"                 # Partial match (fuzzy)
              peekaboo click --id element_42        # Click specific element ID
              peekaboo click --coords 100,200       # Click at coordinates
              peekaboo click "Submit" --wait-for 5000  # Wait up to 5s for element
              peekaboo click "Menu" --double        # Double-click
              peekaboo click "File" --right         # Right-click

            ELEMENT MATCHING:
              Elements are matched by searching text in:
              - Title/Label content (case-insensitive)
              - Value text (partial matching)
              - Role descriptions

              Use --id for precise element targeting from 'see' output.

            TROUBLESHOOTING:
              If elements aren't found:
              - Run 'peekaboo see' first to capture the UI
              - Use 'peekaboo menubar list' for menu bar items
              - Try partial text matching
              - Increase --wait-for timeout
        """,
        category: .automation,
        parameters: [
            ParameterDefinition(
                name: "query",
                type: .string,
                description: "Element text or query to click",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "session",
                type: .string,
                description: "Session ID (uses latest if not specified)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "on",
                type: .string,
                description: "Element ID to click (e.g., B1, T2)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "id",
                type: .string,
                description: "Element ID to click (alias for --on)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name to focus before clicking",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "coords",
                type: .string,
                description: "Click at coordinates (x,y)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "wait-for",
                type: .integer,
                description: "Maximum milliseconds to wait for element",
                required: false,
                defaultValue: "5000",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "double",
                type: .boolean,
                description: "Double-click instead of single click",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag)),
            ParameterDefinition(
                name: "right",
                type: .boolean,
                description: "Right-click (secondary click)",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag)),
            ParameterDefinition(
                name: "button",
                type: .enumeration,
                description: "Mouse button to use",
                required: false,
                defaultValue: "left",
                options: ["left", "right", "middle"],
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "modifier_keys",
                type: .array,
                description: "Modifier keys to hold during click",
                required: false,
                defaultValue: nil,
                options: ["cmd", "shift", "option", "control"],
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"x": 100, "y": 200}"#,
            #"{"description": "Submit button"}"#,
            #"{"x": 50, "y": 50, "button": "right"}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - Always run 'see' first to capture UI elements
            - Use partial text matching for flexibility
            - Menu bar items may need coordinate clicks
            - Wait for elements that load dynamically
            - Check element IDs from 'see' output for precision
        """)

    public static let type = PeekabooToolDefinition(
        name: "type",
        commandName: nil,
        abstract: "Type text into the currently focused element",
        discussion: """
            Types text into the currently focused UI element with customizable
            typing speed and support for escape sequences.

            EXAMPLES:
              peekaboo type "Hello World"
              peekaboo type "username@example.com" --press-return
              peekaboo type "Line 1\\nLine 2"       # Type with newline
              peekaboo type "Name:\\tJohn"          # Type with tab
              peekaboo type "Path: C:\\\\data"      # Type literal backslash
              peekaboo type "Slow typing" --delay 100
              peekaboo type "Clear and type" --clear

            ESCAPE SEQUENCES:
              \\n - Newline/return
              \\t - Tab
              \\b - Backspace/delete
              \\e - Escape
              \\\\ - Literal backslash
        """,
        category: .automation,
        parameters: [
            ParameterDefinition(
                name: "text",
                type: .string,
                description: "Text to type",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "delay",
                type: .integer,
                description: "Delay between keystrokes in milliseconds",
                required: false,
                defaultValue: "50",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "press-return",
                type: .boolean,
                description: "Press return after typing",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag)),
            ParameterDefinition(
                name: "clear",
                type: .boolean,
                description: "Clear the field before typing",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag)),
        ],
        examples: [
            #"{"text": "Hello, World!"}"#,
            #"{"text": "username@example.com", "press_return": true}"#,
        ])

    public static let scroll = PeekabooToolDefinition(
        name: "scroll",
        commandName: nil,
        abstract: "Scroll the view in a specified direction",
        discussion: """
            Scrolls the current view or a specific element in any direction.

            EXAMPLES:
              peekaboo scroll down
              peekaboo scroll up --amount 10
              peekaboo scroll left --smooth
              peekaboo scroll down --on T1
        """,
        category: .automation,
        parameters: [
            ParameterDefinition(
                name: "direction",
                type: .enumeration,
                description: "Scroll direction",
                required: true,
                defaultValue: nil,
                options: ["up", "down", "left", "right"],
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "amount",
                type: .integer,
                description: "Number of scroll units",
                required: false,
                defaultValue: "5",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "smooth",
                type: .boolean,
                description: "Use smooth scrolling",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag)),
            ParameterDefinition(
                name: "on",
                type: .string,
                description: "Element ID to scroll on",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"direction": "down", "amount": 10}"#,
            #"{"direction": "up", "x": 500, "y": 300}"#,
        ])

    public static let press = PeekabooToolDefinition(
        name: "press",
        commandName: nil,
        abstract: "Press individual keys or key sequences",
        discussion: """
            Press individual keys for navigation and control, not for typing text.
            Perfect for pressing Enter, Tab, Escape, arrow keys, function keys, etc.

            EXAMPLES:
              peekaboo press return                # Press Enter/Return
              peekaboo press tab --count 3         # Press Tab 3 times
              peekaboo press escape                # Press Escape
              peekaboo press delete                # Press Backspace/Delete
              peekaboo press forward_delete        # Press Forward Delete (fn+delete)
              peekaboo press up down left right    # Arrow key sequence
              peekaboo press f1                    # Press F1 function key
              peekaboo press space                 # Press spacebar
              peekaboo press enter                 # Numeric keypad Enter

            AVAILABLE KEYS:
              Navigation: up, down, left, right, home, end, pageup, pagedown
              Editing: delete (backspace), forward_delete, clear
              Control: return, enter, tab, escape, space
              Function: f1-f12
              Special: caps_lock, help
        """,
        category: .automation,
        parameters: [
            ParameterDefinition(
                name: "keys",
                type: .array,
                description: "Key(s) to press",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "count",
                type: .integer,
                description: "Repeat count for all keys",
                required: false,
                defaultValue: "1",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "delay",
                type: .integer,
                description: "Delay between key presses in milliseconds",
                required: false,
                defaultValue: "100",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"keys": ["return"]}"#,
            #"{"keys": ["tab", "tab", "return"]}"#,
            #"{"keys": ["escape"]}"#,
        ])

    public static let hotkey = PeekabooToolDefinition(
        name: "hotkey",
        commandName: nil,
        abstract: "Press keyboard shortcuts",
        discussion: """
            Presses keyboard shortcuts by simulating key combinations.

            EXAMPLES:
              peekaboo hotkey cmd,c              # Copy
              peekaboo hotkey cmd,shift,t        # Reopen tab
              peekaboo hotkey cmd,space          # Spotlight
              peekaboo hotkey cmd,w --repeat 3   # Close 3 tabs
        """,
        category: .automation,
        parameters: [
            ParameterDefinition(
                name: "keys",
                type: .string,
                description: "Comma-separated list of keys to press",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "repeat",
                type: .integer,
                description: "Number of times to repeat",
                required: false,
                defaultValue: "1",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"keys": ["cmd", "c"]}"#,
            #"{"keys": ["cmd", "shift", "t"]}"#,
            #"{"keys": ["cmd", "w"], "repeat": 3}"#,
        ])
}

/// UI automation tools for clicking, typing, and interacting with elements
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the click tool
    func createClickTool() -> Tachikoma.AgentTool {
        let definition = UIAutomationToolDefinitions.click

        return Tachikoma.AgentTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentToolParameters(),
            execute: { [services] params in
                let target = params.optionalStringValue("query") ?? params.optionalStringValue("target")
                guard let target else {
                    throw PeekabooError.invalidInput("Either 'query' or 'target' parameter is required")
                }
                
                let appName = params.optionalStringValue("app")
                let doubleClick = params.optionalBooleanValue("double") ?? false
                let rightClick = params.optionalBooleanValue("right") ?? false

                let startTime = Date()

                // Check if target is coordinates (e.g., "100,200")
                if target.contains(","),
                   let coordParts = target.split(separator: ",").map(String.init).map(Double.init) as? [Double],
                   coordParts.count == 2
                {
                    let coordinates = CGPoint(x: coordParts[0], y: coordParts[1])
                    let clickType = rightClick ? ClickType.right : (doubleClick ? ClickType.double : ClickType.single)

                    try await services.automation.click(
                        target: .coordinates(coordinates),
                        clickType: clickType,
                        sessionId: nil as String?)

                    let duration = Date().timeIntervalSince(startTime)

                    // Get the frontmost app for better feedback
                    let frontmostApp = try? await services.applications.getFrontmostApplication()
                    let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                    let actionType = rightClick ? "Right-clicked" : (doubleClick ? "Double-clicked" : "Clicked")
                    return .string(
                        "\(actionType) at (\(Int(coordinates.x)), \(Int(coordinates.y))) in \(targetApp)")
                }

                // Try to click using the target as a query
                let clickType = rightClick ? ClickType.right : (doubleClick ? ClickType.double : ClickType.single)

                try await services.automation.click(
                    target: .query(target),
                    clickType: clickType,
                    sessionId: nil as String?)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await services.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                let actionType = rightClick ? "Right-clicked" : (doubleClick ? "Double-clicked" : "Clicked")
                return .string("\(actionType) on '\(target)' in \(targetApp)")
            })
    }

    /// Create the type tool
    func createTypeTool() -> Tachikoma.AgentTool {
        let definition = UIAutomationToolDefinitions.type

        return Tachikoma.AgentTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentToolParameters(),
            execute: { [services] params in
                guard let text = params.optionalStringValue("text") else {
                    throw PeekabooError.invalidInput("Text parameter is required")
                }
                
                let fieldLabel = params.optionalStringValue("field")
                let appName = params.optionalStringValue("app")
                let clearFirst = params.optionalBooleanValue("clear") ?? false

                let startTime = Date()

                // If a specific field is targeted, click it first
                if let fieldLabel {
                    // Click on the field to focus it
                    try await services.automation.click(
                        target: ClickTarget.query(fieldLabel),
                        clickType: ClickType.single,
                        sessionId: nil as String?)

                    // Small delay to ensure focus
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }

                // Type the text using the automation service
                try await services.automation.type(
                    text: text,
                    target: fieldLabel,
                    clearExisting: clearFirst,
                    typingDelay: params.optionalIntegerValue("delay") ?? 0,
                    sessionId: nil as String?)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await services.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                let characterCount = text.count
                var output = "Typed \(characterCount) characters"
                if characterCount <= 20 {
                    output = "Typed \"\(text)\""
                } else {
                    let preview = String(text.prefix(20)) + "..."
                    output = "Typed \"\(preview)\" (\(characterCount) characters)"
                }

                if let fieldLabel {
                    output += " into '\(fieldLabel)'"
                }
                output += " in \(targetApp)"

                if clearFirst {
                    output += " (cleared first)"
                }

                return .string(output)
            })
    }

    /// Create the scroll tool
    func createScrollTool() -> Tachikoma.AgentTool {
        let definition = UIAutomationToolDefinitions.scroll

        return Tachikoma.AgentTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentToolParameters(),
            execute: { [services] params in
                guard let directionStr = params.optionalStringValue("direction") else {
                    throw PeekabooError.invalidInput("Direction parameter is required")
                }
                
                let amount = params.optionalIntegerValue("amount") ?? 5
                let target = params.optionalStringValue("on")
                let appName = params.optionalStringValue("app")
                let smooth = params.optionalBooleanValue("smooth") ?? false

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
                try await services.automation.scroll(
                    direction: direction,
                    amount: amount,
                    target: target,
                    smooth: smooth,
                    delay: 0,
                    sessionId: nil as String?)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await services.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                var output = "Scrolled \(directionStr) by \(amount) units"
                if let target {
                    output += " in '\(target)'"
                }
                output += " - \(targetApp)"

                return .string(output)
            })
    }

    /// Create the press tool
    func createPressTool() -> Tachikoma.AgentTool {
        let definition = UIAutomationToolDefinitions.press

        return Tachikoma.AgentTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentToolParameters(),
            execute: { [services] params in
                // Handle array of keys or single key
                let keys: [String]
                if params["keys"] != nil {
                    keys = try params.arrayValue("keys") { argument in
                        switch argument {
                        case .string(let s): return s
                        default: throw PeekabooError.invalidInput("Array elements must be strings")
                        }
                    }
                } else if let singleKey = params.optionalStringValue("key") {
                    keys = [singleKey]
                } else {
                    throw PeekabooError.invalidInput("Either 'keys' array or single 'key' parameter is required")
                }
                
                let count = params.optionalIntegerValue("count") ?? 1
                let delay = params.optionalIntegerValue("delay") ?? 100

                let startTime = Date()

                // Process each key
                var actions: [TypeAction] = []
                for keyStr in keys {
                    // Map key name to SpecialKey enum - handle various naming conventions
                    let normalizedKey = keyStr.lowercased()
                        .replacingOccurrences(of: "_", with: "")
                        .replacingOccurrences(of: "-", with: "")

                    let mappedKey: String = switch normalizedKey {
                    case "return", "enter": "return"
                    case "forwarddelete", "fndelete": "forward_delete"
                    case "backspace", "delete": "delete"
                    case "escape", "esc": "escape"
                    case "up", "arrowup", "uparrow": "up"
                    case "down", "arrowdown", "downarrow": "down"
                    case "left", "arrowleft", "leftarrow": "left"
                    case "right", "arrowright", "rightarrow": "right"
                    case "pageup": "pageup"
                    case "pagedown": "pagedown"
                    case "capslock": "caps_lock"
                    default: normalizedKey
                    }

                    guard let specialKey = SpecialKey(rawValue: mappedKey) else {
                        throw PeekabooError
                            .invalidInput(
                                "Unknown key: '\(keyStr)'. Available keys: return, enter, tab, escape, delete, forward_delete, space, up, down, left, right, home, end, pageup, pagedown, f1-f12, caps_lock, clear, help")
                    }

                    actions.append(.key(specialKey))
                }
                
                // Repeat the entire key sequence if count > 1
                var finalActions: [TypeAction] = []
                for _ in 0..<count {
                    finalActions.append(contentsOf: actions)
                }

                // Execute the key presses
                let result = try await services.automation.typeActions(
                    finalActions,
                    typingDelay: delay,
                    sessionId: nil as String?)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await services.applications.getFrontmostApplication()
                let targetApp = frontmostApp?.name ?? "unknown"

                var output = "Pressed \(keys.joined(separator: ", "))"
                if count > 1 {
                    output += " \(count) times"
                }
                output += " in \(targetApp)"

                return .string(output)
            })
    }

    /// Create the hotkey tool
    func createHotkeyTool() -> Tachikoma.AgentTool {
        let definition = UIAutomationToolDefinitions.hotkey

        return Tachikoma.AgentTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentToolParameters(),
            execute: { [services] params in
                guard let keysString = params.optionalStringValue("keys") else {
                    throw PeekabooError.invalidInput("Keys parameter is required")
                }
                
                let repeatCount = params.optionalIntegerValue("repeat") ?? 1

                let startTime = Date()

                // Repeat the hotkey if requested
                for _ in 0..<repeatCount {
                    try await services.automation.hotkey(keys: keysString, holdDuration: 50)
                    
                    // Small delay between repeats
                    if repeatCount > 1 {
                        try await Task.sleep(nanoseconds: UInt64(100_000_000)) // 100ms
                    }
                }

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await services.applications.getFrontmostApplication()
                let targetApp = frontmostApp?.name ?? "unknown"

                // Format the shortcut nicely
                let keyParts = keysString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let shortcutDisplay = keyParts.map(\.capitalized).joined(separator: "+")

                var output = "Pressed \(shortcutDisplay)"
                if repeatCount > 1 {
                    output += " \(repeatCount) times"
                }
                output += " in \(targetApp)"

                return .string(output)
            })
    }
}
