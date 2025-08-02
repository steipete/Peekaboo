import AXorcist
import CoreGraphics
import Foundation
import Tachikoma

// MARK: - UI Automation Tools

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct UIAutomationToolDefinitions {
    public static let click = UnifiedToolDefinition(
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

    public static let type = UnifiedToolDefinition(
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

    public static let scroll = UnifiedToolDefinition(
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

    public static let press = UnifiedToolDefinition(
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

    public static let hotkey = UnifiedToolDefinition(
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
    func createClickTool() -> Tool<PeekabooServices> {
        let definition = UIAutomationToolDefinitions.click

        // Custom parameter mapping for agent tool
        let parameters = ToolParameters.object(
            properties: [
                "target": ParameterSchema.string(
                    description: "Element to click - can be button text, element label (clicks center), or 'x,y' coordinates"),
                "app": ParameterSchema.string(
                    description: "Optional: Application name to search within"),
                "double_click": ParameterSchema.boolean(
                    description: "Whether to double-click (default: false)"),
                "right_click": ParameterSchema.boolean(
                    description: "Whether to right-click (default: false)"),
            ],
            required: ["target"])

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: parameters,
            execute: { params, context in
                let target = try params.string("target")
                let appName = params.string("app", default: nil)
                let doubleClick = params.bool("double_click", default: false)
                let rightClick = params.bool("right_click", default: false)

                let startTime = Date()

                // Check if target is coordinates (e.g., "100,200")
                if target.contains(","),
                   let coordParts = target.split(separator: ",").map(String.init).map(Double.init) as? [Double],
                   coordParts.count == 2
                {
                    let coordinates = CGPoint(x: coordParts[0], y: coordParts[1])
                    let clickType = rightClick ? ClickType.right : (doubleClick ? ClickType.double : ClickType.single)

                    try await context.automation.click(
                        target: .coordinates(coordinates),
                        clickType: clickType,
                        sessionId: nil)

                    let duration = Date().timeIntervalSince(startTime)

                    // Get the frontmost app for better feedback
                    let frontmostApp = try? await context.applications.getFrontmostApplication()
                    let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                    let actionType = rightClick ? "Right-clicked" : (doubleClick ? "Double-clicked" : "Clicked")
                    return .success(
                        "\(actionType) at (\(Int(coordinates.x)), \(Int(coordinates.y))) in \(targetApp)")
                }

                // Try to click using the target as a query
                let clickType = rightClick ? ClickType.right : (doubleClick ? ClickType.double : ClickType.single)

                try await context.automation.click(
                    target: .query(target),
                    clickType: clickType,
                    sessionId: nil)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                let actionType = rightClick ? "Right-clicked" : (doubleClick ? "Double-clicked" : "Clicked")
                return .success("\(actionType) on '\(target)' in \(targetApp)")
            })
    }

    /// Create the type tool
    func createTypeTool() -> Tool<PeekabooServices> {
        createTool(
            name: "type",
            description: "Type text at the current cursor position or into a specific field. Supports escape sequences: \\n (newline), \\t (tab), \\b (backspace), \\e (escape), \\\\ (literal backslash)",
            parameters: ToolParameters.object(
                properties: [
                    "text": ParameterSchema.string(
                        description: "Text to type. Supports escape sequences: \\n (newline), \\t (tab), \\b (backspace), \\e (escape), \\\\ (literal backslash)"),
                    "field": ParameterSchema.string(
                        description: "Optional: Label or identifier of the text field to type into"),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"),
                    "clear_first": ParameterSchema.boolean(
                        description: "Whether to clear the field before typing (default: false)"),
                ],
                required: ["text"]),
            execute: { params, context in
                let text = try params.string("text")
                let fieldLabel = params.string("field", default: nil)
                let appName = params.string("app", default: nil)
                let clearFirst = params.bool("clear_first", default: false)

                let startTime = Date()

                // If a specific field is targeted, click it first
                if let fieldLabel {
                    // Click on the field to focus it
                    try await context.automation.click(
                        target: .query(fieldLabel),
                        clickType: .single,
                        sessionId: nil)

                    // Small delay to ensure focus
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }

                // Type the text using the automation service
                try await context.automation.type(
                    text: text,
                    target: fieldLabel,
                    clearExisting: clearFirst,
                    typingDelay: 0,
                    sessionId: nil)

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

                if let fieldLabel {
                    output += " into '\(fieldLabel)'"
                }
                output += " in \(targetApp)"

                if clearFirst {
                    output += " (cleared first)"
                }

                return .success(output)
            })
    }

    /// Create the scroll tool
    func createScrollTool() -> Tool<PeekabooServices> {
        createTool(
            name: "scroll",
            description: "Scroll in a window or element",
            parameters: ToolParameters.object(
                properties: [
                    "direction": ParameterSchema.enumeration(
                        ["up", "down", "left", "right"],
                        description: "Scroll direction"),
                    "amount": ParameterSchema.integer(
                        description: "Number of scroll units (default: 5)"),
                    "target": ParameterSchema.string(
                        description: "Optional: Element to scroll within (label or identifier)"),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name"),
                ],
                required: ["direction"]),
            execute: { params, context in
                let directionStr = try params.string("direction")
                let amount = params.int("amount", default: 5) ?? 5
                let target = params.string("target", default: nil)
                let appName = params.string("app", default: nil)

                let startTime = Date()

                let direction: ScrollDirection
                switch directionStr?.lowercased() ?? "" {
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
                    sessionId: nil)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = appName ?? frontmostApp?.name ?? "unknown"

                var output = "Scrolled \(directionStr) by \(amount) units"
                if let target {
                    output += " in '\(target)'"
                }
                output += " - \(targetApp)"

                return .success(output)
            })
    }

    /// Create the press tool
    func createPressTool() -> Tool<PeekabooServices> {
        createTool(
            name: "press",
            description: "Press individual keys like Enter, Tab, Escape, arrow keys, etc. Use this instead of type when you just need to press special keys.",
            parameters: ToolParameters.object(
                properties: [
                    "key": ParameterSchema.string(
                        description: "Key to press: return, enter, tab, escape, delete, forward_delete, space, up, down, left, right, home, end, pageup, pagedown, f1-f12, caps_lock, clear, help"),
                    "count": ParameterSchema.integer(
                        description: "Number of times to press the key (default: 1)"),
                ],
                required: ["key"]),
            execute: { params, context in
                let keyStr = try params.string("key")
                let count = params.int("count", default: 1) ?? 1

                let startTime = Date()

                // Map key name to SpecialKey enum - handle various naming conventions
                let normalizedKey = keyStr?.lowercased() ?? ""
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

                // Build type actions for the key presses
                var actions: [TypeAction] = []
                for _ in 0..<count {
                    actions.append(.key(specialKey))
                }

                // Execute the key presses
                let result = try await context.automation.typeActions(
                    actions,
                    typingDelay: 100, // 100ms between key presses
                    sessionId: nil)

                let duration = Date().timeIntervalSince(startTime)

                // Get the frontmost app for better feedback
                let frontmostApp = try? await context.applications.getFrontmostApplication()
                let targetApp = frontmostApp?.name ?? "unknown"

                var output = "Pressed '\(keyStr)'"
                if count > 1 {
                    output += " \(count) times"
                }
                output += " in \(targetApp)"

                return .success(output)
            })
    }

    /// Create the hotkey tool
    func createHotkeyTool() -> Tool<PeekabooServices> {
        createTool(
            name: "hotkey",
            description: "Press a keyboard shortcut or key combination",
            parameters: ToolParameters.object(
                properties: [
                    "key": ParameterSchema.string(
                        description: "Main key to press (e.g., 'a', 'space', 'return', 'escape', 'tab', 'delete', 'arrow_up')"),
                    "modifiers": ParameterSchema.array(
                        of: ParameterSchema.enumeration(
                            ["command", "control", "option", "shift", "function"],
                            description: "Modifier key"),
                        description: "Modifier keys to hold (e.g., ['command', 'shift'])"),
                ],
                required: ["key"]),
            execute: { params, context in
                let keyStr = try params.string("key")
                let modifierStrs = params.arguments["modifiers"] as? [String] ?? []

                // Map key names to match what hotkey expects
                let mappedKey: String = switch keyStr?.lowercased() ?? "" {
                case "return", "enter": "return"
                case "escape", "esc": "escape"
                case "delete", "backspace": "delete"
                case "arrow_up", "up": "up"
                case "arrow_down", "down": "down"
                case "arrow_left", "left": "left"
                case "arrow_right", "right": "right"
                default: keyStr?.lowercased() ?? ""
                }

                // Map modifier strings to the expected format
                let mappedModifiers = modifierStrs.map { mod in
                    switch mod.lowercased() {
                    case "command": "cmd"
                    case "control": "ctrl"
                    case "option": "option"
                    case "shift": "shift"
                    case "function": "fn"
                    default: mod
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
                    shortcutDisplay = modifierStrs.map(\.capitalized).joined(separator: "+") + "+"
                }
                shortcutDisplay += keyStr?.capitalized ?? ""

                return .success("Pressed \(shortcutDisplay) in \(targetApp)")
            })
    }
}
