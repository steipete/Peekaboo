import Foundation
import os.log
import PeekabooCore
import CoreGraphics

/// Tool executor that bridges between the OpenAI agent and PeekabooCore services
final class PeekabooToolExecutor: ToolExecutor {
    private let logger = Logger(subsystem: "com.steipete.peekaboo", category: "ToolExecutor")
    private let services: PeekabooServices
    
    init() {
        self.services = PeekabooServices.shared
        self.logger.info("Initialized PeekabooToolExecutor with PeekabooCore services")
    }
    
    nonisolated func executeTool(name: String, arguments: String) async -> String {
        // Parse the JSON arguments
        guard let argumentData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any]
        else {
            return self.createErrorOutput("Invalid arguments: \(arguments)")
        }
        
        do {
            // Execute tool based on name
            switch name {
            case "see":
                return try await self.executeSee(args: args)
                
            case "click":
                return try await self.executeClick(args: args)
                
            case "type":
                return try await self.executeType(args: args)
                
            case "hotkey":
                return try await self.executeHotkey(args: args)
                
            case "list":
                return try await self.executeList(args: args)
                
            case "window":
                return try await self.executeWindow(args: args)
                
            case "app":
                return try await self.executeApp(args: args)
                
            case "wait":
                return try await self.executeWait(args: args)
                
            case "menu":
                return try await self.executeMenu(args: args)
                
            case "image":
                return try await self.executeImage(args: args)
                
            case "scroll":
                return try await self.executeScroll(args: args)
                
            case "drag":
                return try await self.executeDrag(args: args)
                
            case "swipe":
                return try await self.executeSwipe(args: args)
                
            case "dialog":
                return try await self.executeDialog(args: args)
                
            case "dock":
                return try await self.executeDock(args: args)
                
            default:
                return self.createErrorOutput("Unknown tool: \(name)")
            }
        } catch {
            return self.createErrorOutput(error.localizedDescription)
        }
    }
    
    // MARK: - Tool Implementations
    
    private func executeSee(args: [String: Any]) async throws -> String {
        let sessionId = args["session_id"] as? String ?? UUID().uuidString
        
        // Determine what to capture
        let captureResult: CaptureResult
        if let appName = args["app"] as? String {
            captureResult = try await services.screenCapture.captureWindow(
                appIdentifier: appName,
                windowIndex: nil
            )
        } else {
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        // Detect elements
        let detectionResult = try await services.automation.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId
        )
        
        // Store in session
        try await services.sessions.storeDetectionResult(
            sessionId: sessionId,
            result: detectionResult
        )
        
        // Create response
        let response: [String: Any] = [
            "success": true,
            "session_id": sessionId,
            "screenshot_path": captureResult.savedPath ?? "",
            "app_name": captureResult.applicationName ?? "Unknown",
            "window_title": captureResult.windowTitle ?? "",
            "elements": detectionResult.elements.map { element in
                [
                    "id": element.id,
                    "type": element.type,
                    "label": element.label ?? "",
                    "bounds": [
                        "x": element.bounds.minX,
                        "y": element.bounds.minY,
                        "width": element.bounds.width,
                        "height": element.bounds.height
                    ],
                    "properties": element.properties
                ]
            }
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeClick(args: [String: Any]) async throws -> String {
        let sessionId = args["session_id"] as? String
        let delay = args["delay"] as? Double
        
        // Add delay if specified
        if let delay = delay {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        let clickType = ClickType.left // Default to left click
        
        if let elementId = args["element_id"] as? String {
            try await services.automation.click(
                target: .element(elementId),
                clickType: clickType,
                sessionId: sessionId
            )
        } else if let position = args["position"] as? String {
            let components = position.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid position format: \(position)")
            }
            
            try await services.automation.click(
                target: .position(CGPoint(x: x, y: y)),
                clickType: clickType,
                sessionId: sessionId
            )
        } else {
            throw PeekabooError.invalidInput("Either element_id or position must be provided")
        }
        
        let response: [String: Any] = [
            "success": true,
            "message": "Click executed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeType(args: [String: Any]) async throws -> String {
        guard let text = args["text"] as? String else {
            throw PeekabooError.invalidInput("Text parameter is required")
        }
        
        let clearFirst = args["clear_first"] as? Bool ?? false
        let sessionId = args["session_id"] as? String
        
        try await services.automation.type(
            text: text,
            target: nil, // Type into currently focused element
            clearExisting: clearFirst,
            typingDelay: 50,
            sessionId: sessionId
        )
        
        let response: [String: Any] = [
            "success": true,
            "message": "Text typed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeHotkey(args: [String: Any]) async throws -> String {
        guard let keys = args["keys"] as? String else {
            throw PeekabooError.invalidInput("Keys parameter is required")
        }
        
        try await services.automation.hotkey(keys: keys, holdDuration: 100)
        
        let response: [String: Any] = [
            "success": true,
            "message": "Hotkey executed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeList(args: [String: Any]) async throws -> String {
        guard let target = args["target"] as? String else {
            throw PeekabooError.invalidInput("Target parameter is required")
        }
        
        let response: [String: Any]
        
        switch target {
        case "apps":
            let apps = try await services.applications.listRunningApplications()
            response = [
                "success": true,
                "apps": apps.map { app in
                    [
                        "name": app.name,
                        "bundle_id": app.bundleIdentifier,
                        "pid": app.processIdentifier,
                        "is_active": app.isActive,
                        "is_hidden": app.isHidden
                    ]
                }
            ]
            
        case "windows":
            let appName = args["app"] as? String
            let windows = try await services.windows.listWindows(appIdentifier: appName)
            response = [
                "success": true,
                "windows": windows.map { window in
                    [
                        "app_name": window.appName,
                        "title": window.title,
                        "index": window.index,
                        "bounds": [
                            "x": window.bounds.minX,
                            "y": window.bounds.minY,
                            "width": window.bounds.width,
                            "height": window.bounds.height
                        ],
                        "is_minimized": window.isMinimized,
                        "is_main": window.isMain
                    ]
                }
            ]
            
        default:
            throw PeekabooError.invalidInput("Invalid target: \(target). Must be 'apps' or 'windows'")
        }
        
        return try self.createJSONOutput(response)
    }
    
    private func executeWindow(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String else {
            throw PeekabooError.invalidInput("Action parameter is required")
        }
        
        let appName = args["app"] as? String
        let title = args["title"] as? String
        
        switch action {
        case "close":
            try await services.windows.closeWindow(appIdentifier: appName, windowTitle: title)
            
        case "minimize":
            try await services.windows.minimizeWindow(appIdentifier: appName, windowTitle: title)
            
        case "maximize":
            try await services.windows.maximizeWindow(appIdentifier: appName, windowTitle: title)
            
        case "move":
            guard let position = args["position"] as? String else {
                throw PeekabooError.invalidInput("Position parameter is required for move action")
            }
            let components = position.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid position format: \(position)")
            }
            try await services.windows.moveWindow(
                appIdentifier: appName,
                windowTitle: title,
                to: CGPoint(x: x, y: y)
            )
            
        case "resize":
            guard let size = args["size"] as? String else {
                throw PeekabooError.invalidInput("Size parameter is required for resize action")
            }
            let components = size.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let width = Double(components[0]),
                  let height = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid size format: \(size)")
            }
            try await services.windows.resizeWindow(
                appIdentifier: appName,
                windowTitle: title,
                to: CGSize(width: width, height: height)
            )
            
        case "focus":
            try await services.windows.focusWindow(appIdentifier: appName, windowTitle: title)
            
        default:
            throw PeekabooError.invalidInput("Invalid action: \(action)")
        }
        
        let response: [String: Any] = [
            "success": true,
            "message": "\(action) window action completed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeApp(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String,
              let appName = args["app"] as? String else {
            throw PeekabooError.invalidInput("Action and app parameters are required")
        }
        
        switch action {
        case "launch":
            try await services.applications.launchApplication(identifier: appName)
            
        case "quit":
            try await services.applications.quitApplication(identifier: appName)
            
        case "focus":
            try await services.applications.focusApplication(identifier: appName)
            
        case "hide":
            try await services.applications.hideApplication(identifier: appName)
            
        case "unhide":
            try await services.applications.unhideApplication(identifier: appName)
            
        default:
            throw PeekabooError.invalidInput("Invalid action: \(action)")
        }
        
        let response: [String: Any] = [
            "success": true,
            "message": "\(action) application action completed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeWait(args: [String: Any]) async throws -> String {
        guard let seconds = args["seconds"] as? Double else {
            throw PeekabooError.invalidInput("Seconds parameter is required")
        }
        
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        
        let response: [String: Any] = [
            "success": true,
            "message": "Waited for \(seconds) seconds"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeMenu(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String,
              let appName = args["app"] as? String else {
            throw PeekabooError.invalidInput("Action and app parameters are required")
        }
        
        switch action {
        case "list":
            let items = try await services.menu.listMenuItems(appIdentifier: appName)
            let response: [String: Any] = [
                "success": true,
                "menu_items": self.formatMenuItems(items)
            ]
            return try self.createJSONOutput(response)
            
        case "click":
            guard let menuPath = args["menu_path"] as? String else {
                throw PeekabooError.invalidInput("Menu path is required for click action")
            }
            try await services.menu.clickMenuItem(appIdentifier: appName, menuPath: menuPath)
            let response: [String: Any] = [
                "success": true,
                "message": "Menu item clicked successfully"
            ]
            return try self.createJSONOutput(response)
            
        default:
            throw PeekabooError.invalidInput("Invalid action: \(action)")
        }
    }
    
    private func executeImage(args: [String: Any]) async throws -> String {
        let captureResult: CaptureResult
        
        if let appName = args["app"] as? String {
            let windowIndex = args["window_index"] as? Int
            captureResult = try await services.screenCapture.captureWindow(
                appIdentifier: appName,
                windowIndex: windowIndex
            )
        } else if let screenIndex = args["screen_index"] as? Int {
            captureResult = try await services.screenCapture.captureScreen(displayIndex: screenIndex)
        } else {
            // Default to frontmost window
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        let response: [String: Any] = [
            "success": true,
            "path": captureResult.savedPath ?? "",
            "app_name": captureResult.applicationName ?? "Unknown",
            "window_title": captureResult.windowTitle ?? "",
            "width": Int(captureResult.imageSize.width),
            "height": Int(captureResult.imageSize.height)
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeScroll(args: [String: Any]) async throws -> String {
        let directionString = args["direction"] as? String ?? "down"
        let amount = args["amount"] as? Int ?? 5
        let sessionId = args["session_id"] as? String
        let target = args["element_id"] as? String
        
        let direction: ScrollDirection
        switch directionString.lowercased() {
        case "up": direction = .up
        case "down": direction = .down
        case "left": direction = .left
        case "right": direction = .right
        default:
            throw PeekabooError.invalidInput("Invalid scroll direction: \(directionString)")
        }
        
        try await services.automation.scroll(
            direction: direction,
            amount: amount,
            target: target,
            smooth: false,
            delay: 10,
            sessionId: sessionId
        )
        
        let response: [String: Any] = [
            "success": true,
            "message": "Scrolled \(directionString) by \(amount) units"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeDrag(args: [String: Any]) async throws -> String {
        let sessionId = args["session_id"] as? String
        let duration = args["duration"] as? Double ?? 0.5
        
        let fromTarget: DragTarget
        let toTarget: DragTarget
        
        // Parse from target
        if let fromElementId = args["from_element_id"] as? String {
            fromTarget = .element(fromElementId)
        } else if let fromPosition = args["from_position"] as? String {
            let components = fromPosition.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid from_position format: \(fromPosition)")
            }
            fromTarget = .position(CGPoint(x: x, y: y))
        } else {
            throw PeekabooError.invalidInput("Either from_element_id or from_position is required")
        }
        
        // Parse to target
        if let toElementId = args["to_element_id"] as? String {
            toTarget = .element(toElementId)
        } else if let toPosition = args["to_position"] as? String {
            let components = toPosition.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid to_position format: \(toPosition)")
            }
            toTarget = .position(CGPoint(x: x, y: y))
        } else {
            throw PeekabooError.invalidInput("Either to_element_id or to_position is required")
        }
        
        try await services.automation.drag(
            from: fromTarget,
            to: toTarget,
            duration: duration,
            sessionId: sessionId
        )
        
        let response: [String: Any] = [
            "success": true,
            "message": "Drag operation completed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeSwipe(args: [String: Any]) async throws -> String {
        let directionString = args["direction"] as? String ?? "right"
        let distance = args["distance"] as? Double ?? 100.0
        let duration = args["duration"] as? Double ?? 0.5
        let sessionId = args["session_id"] as? String
        
        let direction: SwipeDirection
        switch directionString.lowercased() {
        case "up": direction = .up
        case "down": direction = .down
        case "left": direction = .left
        case "right": direction = .right
        default:
            throw PeekabooError.invalidInput("Invalid swipe direction: \(directionString)")
        }
        
        let startPoint: CGPoint
        if let elementId = args["element_id"] as? String {
            // Get element center from session
            guard let sessionId = sessionId,
                  let session = try? await services.sessions.getSession(sessionId: sessionId),
                  let element = session.detectionResults.first?.elements.first(where: { $0.id == elementId }) else {
                throw PeekabooError.elementNotFound(elementId)
            }
            startPoint = CGPoint(
                x: element.bounds.midX,
                y: element.bounds.midY
            )
        } else if let position = args["position"] as? String {
            let components = position.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid position format: \(position)")
            }
            startPoint = CGPoint(x: x, y: y)
        } else {
            // Default to center of screen
            startPoint = CGPoint(x: 500, y: 500) // This should be improved to get actual screen center
        }
        
        try await services.automation.swipe(
            direction: direction,
            distance: distance,
            startPoint: startPoint,
            duration: duration,
            sessionId: sessionId
        )
        
        let response: [String: Any] = [
            "success": true,
            "message": "Swiped \(directionString) by \(distance) points"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeDialog(args: [String: Any]) async throws -> String {
        let action = args["action"] as? String ?? "accept"
        let buttonText = args["button_text"] as? String
        
        switch action {
        case "accept":
            try await services.dialogs.acceptDialog(buttonText: buttonText)
        case "dismiss":
            try await services.dialogs.dismissDialog(buttonText: buttonText)
        case "input":
            guard let text = args["text"] as? String else {
                throw PeekabooError.invalidInput("Text parameter is required for input action")
            }
            try await services.dialogs.inputText(text)
        default:
            throw PeekabooError.invalidInput("Invalid dialog action: \(action)")
        }
        
        let response: [String: Any] = [
            "success": true,
            "message": "Dialog \(action) completed successfully"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeDock(args: [String: Any]) async throws -> String {
        if let action = args["action"] as? String, action == "list" {
            let items = try await services.dock.listDockItems()
            let response: [String: Any] = [
                "success": true,
                "dock_items": items.map { item in
                    [
                        "title": item.title,
                        "type": item.type,
                        "app_name": item.appName ?? "",
                        "is_running": item.isRunning
                    ]
                }
            ]
            return try self.createJSONOutput(response)
        } else if let appName = args["app"] as? String {
            try await services.dock.clickDockItem(appName: appName)
            let response: [String: Any] = [
                "success": true,
                "message": "Clicked dock item: \(appName)"
            ]
            return try self.createJSONOutput(response)
        } else {
            throw PeekabooError.invalidInput("Either action='list' or app parameter is required")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatMenuItems(_ items: [MenuItem]) -> [[String: Any]] {
        items.map { item in
            var dict: [String: Any] = [
                "title": item.title,
                "path": item.path,
                "enabled": item.isEnabled,
                "has_submenu": item.hasSubmenu
            ]
            if let shortcut = item.shortcut {
                dict["shortcut"] = shortcut
            }
            if !item.children.isEmpty {
                dict["children"] = formatMenuItems(item.children)
            }
            return dict
        }
    }
    
    private func createJSONOutput(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        guard let string = String(data: data, encoding: .utf8) else {
            throw PeekabooError.encodingError("Failed to encode JSON response")
        }
        return string
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
    
    // MARK: - Tool Parameter Definitions
    
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
            
        case "image":
            FunctionParameters(
                properties: [
                    "app": Property(type: "string", description: "Application name to capture"),
                    "window_index": Property(type: "integer", description: "Window index if multiple windows"),
                    "screen_index": Property(type: "integer", description: "Screen index for full screen capture"),
                ],
                required: [])
            
        case "scroll":
            FunctionParameters(
                properties: [
                    "direction": Property(type: "string", description: "Scroll direction", enum: ["up", "down", "left", "right"]),
                    "amount": Property(type: "integer", description: "Amount to scroll (default: 5)"),
                    "element_id": Property(type: "string", description: "Element ID to scroll within"),
                    "session_id": Property(type: "string", description: "Session ID for element lookup"),
                ],
                required: [])
            
        case "drag":
            FunctionParameters(
                properties: [
                    "from_element_id": Property(type: "string", description: "Source element ID"),
                    "from_position": Property(type: "string", description: "Source position (x,y) as alternative"),
                    "to_element_id": Property(type: "string", description: "Target element ID"),
                    "to_position": Property(type: "string", description: "Target position (x,y) as alternative"),
                    "duration": Property(type: "number", description: "Drag duration in seconds (default: 0.5)"),
                    "session_id": Property(type: "string", description: "Session ID for element lookup"),
                ],
                required: [])
            
        case "swipe":
            FunctionParameters(
                properties: [
                    "direction": Property(type: "string", description: "Swipe direction", enum: ["up", "down", "left", "right"]),
                    "distance": Property(type: "number", description: "Swipe distance in points (default: 100)"),
                    "duration": Property(type: "number", description: "Swipe duration in seconds (default: 0.5)"),
                    "element_id": Property(type: "string", description: "Element ID to swipe from"),
                    "position": Property(type: "string", description: "Start position (x,y) as alternative"),
                    "session_id": Property(type: "string", description: "Session ID for element lookup"),
                ],
                required: ["direction"])
            
        case "dialog":
            FunctionParameters(
                properties: [
                    "action": Property(type: "string", description: "Dialog action", enum: ["accept", "dismiss", "input"]),
                    "button_text": Property(type: "string", description: "Button text to click (optional)"),
                    "text": Property(type: "string", description: "Text to input (for input action)"),
                ],
                required: [])
            
        case "dock":
            FunctionParameters(
                properties: [
                    "action": Property(type: "string", description: "Dock action", enum: ["list", "click"]),
                    "app": Property(type: "string", description: "App name to click in dock"),
                ],
                required: [])
            
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
}

// MARK: - PeekabooError Extension

enum PeekabooError: LocalizedError {
    case invalidInput(String)
    case elementNotFound(String)
    case encodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .elementNotFound(let id):
            return "Element not found: \(id)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        }
    }
}