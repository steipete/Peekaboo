import Foundation
import os.log

/// Tool executor that bridges between the OpenAI agent and peekaboo CLI
final class PeekabooToolExecutor: ToolExecutor {
    private let logger = Logger(subsystem: "com.steipete.peekaboo", category: "ToolExecutor")
    private let cliPath: String

    init() {
        // Find peekaboo CLI - first check if it's in the app bundle
        if let bundlePath = Bundle.main.path(forResource: "peekaboo", ofType: nil) {
            self.cliPath = bundlePath
        } else {
            // Fallback to development path
            let devPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Projects/Peekaboo/peekaboo-cli/.build/debug/peekaboo")
                .path
            self.cliPath = devPath
        }

        self.logger.info("Using peekaboo CLI at: \(self.cliPath)")
    }

    nonisolated func executeTool(name: String, arguments: String) async -> String {
        // Parse the JSON arguments
        guard let argumentData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any]
        else {
            return self.createErrorOutput("Invalid arguments: \(arguments)")
        }

        // Build command based on tool name
        var command = [cliPath, name]

        // Add arguments based on the tool
        switch name {
        case "see":
            if let app = args["app"] as? String {
                command.append("--app")
                command.append(app)
            }
            command.append("--json-output")

        case "click":
            if let elementId = args["element_id"] as? String {
                command.append("--element-id")
                command.append(elementId)
            } else if let position = args["position"] as? String {
                command.append("--position")
                command.append(position)
            }
            if let delay = args["delay"] as? Double {
                command.append("--delay")
                command.append(String(delay))
            }
            command.append("--json-output")

        case "type":
            if let text = args["text"] as? String {
                command.append(text)
            }
            if let clear = args["clear_first"] as? Bool, clear {
                command.append("--clear-first")
            }
            command.append("--json-output")

        case "hotkey":
            if let keys = args["keys"] as? String {
                command.append(keys)
            }
            command.append("--json-output")

        case "list":
            if let target = args["target"] as? String {
                command.append(target)
            }
            if let app = args["app"] as? String {
                command.append("--app")
                command.append(app)
            }
            command.append("--json-output")

        case "window":
            if let action = args["action"] as? String {
                command.append(action)
            }
            if let app = args["app"] as? String {
                command.append("--app")
                command.append(app)
            }
            if let title = args["title"] as? String {
                command.append("--title")
                command.append(title)
            }
            command.append("--json-output")

        case "app":
            if let action = args["action"] as? String {
                command.append(action)
            }
            if let appName = args["app"] as? String {
                command.append(appName)
            }
            command.append("--json-output")

        case "wait":
            if let seconds = args["seconds"] as? Double {
                command.append(String(seconds))
            }

        case "menu":
            if let action = args["action"] as? String {
                command.append(action)
            }
            if let app = args["app"] as? String {
                command.append("--app")
                command.append(app)
            }
            if let menuPath = args["menu_path"] as? String {
                command.append("--path")
                command.append(menuPath)
            }
            command.append("--json-output")

        default:
            // Generic handling for other tools
            for (key, value) in args {
                command.append("--\(key.replacingOccurrences(of: "_", with: "-"))")
                command.append("\(value)")
            }
            if !command.contains("--json-output") {
                command.append("--json-output")
            }
        }

