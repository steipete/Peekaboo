import Foundation
import os.log
import CoreGraphics

/// Tool executor that implements AI agent tools using PeekabooCore services
public final class PeekabooToolExecutor: ToolExecutor {
    private let logger = Logger(subsystem: "com.steipete.peekaboo", category: "ToolExecutor")
    private let services: PeekabooServices
    private let verbose: Bool
    
    public init(verbose: Bool = false) {
        self.services = PeekabooServices.shared
        self.verbose = verbose
    }
    
    public nonisolated func executeTool(name: String, arguments: String) async -> String {
        // Parse the function name
        let commandName = name.replacingOccurrences(of: "peekaboo_", with: "")
        
        // Parse JSON arguments
        guard let argsData = arguments.data(using: .utf8) else {
            return await createErrorJSON(PeekabooError.invalidInput("Invalid UTF-8 string"))
        }
        
        let args: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                return await createErrorJSON(PeekabooError.invalidInput("Arguments must be a JSON object"))
            }
            args = parsed
        } catch {
            return await createErrorJSON(PeekabooError.invalidInput("Failed to parse JSON: \(error.localizedDescription)"))
        }
        
        // Execute the appropriate function
        do {
            let result = try await executeInternalFunction(command: commandName, args: args)
            
            if verbose {
                await logVerbose("✅ Tool \(commandName) completed")
            }
            
            return result
        } catch {
            return await createErrorJSON(PeekabooError.commandFailed(error.localizedDescription))
        }
    }
    
    @MainActor
    private func executeInternalFunction(command: String, args: [String: Any]) async throws -> String {
        switch command {
        case "see":
            return try await executeSee(args: args)
        case "click":
            return try await executeClick(args: args)
        case "type":
            return try await executeType(args: args)
        case "app":
            return try await executeApp(args: args)
        case "window":
            return try await executeWindow(args: args)
        case "image":
            return try await executeImage(args: args)
        case "wait", "sleep":
            return try await executeWait(args: args)
        case "hotkey":
            return try await executeHotkey(args: args)
        case "scroll":
            return try await executeScroll(args: args)
        case "analyze_screenshot":
            return try await executeAnalyzeScreenshot(args: args)
        case "list":
            return try await executeList(args: args)
        case "shell":
            return try await executeShell(args: args)
        case "menu":
            return try await executeMenu(args: args)
        case "dialog":
            return try await executeDialog(args: args)
        case "drag":
            return try await executeDrag(args: args)
        case "dock":
            return try await executeDock(args: args)
        case "swipe":
            return try await executeSwipe(args: args)
        default:
            throw PeekabooError.invalidInput("Unknown command: \(command)")
        }
    }
    
    // MARK: - Command Implementations
    
    @MainActor
    private func executeSee(args: [String: Any]) async throws -> String {
        // Determine capture target
        let captureResult: CaptureResult
        if let app = args["app"] as? String {
            captureResult = try await services.screenCapture.captureWindow(
                appIdentifier: app,
                windowIndex: nil
            )
        } else {
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        // Save the screenshot
        let defaultPath = "/tmp/peekaboo_\(UUID().uuidString).png"
        let screenshotPath: String
        do {
            try captureResult.imageData.write(to: URL(fileURLWithPath: defaultPath))
            screenshotPath = defaultPath
        } catch {
            throw PeekabooError.fileIOError("Failed to save screenshot: \(error.localizedDescription)")
        }
        
        // Create session and detect elements
        let sessionId = try await services.sessions.createSession()
        let detectionResult = try await services.automation.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId
        )
        
        // Store detection result in session
        let enhancedResult = ElementDetectionResult(
            sessionId: sessionId,
            screenshotPath: screenshotPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata
        )
        try await services.sessions.storeDetectionResult(
            sessionId: sessionId,
            result: enhancedResult
        )
        
        // Menu bar data not available in this implementation
        let menuBarData: MenuStructure? = nil
        
        // Prepare response
        let elements = detectionResult.elements.all.map { element -> [String: Any] in
            let bounds: [String: Any] = [
                "x": element.bounds.origin.x,
                "y": element.bounds.origin.y,
                "width": element.bounds.width,
                "height": element.bounds.height
            ]
            return [
                "id": element.id,
                "type": element.type.rawValue,
                "label": element.label ?? element.value ?? "",
                "bounds": bounds,
                "isEnabled": element.isEnabled
            ]
        }
        
        var responseData: [String: Any] = [
            "screenshot_raw": screenshotPath,
            "session_id": sessionId,
            "elements": elements
        ]
        
        // Add menu bar data if available
        if let menuBar = menuBarData {
            responseData["menu_bar"] = convertMenuBarData(menuBar)
        }
        
        // Add analyze result if requested
        if args["analyze"] as? Bool == true {
            if let analysis = try? await analyzeScreenshot(path: screenshotPath) {
                responseData["analysis"] = analysis
            }
        }
        
        let response: [String: Any] = [
            "success": true,
            "data": responseData
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeClick(args: [String: Any]) async throws -> String {
        // Determine click target
        let clickTarget: ClickTarget
        if let element = args["element"] as? String {
            clickTarget = .elementId(element)
        } else if let text = args["text"] as? String {
            clickTarget = .elementId(text) // Using element ID for text search
        } else if let x = args["x"] as? Double, let y = args["y"] as? Double {
            clickTarget = .coordinates(CGPoint(x: x, y: y))
        } else {
            throw PeekabooError.invalidInput("Click requires either 'element', 'text', or 'x,y' coordinates")
        }
        
        // Get click type
        let clickType: ClickType = (args["double_click"] as? Bool ?? false) ? .double : .single
        
        // Get session ID - fall back to most recent if not provided
        let providedSessionId = args["session_id"] as? String
        let sessionId: String?
        if let provided = providedSessionId {
            sessionId = provided
        } else {
            sessionId = await services.sessions.getMostRecentSession()
        }
        
        // Perform the click
        try await services.automation.click(
            target: clickTarget,
            clickType: clickType,
            sessionId: sessionId
        )
        
        // Prepare response
        let response: [String: Any] = [
            "success": true,
            "data": [
                "message": "Click executed successfully",
                "target": "\(clickTarget)",
                "clickType": clickType.rawValue
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeType(args: [String: Any]) async throws -> String {
        guard let text = args["text"] as? String else {
            throw PeekabooError.invalidInput("Type command requires 'text' parameter")
        }
        
        let sessionId = args["session_id"] as? String
        let clearFirst = args["clear_first"] as? Bool ?? false
        
        // Perform the typing
        try await services.automation.type(
            text: text,
            target: nil,
            clearExisting: clearFirst,
            typingDelay: 10,
            sessionId: sessionId
        )
        
        // Prepare response
        let response: [String: Any] = [
            "success": true,
            "data": [
                "message": "Text typed successfully",
                "text": text,
                "charactersTyped": text.count
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeApp(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String,
              let name = args["name"] as? String
        else {
            throw PeekabooError.invalidInput("App command requires 'action' and 'name' parameters")
        }
        
        var message = ""
        var additionalData: [String: Any] = [:]
        
        switch action {
        case "launch":
            let result = try await services.applications.launchApplication(identifier: name)
            message = "App launched successfully"
            additionalData = [
                "processIdentifier": result.processIdentifier,
                "isActive": result.isActive,
                "windowCount": result.windowCount
            ]
            
        case "quit":
            _ = try await services.applications.quitApplication(identifier: name, force: false)
            message = "App quit successfully"
            
        case "focus", "switch":
            try await services.applications.activateApplication(identifier: name)
            message = "App focused successfully"
            
        case "hide":
            try await services.applications.hideApplication(identifier: name)
            message = "App hidden successfully"
            
        case "unhide":
            try await services.applications.unhideApplication(identifier: name)
            message = "App unhidden successfully"
            
        default:
            throw PeekabooError.invalidInput("Unknown app action: \(action)")
        }
        
        // Prepare response
        var responseData: [String: Any] = [
            "message": message,
            "app": name,
            "action": action
        ]
        responseData.merge(additionalData) { (_, new) in new }
        
        let response: [String: Any] = [
            "success": true,
            "data": responseData
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeWindow(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String else {
            throw PeekabooError.invalidInput("Window command requires 'action' parameter")
        }
        
        let app = args["app"] as? String
        let _ = args["title"] as? String  // Currently unused but available for future window title targeting
        
        switch action {
        case "close":
            let target: WindowTarget = app != nil ? .application(app!) : .frontmost
            try await services.windows.closeWindow(target: target)
            return createSuccessJSON("Window closed")
            
        case "minimize":
            let target: WindowTarget = app != nil ? .application(app!) : .frontmost
            try await services.windows.minimizeWindow(target: target)
            return createSuccessJSON("Window minimized")
            
        case "maximize":
            let target: WindowTarget = app != nil ? .application(app!) : .frontmost
            try await services.windows.maximizeWindow(target: target)
            return createSuccessJSON("Window maximized")
            
        case "focus":
            let target: WindowTarget = app != nil ? .application(app!) : .frontmost
            try await services.windows.focusWindow(target: target)
            return createSuccessJSON("Window focused")
            
        case "move":
            guard let x = args["x"] as? Double,
                  let y = args["y"] as? Double else {
                throw PeekabooError.invalidInput("Move command requires 'x' and 'y' parameters")
            }
            let target: WindowTarget = app != nil ? .application(app!) : .frontmost
            try await services.windows.moveWindow(target: target, to: CGPoint(x: x, y: y))
            return createSuccessJSON("Window moved")
            
        case "resize":
            guard let width = args["width"] as? Double,
                  let height = args["height"] as? Double else {
                throw PeekabooError.invalidInput("Resize command requires 'width' and 'height' parameters")
            }
            let target: WindowTarget = app != nil ? .application(app!) : .frontmost
            try await services.windows.resizeWindow(target: target, to: CGSize(width: width, height: height))
            return createSuccessJSON("Window resized")
            
        default:
            throw PeekabooError.invalidInput("Unknown window action: \(action)")
        }
    }
    
    @MainActor
    private func executeImage(args: [String: Any]) async throws -> String {
        let captureResult: CaptureResult
        
        if let app = args["app"] as? String {
            captureResult = try await services.screenCapture.captureWindow(
                appIdentifier: app,
                windowIndex: nil
            )
        } else if let mode = args["mode"] as? String, mode == "fullscreen" {
            captureResult = try await services.screenCapture.captureScreen(displayIndex: nil)
        } else {
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        // Save to specified path or default
        let path = args["path"] as? String ?? "/tmp/peekaboo_\(UUID().uuidString).png"
        try captureResult.imageData.write(to: URL(fileURLWithPath: path))
        
        let response: [String: Any] = [
            "success": true,
            "data": [
                "path": path,
                "width": captureResult.metadata.size.width,
                "height": captureResult.metadata.size.height,
                "app": captureResult.metadata.applicationInfo?.name ?? "",
                "window": captureResult.metadata.windowInfo?.title ?? ""
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeWait(args: [String: Any]) async throws -> String {
        guard let duration = args["duration"] as? Double else {
            throw PeekabooError.invalidInput("Wait command requires 'duration' parameter")
        }
        
        // Convert seconds to nanoseconds
        let nanoseconds = UInt64(duration * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
        
        return createSuccessJSON("Waited for \(duration) seconds")
    }
    
    @MainActor
    private func executeHotkey(args: [String: Any]) async throws -> String {
        let keys: [String]
        if let keysArray = args["keys"] as? [String] {
            keys = keysArray
        } else if let keysString = args["keys"] as? String {
            keys = keysString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            throw PeekabooError.invalidInput("Hotkey command requires 'keys' (array or string)")
        }
        
        // Execute hotkey
        try await services.automation.hotkey(keys: keys.joined(separator: ","), holdDuration: 0)
        
        // Prepare response
        let response: [String: Any] = [
            "success": true,
            "data": [
                "message": "Hotkey pressed successfully",
                "keys": keys
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeScroll(args: [String: Any]) async throws -> String {
        let direction = ScrollDirection(rawValue: args["direction"] as? String ?? "down") ?? .down
        let amount = args["amount"] as? Int ?? 5
        let element = args["element"] as? String
        let sessionId = args["session_id"] as? String
        
        // Execute scroll
        try await services.automation.scroll(
            direction: direction,
            amount: amount,
            target: element,
            smooth: true,
            delay: 10,
            sessionId: sessionId
        )
        
        // Prepare response
        let response: [String: Any] = [
            "success": true,
            "data": [
                "message": "Scrolled successfully",
                "direction": direction.rawValue,
                "amount": amount,
                "target": element ?? "activeWindow"
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeAnalyzeScreenshot(args: [String: Any]) async throws -> String {
        guard let screenshotPath = args["screenshot_path"] as? String else {
            throw PeekabooError.invalidInput("analyze_screenshot requires 'screenshot_path' parameter")
        }
        
        let question = args["question"] as? String ?? "What is shown in this screenshot?"
        
        // Use the vision API to analyze the screenshot
        let analysis = try await analyzeScreenshot(path: screenshotPath, question: question)
        
        // Prepare response
        let response: [String: Any] = [
            "success": true,
            "data": [
                "analysis": analysis,
                "screenshot_path": screenshotPath,
                "question": question
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeList(args: [String: Any]) async throws -> String {
        guard let target = args["target"] as? String else {
            throw PeekabooError.invalidInput("List command requires 'target' parameter")
        }
        
        switch target {
        case "apps":
            let apps = try await services.applications.listApplications()
            let appData = apps.map { app -> [String: Any] in
                return [
                    "name": app.name,
                    "bundleIdentifier": app.bundleIdentifier as Any,
                    "processIdentifier": app.processIdentifier,
                    "isActive": app.isActive,
                    "windowCount": app.windowCount
                ]
            }
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "applications": appData,
                    "count": apps.count
                ]
            ]
            
            return try createJSONOutput(response)
            
        case "windows":
            let appName = args["app"] as? String
            guard let app = appName else {
                throw PeekabooError.invalidInput("List windows requires 'app' parameter")
            }
            
            let windows = try await services.applications.listWindows(for: app)
            let windowData = windows.map { window -> [String: Any] in
                return [
                    "title": window.title,
                    "bounds": [
                        "x": window.bounds.origin.x,
                        "y": window.bounds.origin.y,
                        "width": window.bounds.width,
                        "height": window.bounds.height
                    ],
                    "isMinimized": window.isMinimized,
                    "isMainWindow": window.isMainWindow,
                    "windowID": window.windowID
                ]
            }
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "windows": windowData,
                    "count": windows.count,
                    "app": app
                ]
            ]
            
            return try createJSONOutput(response)
            
        default:
            throw PeekabooError.invalidInput("Unknown list target: \(target)")
        }
    }
    
    @MainActor
    private func executeShell(args: [String: Any]) async throws -> String {
        guard let command = args["command"] as? String else {
            throw PeekabooError.invalidInput("Shell command requires 'command' parameter")
        }
        
        let timeout = args["timeout"] as? Int ?? 30
        
        if verbose {
            logger.info("🐚 Executing shell command: \(command)")
        }
        
        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Run process
        do {
            try process.run()
        } catch {
            throw PeekabooError.commandFailed("Failed to execute shell command: \(error.localizedDescription)")
        }
        
        // Wait for completion with timeout
        let startTime = Date()
        while process.isRunning && Date().timeIntervalSince(startTime) < Double(timeout) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        if process.isRunning {
            process.terminate()
            throw PeekabooError.timeout("Shell command timed out after \(timeout) seconds")
        }
        
        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        // Prepare response based on exit code
        let response: [String: Any]
        if process.terminationStatus == 0 {
            response = [
                "success": true,
                "data": [
                    "output": output,
                    "error_output": errorOutput,
                    "exit_code": 0,
                    "command": command
                ]
            ]
        } else {
            response = [
                "success": false,
                "error": [
                    "code": "SHELL_COMMAND_FAILED",
                    "message": "Command exited with code \(process.terminationStatus)",
                    "details": [
                        "output": output,
                        "error_output": errorOutput,
                        "exit_code": process.terminationStatus
                    ]
                ]
            ]
        }
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeMenu(args: [String: Any]) async throws -> String {
        guard let app = args["app"] as? String else {
            throw PeekabooError.invalidInput("Menu command requires 'app' parameter")
        }
        
        let subcommand = args["subcommand"] as? String ?? "click"
        
        switch subcommand {
        case "click":
            // Get the menu path - either from 'path' or 'item'
            let menuPath: String
            if let path = args["path"] as? String {
                menuPath = path
            } else if let item = args["item"] as? String {
                menuPath = item
            } else {
                throw PeekabooError.invalidInput("Menu click requires either 'path' or 'item' parameter")
            }
            
            // Click the menu item
            try await services.menu.clickMenuItem(app: app, itemPath: menuPath)
            
            // Prepare response
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Menu item clicked successfully",
                    "app": app,
                    "menu_path": menuPath
                ]
            ]
            
            return try createJSONOutput(response)
            
        case "list":
            // List menu structure
            let menuStructure = try await services.menu.listMenus(for: app)
            
            // Convert to simple structure for response
            let menusData = menuStructure.menus.map { menu -> [String: Any] in
                return [
                    "title": menu.title,
                    "enabled": menu.isEnabled,
                    "items": convertMenuItems(menu.items)
                ]
            }
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "app": menuStructure.application.name,
                    "menus": menusData
                ]
            ]
            
            return try createJSONOutput(response)
            
        default:
            throw PeekabooError.invalidInput("Unknown menu subcommand: \(subcommand)")
        }
    }
    
    @MainActor
    private func executeDialog(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String else {
            throw PeekabooError.invalidInput("Dialog command requires 'action' parameter")
        }
        
        switch action {
        case "click":
            guard let button = args["button"] as? String else {
                throw PeekabooError.invalidInput("Dialog click requires 'button' parameter")
            }
            
            let targetApp = args["app"] as? String
            _ = try await services.dialogs.clickButton(
                buttonText: button,
                windowTitle: targetApp
            )
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Dialog button clicked successfully",
                    "button": button,
                    "action": "click"
                ]
            ]
            
            return try createJSONOutput(response)
            
        case "input":
            guard let text = args["text"] as? String else {
                throw PeekabooError.invalidInput("Dialog input requires 'text' parameter")
            }
            
            let field = args["field"] as? String
            let targetApp = args["app"] as? String
            
            _ = try await services.dialogs.enterText(
                text: text,
                fieldIdentifier: field,
                clearExisting: false,
                windowTitle: targetApp
            )
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Text input successfully",
                    "text": text,
                    "action": "input"
                ]
            ]
            
            return try createJSONOutput(response)
            
        case "dismiss":
            let targetApp = args["app"] as? String
            
            _ = try await services.dialogs.dismissDialog(force: false, windowTitle: targetApp)
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Dialog dismissed successfully",
                    "action": "dismiss"
                ]
            ]
            
            return try createJSONOutput(response)
            
        default:
            throw PeekabooError.invalidInput("Unknown dialog action: \(action)")
        }
    }
    
    @MainActor
    private func executeDrag(args: [String: Any]) async throws -> String {
        // Get start point
        let fromX = args["from_x"] as? Double ?? args["fromX"] as? Double
        let fromY = args["from_y"] as? Double ?? args["fromY"] as? Double
        let toX = args["to_x"] as? Double ?? args["toX"] as? Double
        let toY = args["to_y"] as? Double ?? args["toY"] as? Double
        
        guard let startX = fromX, let startY = fromY,
              let endX = toX, let endY = toY else {
            throw PeekabooError.invalidInput("Drag requires from_x, from_y, to_x, to_y parameters")
        }
        
        let fromPoint = CGPoint(x: startX, y: startY)
        let toPoint = CGPoint(x: endX, y: endY)
        let duration = args["duration"] as? Double ?? 0.5
        
        // Perform the drag
        try await services.automation.drag(
            from: fromPoint,
            to: toPoint,
            duration: Int(duration * 1000), // Convert seconds to milliseconds
            steps: 10,
            modifiers: nil
        )
        
        let response: [String: Any] = [
            "success": true,
            "data": [
                "message": "Drag completed successfully",
                "from": ["x": fromPoint.x, "y": fromPoint.y],
                "to": ["x": toPoint.x, "y": toPoint.y],
                "duration": duration
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    @MainActor
    private func executeDock(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String else {
            throw PeekabooError.invalidInput("Dock command requires 'action' parameter")
        }
        
        switch action {
        case "show":
            try await services.dock.showDock()
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Dock shown successfully",
                    "action": "show"
                ]
            ]
            
            return try createJSONOutput(response)
            
        case "hide":
            try await services.dock.hideDock()
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Dock hidden successfully",
                    "action": "hide"
                ]
            ]
            
            return try createJSONOutput(response)
            
        case "click":
            guard let app = args["app"] as? String else {
                throw PeekabooError.invalidInput("Dock click requires 'app' parameter")
            }
            
            let rightClick = args["right_click"] as? Bool ?? false
            
            if rightClick {
                try await services.dock.rightClickDockItem(
                    appName: app,
                    menuItem: nil
                )
            } else {
                try await services.dock.launchFromDock(appName: app)
            }
            
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "message": "Dock item clicked successfully",
                    "app": app,
                    "action": "click",
                    "rightClick": rightClick
                ]
            ]
            
            return try createJSONOutput(response)
            
        default:
            throw PeekabooError.invalidInput("Unknown dock action: \(action)")
        }
    }
    
    @MainActor
    private func executeSwipe(args: [String: Any]) async throws -> String {
        let direction = args["direction"] as? String ?? "left"
        let distance = args["distance"] as? Double ?? 100.0
        let duration = args["duration"] as? Double ?? 0.5
        
        // Convert direction string to SwipeDirection
        let swipeDirection: SwipeDirection
        switch direction.lowercased() {
        case "left":
            swipeDirection = .left
        case "right":
            swipeDirection = .right
        case "up":
            swipeDirection = .up
        case "down":
            swipeDirection = .down
        default:
            throw PeekabooError.invalidInput("Invalid swipe direction: \(direction)")
        }
        
        // Get start point if provided, otherwise use current mouse position
        let startPoint: CGPoint?
        if let x = args["x"] as? Double, let y = args["y"] as? Double {
            startPoint = CGPoint(x: x, y: y)
        } else {
            startPoint = nil
        }
        
        // Calculate end point based on direction and distance
        let currentPoint = startPoint ?? CGPoint(x: 500, y: 500) // Default center if not provided
        let endPoint: CGPoint
        
        switch swipeDirection {
        case .left:
            endPoint = CGPoint(x: currentPoint.x - distance, y: currentPoint.y)
        case .right:
            endPoint = CGPoint(x: currentPoint.x + distance, y: currentPoint.y)
        case .up:
            endPoint = CGPoint(x: currentPoint.x, y: currentPoint.y - distance)
        case .down:
            endPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + distance)
        }
        
        // Perform the swipe
        try await services.automation.swipe(
            from: currentPoint,
            to: endPoint,
            duration: Int(duration * 1000), // Convert seconds to milliseconds
            steps: 10
        )
        
        let response: [String: Any] = [
            "success": true,
            "data": [
                "message": "Swipe completed successfully",
                "direction": direction,
                "distance": distance,
                "duration": duration
            ]
        ]
        
        return try createJSONOutput(response)
    }
    
    // MARK: - Helper Methods
    
    private func analyzeScreenshot(path: String, question: String? = nil) async throws -> String {
        // Get configured AI providers
        let providersConfig = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"] ?? "openai/gpt-4o"
        let providers = providersConfig.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        // Try each provider until one works
        for providerSpec in providers {
            let parts = providerSpec.split(separator: "/")
            guard parts.count == 2 else { continue }
            
            let provider = String(parts[0])
            let model = String(parts[1])
            
            switch provider.lowercased() {
            case "openai":
                if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
                    return try await analyzeWithOpenAI(
                        imagePath: path,
                        question: question ?? "What is shown in this screenshot?",
                        apiKey: apiKey,
                        model: model
                    )
                }
            default:
                continue
            }
        }
        
        throw PeekabooError.noAIProviderAvailable
    }
    
    private func analyzeWithOpenAI(imagePath: String, question: String, apiKey: String, model: String) async throws -> String {
        // Read image and convert to base64
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let base64String = imageData.base64EncodedString()
        
        // Create vision request using Chat Completions API
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the message content array
        let messageContent: [[String: Any]] = [
            [
                "type": "text",
                "text": question,
            ],
            [
                "type": "image_url",
                "image_url": [
                    "url": "data:image/png;base64,\(base64String)",
                ],
            ],
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": messageContent,
                ],
            ],
            "max_tokens": 500,
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw PeekabooError.aiProviderError("Vision API request failed")
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw PeekabooError.aiProviderError("Failed to parse vision API response")
        }
        
        return content
    }
    
    @MainActor
    private func convertMenuBarData(_ menuBar: MenuStructure) -> [String: Any] {
        return [
            "app": menuBar.application.name,
            "menus": menuBar.menus.map { menu -> [String: Any] in
                return [
                    "title": menu.title,
                    "enabled": menu.isEnabled,
                    "items": convertMenuItems(menu.items)
                ]
            }
        ]
    }
    
    @MainActor
    private func convertMenuItems(_ items: [MenuItem]) -> [[String: Any]] {
        items.map { item -> [String: Any] in
            var itemData: [String: Any] = [
                "title": item.title,
                "enabled": item.isEnabled
            ]
            
            if item.isSeparator {
                itemData["separator"] = true
            }
            
            if item.isChecked {
                itemData["checked"] = true
            }
            
            if let shortcut = item.keyboardShortcut {
                itemData["shortcut"] = shortcut.displayString
            }
            
            if !item.submenu.isEmpty {
                itemData["items"] = convertMenuItems(item.submenu)
            }
            
            return itemData
        }
    }
    
    private func createSuccessJSON(_ message: String) -> String {
        let response = [
            "success": true,
            "data": ["message": message],
        ] as [String: Any]
        
        if let data = try? JSONSerialization.data(withJSONObject: response),
           let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        
        return #"{"success": true, "data": {"message": "\#(message)"}}"#
    }
    
    private nonisolated func createErrorJSON(_ error: PeekabooError) async -> String {
        let response = [
            "success": false,
            "error": [
                "message": error.localizedDescription,
                "code": error.errorCode
            ]
        ] as [String: Any]
        
        if let data = try? JSONSerialization.data(withJSONObject: response),
           let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        
        return #"{"success": false, "error": {"message": "\#(error.localizedDescription)", "code": "\#(error.errorCode)"}}"#
    }
    
    private func createJSONOutput(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        guard let string = String(data: data, encoding: .utf8) else {
            throw PeekabooError.commandFailed("Failed to convert JSON to string")
        }
        return string
    }
    
    private nonisolated func logVerbose(_ message: String) async {
        await MainActor.run {
            logger.info("\(message)")
        }
    }
    
    public nonisolated func availableTools() -> [Tool] {
        [
            makePeekabooTool("see", "Capture screenshot and analyze what's visible with vision AI"),
            makePeekabooTool("click", "Click on UI elements or coordinates"),
            makePeekabooTool("type", "Type text into UI elements"),
            makePeekabooTool("scroll", "Scroll content in any direction"),
            makePeekabooTool("hotkey", "Press keyboard shortcuts"),
            makePeekabooTool("image", "Capture screenshots of apps or screen"),
            makePeekabooTool("window", "Manipulate application windows (close, minimize, maximize, move, resize, focus)"),
            makePeekabooTool("app", "Control applications (launch, quit, focus, hide, unhide)"),
            makePeekabooTool("wait", "Wait for a specified duration in seconds"),
            makePeekabooTool("analyze_screenshot", "Analyze a screenshot using vision AI to understand UI elements and content"),
            makePeekabooTool("list", "List all running applications on macOS. Use with target='apps' to get a list of all running applications."),
            makePeekabooTool("menu", "Interact with menu bar: use 'list' subcommand to discover all menus, 'click' to click menu items"),
            makePeekabooTool("dialog", "Interact with system dialogs and alerts (click buttons, input text, dismiss)"),
            makePeekabooTool("drag", "Perform drag and drop operations between UI elements or coordinates"),
            makePeekabooTool("dock", "Interact with the macOS Dock (launch apps, right-click items)"),
            makePeekabooTool("swipe", "Perform swipe gestures for navigation and scrolling"),
            makePeekabooTool("shell", "Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)"),
        ]
    }
    
    private func makePeekabooTool(_ name: String, _ description: String) -> Tool {
        Tool(
            type: "function",
            function: Tool.Function(
                name: "peekaboo_\(name)",
                description: description,
                parameters: Tool.Parameters(
                    type: "object",
                    properties: [:],
                    required: []
                )
            )
        )
    }
    
    public nonisolated func systemPrompt() -> String {
        """
        You are a helpful AI agent that can see and interact with the macOS desktop.
        You have access to comprehensive Peekaboo commands for UI automation:

        DECISION MAKING PRIORITY:
        1. ALWAYS attempt to make reasonable decisions with available information
        2. Use context clues, common patterns, and best practices to infer intent  
        3. Only ask questions when you genuinely cannot proceed without user input

        WHEN TO ASK QUESTIONS:
        - Ambiguous requests where multiple valid interpretations exist
        - Missing critical information that cannot be reasonably inferred
        - Potentially destructive actions that need confirmation

        QUESTION FORMAT:
        When you must ask a question, end your response with:
        "❓ QUESTION: [specific question]"

        VISION & SCREENSHOTS:
        - 'see': Capture screenshots and map UI elements (use analyze=true for vision analysis)
          The see command also extracts menu bar information showing available menus
        - 'analyze_screenshot': Analyze any screenshot with vision AI
        - 'image': Take screenshots of specific apps or screens

        UI INTERACTION:
        - 'click': Click on elements or coordinates
        - 'type': Type text into the currently focused element (no element parameter needed)
          NOTE: To press Enter after typing, use a separate 'hotkey' command with ["return"]
          For efficiency, group related actions when possible
        - 'scroll': Scroll in any direction
        - 'hotkey': Press keyboard shortcuts - provide keys as array: ["cmd", "s"] or ["cmd", "shift", "d"]
          Common: ["return"] for Enter, ["tab"] for Tab, ["escape"] for Escape
        - 'drag': Drag and drop between elements
        - 'swipe': Perform swipe gestures

        APPLICATION CONTROL:
        - 'app': Launch, quit, focus, hide, or unhide applications
        - 'window': Close, minimize, maximize, move, resize, or focus windows
        - 'menu': Menu bar interaction - use subcommand='list' to discover menus, subcommand='click' to click items
          Example: menu(app="Calculator", subcommand="list") to list all menus
          Note: Use plain ellipsis "..." instead of Unicode "…" in menu paths (e.g., "Save..." not "Save…")
        - 'dock': Interact with Dock items
        - 'dialog': Handle system dialogs and alerts

        DISCOVERY & UTILITY:
        - 'list': List running apps or windows - USE THIS TO LIST APPLICATIONS!
        - 'wait': Pause execution for specified duration - AVOID USING THIS unless absolutely necessary
          Instead of waiting, use 'see' again if content seems to be loading

        When given a task:
        1. **TO LIST APPLICATIONS**: Use 'list' with target='apps' - DO NOT use Activity Monitor or screenshots!
        2. **TO LIST WINDOWS**: Use 'list' with target='windows' and app='AppName'
        3. **TO DISCOVER MENUS**: Use 'menu list --app AppName' to get full menu structure OR 'see' command which includes basic menu_bar data
        4. For UI interaction: Use 'see' to capture screenshots and map UI elements
        5. Break down complex tasks into MINIMAL specific actions
        6. Execute each action ONCE before retrying - don't repeat failed patterns
        7. Verify results only when necessary for the task
        
        FINAL RESPONSE REQUIREMENTS:
        - ALWAYS provide a meaningful final message that summarizes what you accomplished
        - For information retrieval (weather, search results, etc.): Include the actual information found
        - For actions/tasks: Describe what was done and confirm success or explain any issues
        - Be specific about the outcome - avoid generic "task completed" messages
        - Examples:
          - Information: "The weather in London is currently 15°C with cloudy skies and 70% humidity."
          - Action success: "I've opened Safari and navigated to the Apple homepage. The page is now displayed."
          - Action with issues: "I opened TextEdit but couldn't find a save button. The document remains unsaved."
        - Use 'see' with analyze=true when you need to understand or verify what's on screen
        
        IMPORTANT APP BEHAVIORS & OPTIMIZATIONS:
        - ALWAYS check window_count in app launch response BEFORE any other action
        - Safari launch pattern:
          1. Launch Safari and check window_count
          2. If window_count = 0, wait ONE second (agent processing time), then try 'see' ONCE
          3. If 'see' still fails, use 'app' focus command, then 'hotkey' ["cmd", "n"] ONCE
          4. Do NOT repeat the see/cmd+n pattern multiple times
        - STOP trying if a window is created - one window is enough
        - Browser windows may take 1-2 seconds to fully appear after launch
        - NEVER use 'wait' commands - the agent processing time provides natural delays
        - If content appears to be loading, use 'see' again instead of 'wait'
        - BE EFFICIENT: Minimize redundant commands and retries
        
        SAVING FILES:
        - After opening Save dialog, type the filename then use 'hotkey' with ["cmd", "s"] or ["return"] to save
        - To navigate to Desktop in save dialog: use 'hotkey' with ["cmd", "shift", "d"]

        EFFICIENCY & TIMING:
        - Your processing time naturally adds 1-2 seconds between commands - use this instead of 'wait'
        - One retry is usually enough - if something fails twice, try a different approach
        - For Safari/browser launches: Allow 2-3 seconds total for window to appear (your thinking time counts)
        - Reduce steps by combining related actions when possible
        - Each command costs time - optimize for minimal command count
        
        WEB SEARCH & INFORMATION RETRIEVAL:
        When asked to find information online (weather, news, facts, etc.):
        
        PREFERRED METHOD - Using shell command:
        1. Use shell(command="open https://www.google.com/search?q=weather+in+london+forecast")
           This opens the URL in the user's default browser automatically
        2. Wait a moment for the page to load
        3. Use 'see' with analyze=true to read the search results
        4. Extract and report the relevant information
        
        ALTERNATIVE METHOD - Manual browser control:
        1. First check for running browsers using: list(target="apps")
           Common browsers: Safari, Google Chrome, Firefox, Arc, Brave, Microsoft Edge, Opera
        2. If a browser is running:
           - Focus it using: app(action="focus", name="BrowserName")
           - Open new tab: hotkey(keys=["cmd", "t"])
        3. If no browser is running:
           - Try launching browsers OR use shell(command="open https://...")
        4. Once browser window is open:
           - Navigate to address bar: hotkey(keys=["cmd", "l"])
           - Type your search query
           - Press Enter: hotkey(keys=["return"])
        
        SHELL COMMAND USAGE:
        - shell(command="open https://google.com") - Opens URL in default browser
        - shell(command="open -a Safari https://example.com") - Opens in specific browser
        - shell(command="curl -s https://api.example.com") - Fetch API data directly
        - shell(command="echo 'Hello World'") - Run any shell command
        - shell(command="say 'Hello, I am your AI assistant'") - Speak text using macOS text-to-speech
        - shell(command="say -v Samantha 'Welcome to Peekaboo'") - Use specific voice (Samantha, Alex, etc.)
        - Always check the success field in response
        - IMPORTANT: Quote URLs with special characters to prevent shell expansion errors:
          ✓ shell(command="open 'https://www.google.com/search?q=weather+forecast'")
          ✗ shell(command="open https://www.google.com/search?q=weather+forecast") - fails with "no matches found"
        
        APPLESCRIPT AUTOMATION via shell:
        - shell(command="osascript -e 'tell application \"Safari\" to activate'") - Activate Safari
        - shell(command="osascript -e 'tell application \"TextEdit\" to make new document'") - Create new document
        - shell(command="osascript -e 'tell application \"Finder\" to get selection as alias list'") - Get selected files
        - shell(command="osascript -e 'tell application \"Safari\" to get URL of current tab of front window'") - Get current URL
        - shell(command="osascript -e 'tell application \"Safari\" to get URL of every tab of front window'") - Get all tab URLs
        - shell(command="osascript -e 'tell application \"Safari\" to get name of every tab of front window'") - Get all tab titles
        - shell(command="osascript -e 'tell application \"System Events\" to keystroke \"v\" using command down'") - Send keyboard shortcut
        - shell(command="osascript -e 'set volume output volume 50'") - Control system volume
        - shell(command="osascript -e 'display dialog \"Hello World\"'") - Show dialog box
        - shell(command="osascript ~/my-script.scpt") - Run AppleScript file
        - Use AppleScript when native Peekaboo commands don't provide enough control
        - AppleScript can access app-specific features not available through UI automation
        
        CRITICAL INSTRUCTIONS:
        - When asked to "list applications" or "show running apps", ALWAYS use: list(target="apps")
        - Do NOT launch Activity Monitor to list apps - use the list command!
        - Do NOT take screenshots to find running apps - use the list command!
        - MINIMIZE command usage - be efficient and avoid redundant operations
        - STOP repeating failed command patterns - try something different
        - For web information: ALWAYS try to search using Safari - don't say you can't access the web!

        Always maintain session_id across related commands for element tracking.
        Be precise with UI interactions and verify the current state before acting.
        
        REMEMBER: Your final message is what the user sees as the result. Make it informative and specific to what you accomplished or discovered. For web searches, include the actual information you found.
        """
    }
}