        // Execute command
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if process.terminationStatus == 0 {
                return String(data: outputData, encoding: .utf8) ?? "Success"
            } else {
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return self.createErrorOutput(errorString)
            }
        } catch {
            return self.createErrorOutput("Failed to execute command: \(error.localizedDescription)")
        }
    }

    nonisolated func availableTools() -> [Tool] {
        [
            self.makePeekabooTool("see", "Capture and analyze UI state"),
            self.makePeekabooTool("click", "Click on UI elements or coordinates"),
            self.makePeekabooTool("type", "Type text into the focused element"),
            self.makePeekabooTool("scroll", "Scroll content in any direction"),
            self.makePeekabooTool("hotkey", "Press keyboard shortcuts"),
            self.makePeekabooTool("image", "Capture screenshots of apps or screen"),
            self.makePeekabooTool("window", "Manipulate application windows"),
            self.makePeekabooTool("app", "Control applications"),
            self.makePeekabooTool("wait", "Wait for a specified duration"),
            self.makePeekabooTool("list", "List running applications or windows"),
            self.makePeekabooTool("menu", "Interact with menu bar"),
            self.makePeekabooTool("dialog", "Interact with system dialogs"),
            self.makePeekabooTool("drag", "Perform drag and drop operations"),
            self.makePeekabooTool("dock", "Interact with the macOS Dock"),
            self.makePeekabooTool("swipe", "Perform swipe gestures"),
        ]
    }

    nonisolated func systemPrompt() -> String {
        """
        You are Peekaboo, an AI assistant specialized in macOS automation.

        You have access to tools that let you see and interact with the macOS UI.
        Available tools:

        VISUALIZATION & CAPTURE:
        - 'see': Capture current UI state with element mappings
        - 'image': Capture screenshots of apps or entire screen

        UI INTERACTION:
        - 'click': Click on elements (by ID from 'see') or coordinates
        - 'type': Type text into focused fields
        - 'scroll': Scroll in windows or elements
        - 'drag': Drag and drop between elements
        - 'swipe': Perform swipe gestures

        KEYBOARD & SHORTCUTS:
        - 'hotkey': Press keyboard shortcuts (e.g., "cmd+c", "cmd+shift+a")

        APPLICATION CONTROL:
        - 'app': Launch, quit, focus, hide/unhide apps
        - 'window': Close, minimize, maximize, move, resize windows
        - 'dock': Interact with Dock items

        DISCOVERY & UTILITY:
        - 'list': List running apps or windows
        - 'menu': Discover and click menu items
        - 'dialog': Handle system dialogs
        - 'wait': Pause execution

        When given a task:
        1. Use 'see' to understand the current UI state
        2. Use 'list' to discover running applications
        3. Use 'menu list' to discover available menus
        4. Break down complex tasks into specific actions
        5. Execute each action using the appropriate command
        6. Verify results when needed

        Be precise with UI interactions and verify the current state before acting.
        """
    }

    // MARK: - Helper Methods

    private nonisolated func makePeekabooTool(_ name: String, _ description: String) -> Tool {
        // Define parameters based on tool name
        let parameters = switch name {
        case "see":
            FunctionParameters(
                properties: [
                    "app": Property(type: "string", description: "Application name to capture"),
                    "window": Property(type: "string", description: "Window title to capture"),
                    "session_id": Property(type: "string", description: "Session ID for element tracking"),
                ],
                required: [])

        case "click":
            FunctionParameters(
                properties: [
                    "element_id": Property(type: "string", description: "Element ID from 'see' command"),
                    "position": Property(type: "string", description: "x,y coordinates as alternative to element_id"),
                    "delay": Property(type: "number", description: "Delay before click in seconds"),
                    "session_id": Property(type: "string", description: "Session ID for element lookup"),
                ],
                required: [])

        case "type":
            FunctionParameters(
                properties: [
                    "text": Property(type: "string", description: "Text to type"),
                    "clear_first": Property(type: "boolean", description: "Clear existing text first"),
                ],
                required: ["text"])

        case "hotkey":
            FunctionParameters(
                properties: [
                    "keys": Property(type: "string", description: "Keyboard shortcut (e.g., 'cmd+c')"),
                ],
                required: ["keys"])

        case "list":
            FunctionParameters(
                properties: [
                    "target": Property(type: "string", description: "What to list", enum: ["apps", "windows"]),
                    "app": Property(type: "string", description: "App name when listing windows"),
                ],
                required: ["target"])

        case "window":
            FunctionParameters(
                properties: [
                    "action": Property(type: "string", description: "Window action",
                                       enum: ["close", "minimize", "maximize", "move", "resize", "focus"]),
                    "app": Property(type: "string", description: "Application name"),
                    "title": Property(type: "string", description: "Window title"),
                    "position": Property(type: "string", description: "New position for move (x,y)"),
                    "size": Property(type: "string", description: "New size for resize (width,height)"),
                ],
                required: ["action"])

        case "app":
            FunctionParameters(
                properties: [
                    "action": Property(type: "string", description: "App action",
                                       enum: ["launch", "quit", "focus", "hide", "unhide"]),
                    "app": Property(type: "string", description: "Application name or bundle ID"),
                ],
                required: ["action", "app"])

        case "wait":
            FunctionParameters(
                properties: [
                    "seconds": Property(type: "number", description: "Seconds to wait"),
                ],
                required: ["seconds"])

        case "menu":
            FunctionParameters(
                properties: [
                    "action": Property(type: "string", description: "Menu action", enum: ["list", "click"]),
                    "app": Property(type: "string", description: "Application name"),
                    "menu_path": Property(type: "string", description: "Menu path for clicking (e.g., 'File/Save')"),
                ],
                required: ["action", "app"])

        default:
            // Generic parameters
            FunctionParameters(properties: [:], required: [])
        }

        return Tool(
            function: ToolFunction(
                name: name,
                description: description,
                parameters: parameters))
    }

    private nonisolated func createErrorOutput(_ message: String) -> String {
        let error = [
            "success": false,
            "error": [
                "message": message,
                "code": "TOOL_EXECUTION_FAILED",
            ],
        ] as [String: Any]

        if let data = try? JSONSerialization.data(withJSONObject: error),
           let string = String(data: data, encoding: .utf8)
        {
            return string
        }

        return "{\"success\": false, \"error\": {\"message\": \"Failed to create error output\"}}"
    }
}
