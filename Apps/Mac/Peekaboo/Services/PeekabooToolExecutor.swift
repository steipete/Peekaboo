import Foundation
import os.log
import PeekabooCore
import CoreGraphics
import ApplicationServices

/// Tool executor that bridges between the OpenAI agent and PeekabooCore services
final class PeekabooToolExecutor: ToolExecutor {
    private let logger = Logger(subsystem: "com.steipete.peekaboo", category: "ToolExecutor")
    private let services: PeekabooServices
    
    init() {
        self.services = PeekabooServices.shared
        self.logger.info("Initialized PeekabooToolExecutor with PeekabooCore services")
    }
    
    nonisolated func executeTool(name: String, arguments: String) async -> String {
        await MainActor.run {
            logger.info("🔧 Executing tool: \(name)")
            logger.debug("Arguments: \(arguments)")
        }
        
        // Parse the JSON arguments
        guard let argumentData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any]
        else {
            await MainActor.run {
                logger.error("Failed to parse arguments for tool \(name): \(arguments)")
            }
            return self.createErrorOutput("Invalid arguments: \(arguments)")
        }
        
        do {
            let startTime = Date()
            
            // Execute tool based on name
            let result: String
            switch name {
            case "see":
                result = try await self.executeSee(args: args)
                
            case "click":
                result = try await self.executeClick(args: args)
                
            case "type":
                result = try await self.executeType(args: args)
                
            case "hotkey":
                result = try await self.executeHotkey(args: args)
                
            case "list":
                result = try await self.executeList(args: args)
                
            case "window":
                result = try await self.executeWindow(args: args)
                
            case "app":
                result = try await self.executeApp(args: args)
                
            case "wait":
                result = try await self.executeWait(args: args)
                
            case "menu":
                result = try await self.executeMenu(args: args)
                
            case "image":
                result = try await self.executeImage(args: args)
                
            case "scroll":
                result = try await self.executeScroll(args: args)
                
            case "drag":
                result = try await self.executeDrag(args: args)
                
            case "swipe":
                result = try await self.executeSwipe(args: args)
                
            case "dialog":
                result = try await self.executeDialog(args: args)
                
            case "dock":
                result = try await self.executeDock(args: args)
                
            case "move":
                result = try await self.executeMove(args: args)
                
            case "sleep":
                result = try await self.executeSleep(args: args)
                
            case "analyze":
                result = try await self.executeAnalyze(args: args)
                
            case "permissions":
                result = try await self.executePermissions(args: args)
                
            case "shell":
                result = try await self.executeShell(args: args)
                
            default:
                await MainActor.run {
                    logger.error("Unknown tool requested: \(name)")
                }
                return self.createErrorOutput("Unknown tool: \(name)")
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            await MainActor.run {
                logger.info("✅ Tool \(name) completed in \(String(format: "%.2f", executionTime))s")
                logger.debug("Result preview: \(result.prefix(200))...")
            }
            
            return result
        } catch {
            await MainActor.run {
                logger.error("❌ Tool \(name) failed: \(error.localizedDescription)")
            }
            return self.createErrorOutput(error.localizedDescription)
        }
    }
    
    // MARK: - Tool Implementations
    
    private func executeSee(args: [String: Any]) async throws -> String {
        let sessionId = args["session_id"] as? String ?? UUID().uuidString
        await MainActor.run {
            logger.info("Executing 'see' command with session: \(sessionId)")
        }
        
        // Determine what to capture
        let captureResult: CaptureResult
        if let appName = args["app"] as? String {
            await MainActor.run {
                logger.debug("Capturing window for app: \(appName)")
            }
            captureResult = try await services.screenCapture.captureWindow(
                appIdentifier: appName,
                windowIndex: nil
            )
        } else {
            await MainActor.run {
                logger.debug("Capturing frontmost window")
            }
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        // Detect elements
        await MainActor.run {
            logger.debug("Detecting UI elements in captured image")
        }
        let detectionResult = try await services.automation.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId
        )
        await MainActor.run {
            logger.info("Detected \(detectionResult.elements.all.count) elements")
        }
        
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
            "app_name": captureResult.metadata.applicationInfo?.name ?? "Unknown",
            "window_title": captureResult.metadata.windowInfo?.title ?? "",
            "elements": detectionResult.elements.all.map { element in
                [
                    "id": element.id,
                    "type": element.type.rawValue,
                    "label": element.label ?? "",
                    "bounds": [
                        "x": element.bounds.minX,
                        "y": element.bounds.minY,
                        "width": element.bounds.width,
                        "height": element.bounds.height
                    ],
                    "properties": element.attributes
                ]
            }
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeClick(args: [String: Any]) async throws -> String {
        let providedSessionId = args["session_id"] as? String
        let sessionId: String?
        if let provided = providedSessionId {
            sessionId = provided
        } else {
            sessionId = await services.sessions.getMostRecentSession()
        }
        let delay = args["delay"] as? Double
        
        await MainActor.run {
            logger.info("Executing 'click' command")
            if let sessionId = sessionId {
                logger.debug("Using session: \(sessionId)")
            }
        }
        
        // Add delay if specified
        if let delay = delay {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        let clickType = ClickType.single // Default to single click
        
        if let elementId = args["element_id"] as? String ?? args["element"] as? String {
            await MainActor.run {
                logger.debug("Clicking on element: \(elementId)")
            }
            try await services.automation.click(
                target: .elementId(elementId),
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
            
            await MainActor.run {
                logger.debug("Clicking at coordinates: (\(x), \(y))")
            }
            try await services.automation.click(
                target: .coordinates(CGPoint(x: x, y: y)),
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
        
        await MainActor.run {
            logger.info("Executing 'type' command")
            logger.debug("Text length: \(text.count) chars, clear first: \(clearFirst)")
        }
        
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
        
        await MainActor.run {
            logger.info("Executing 'hotkey' command: \(keys)")
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
        
        await MainActor.run {
            logger.info("Executing 'list' command for target: \(target)")
        }
        
        let response: [String: Any]
        
        switch target {
        case "apps":
            let apps = try await services.applications.listApplications()
            await MainActor.run {
                logger.debug("Found \(apps.count) applications")
            }
            response = [
                "success": true,
                "apps": apps.map { app in
                    [
                        "name": app.name,
                        "bundle_id": app.bundleIdentifier ?? "",
                        "pid": app.processIdentifier,
                        "is_active": app.isActive,
                        "is_hidden": app.isHidden
                    ]
                }
            ]
            
        case "windows":
            let appName = args["app"] as? String
            if let appName = appName {
                await MainActor.run {
                    logger.debug("Listing windows for app: \(appName)")
                }
            }
            let windows = if let appName = appName {
                try await services.windows.listWindows(target: .application(appName))
            } else {
                try await services.windows.listWindows(target: .frontmost)
            }
            await MainActor.run {
                logger.debug("Found \(windows.count) windows")
            }
            response = [
                "success": true,
                "windows": windows.map { window in
                    [
                        "title": window.title,
                        "index": window.index,
                        "bounds": [
                            "x": window.bounds.minX,
                            "y": window.bounds.minY,
                            "width": window.bounds.width,
                            "height": window.bounds.height
                        ],
                        "is_minimized": window.isMinimized,
                        "is_main": window.isMainWindow
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
        
        await MainActor.run {
            logger.info("Executing 'window' command with action: \(action)")
            if let appName = appName {
                logger.debug("Target app: \(appName)")
            }
            if let title = title {
                logger.debug("Target window: \(title)")
            }
        }
        
        switch action {
        case "close":
            let target = self.determineWindowTarget(appName: appName, title: title)
            try await services.windows.closeWindow(target: target)
            
        case "minimize":
            let target = self.determineWindowTarget(appName: appName, title: title)
            try await services.windows.minimizeWindow(target: target)
            
        case "maximize":
            let target = self.determineWindowTarget(appName: appName, title: title)
            try await services.windows.maximizeWindow(target: target)
            
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
            let target = self.determineWindowTarget(appName: appName, title: title)
            try await services.windows.moveWindow(target: target, to: CGPoint(x: x, y: y))
            
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
            let target = self.determineWindowTarget(appName: appName, title: title)
            try await services.windows.resizeWindow(target: target, to: CGSize(width: width, height: height))
            
        case "focus":
            let target = self.determineWindowTarget(appName: appName, title: title)
            try await services.windows.focusWindow(target: target)
            
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
        
        await MainActor.run {
            logger.info("Executing 'app' command: \(action) for app: \(appName)")
        }
        
        switch action {
        case "launch":
            _ = try await services.applications.launchApplication(identifier: appName)
            
        case "quit":
            let _ = try await services.applications.quitApplication(identifier: appName, force: false)
            
        case "focus":
            try await services.applications.activateApplication(identifier: appName)
            
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
        
        await MainActor.run {
            logger.info("Executing 'wait' command for \(seconds) seconds")
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
        
        await MainActor.run {
            logger.info("Executing 'menu' command: \(action) for app: \(appName)")
        }
        
        switch action {
        case "list":
            let menuStructure = try await services.menu.listMenus(for: appName)
            await MainActor.run {
                logger.debug("Found \(menuStructure.menus.count) menus")
            }
            let response: [String: Any] = [
                "success": true,
                "app_name": menuStructure.application.name,
                "menus": menuStructure.menus.map { menu in
                    [
                        "title": menu.title,
                        "enabled": menu.isEnabled,
                        "items": self.formatMenuItems(menu.items)
                    ]
                }
            ]
            return try self.createJSONOutput(response)
            
        case "click":
            guard let menuPath = args["menu_path"] as? String else {
                throw PeekabooError.invalidInput("Menu path is required for click action")
            }
            await MainActor.run {
                logger.debug("Clicking menu item: \(menuPath)")
            }
            try await services.menu.clickMenuItem(app: appName, itemPath: menuPath)
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
        await MainActor.run {
            logger.info("Executing 'image' command")
        }
        
        let captureResult: CaptureResult
        
        if let appName = args["app"] as? String {
            let windowIndex = args["window_index"] as? Int
            await MainActor.run {
                logger.debug("Capturing window for app: \(appName), index: \(windowIndex ?? 0)")
            }
            captureResult = try await services.screenCapture.captureWindow(
                appIdentifier: appName,
                windowIndex: windowIndex
            )
        } else if let screenIndex = args["screen_index"] as? Int {
            await MainActor.run {
                logger.debug("Capturing screen at index: \(screenIndex)")
            }
            captureResult = try await services.screenCapture.captureScreen(displayIndex: screenIndex)
        } else {
            // Default to frontmost window
            await MainActor.run {
                logger.debug("Capturing frontmost window")
            }
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        await MainActor.run {
            logger.info("Image captured successfully: \(captureResult.savedPath ?? "<unsaved>")")
        }
        
        let response: [String: Any] = [
            "success": true,
            "path": captureResult.savedPath ?? "",
            "app_name": captureResult.metadata.applicationInfo?.name ?? "Unknown",
            "window_title": captureResult.metadata.windowInfo?.title ?? "",
            "width": Int(captureResult.metadata.size.width),
            "height": Int(captureResult.metadata.size.height)
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeScroll(args: [String: Any]) async throws -> String {
        let directionString = args["direction"] as? String ?? "down"
        let amount = args["amount"] as? Int ?? 5
        let sessionId = args["session_id"] as? String
        let target = args["element_id"] as? String
        
        await MainActor.run {
            logger.info("Executing 'scroll' command: \(directionString) by \(amount) units")
            if let target = target {
                logger.debug("Target element: \(target)")
            }
        }
        
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
        
        await MainActor.run {
            logger.info("Executing 'drag' command with duration: \(duration)s")
        }
        
        // Variables will be defined below
        
        // Parse from coordinates
        let fromPoint: CGPoint
        if let fromPosition = args["from_position"] as? String {
            await MainActor.run {
                logger.debug("Drag from position: \(fromPosition)")
            }
            let components = fromPosition.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid from_position format: \(fromPosition)")
            }
            fromPoint = CGPoint(x: x, y: y)
        } else if let fromElementId = args["from_element_id"] as? String,
                  let sessionId = sessionId,
                  let result = try? await services.sessions.getDetectionResult(sessionId: sessionId),
                  let element = result.elements.all.first(where: { $0.id == fromElementId }) {
            await MainActor.run {
                logger.debug("Drag from element: \(fromElementId)")
            }
            fromPoint = CGPoint(
                x: element.bounds.midX,
                y: element.bounds.midY
            )
        } else {
            throw PeekabooError.invalidInput("Either from_element_id or from_position is required")
        }
        
        // Parse to coordinates
        let toPoint: CGPoint
        if let toPosition = args["to_position"] as? String {
            await MainActor.run {
                logger.debug("Drag to position: \(toPosition)")
            }
            let components = toPosition.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid to_position format: \(toPosition)")
            }
            toPoint = CGPoint(x: x, y: y)
        } else if let toElementId = args["to_element_id"] as? String,
                  let sessionId = sessionId,
                  let result = try? await services.sessions.getDetectionResult(sessionId: sessionId),
                  let element = result.elements.all.first(where: { $0.id == toElementId }) {
            await MainActor.run {
                logger.debug("Drag to element: \(toElementId)")
            }
            toPoint = CGPoint(
                x: element.bounds.midX,
                y: element.bounds.midY
            )
        } else {
            throw PeekabooError.invalidInput("Either to_element_id or to_position is required")
        }
        
        // Execute drag
        try await services.automation.drag(
            from: fromPoint,
            to: toPoint,
            duration: Int(duration * 1000),
            steps: 10,
            modifiers: nil
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
        
        await MainActor.run {
            logger.info("Executing 'swipe' command: \(directionString) for \(distance) points")
        }
        
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
            await MainActor.run {
                logger.debug("Swiping from element: \(elementId)")
            }
            // Get element center from session
            guard let sessionId = sessionId,
                  let result = try? await services.sessions.getDetectionResult(sessionId: sessionId),
                  let element = result.elements.all.first(where: { $0.id == elementId }) else {
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
            await MainActor.run {
                logger.debug("Swiping from position: (\(x), \(y))")
            }
        } else {
            // Default to center of screen
            startPoint = CGPoint(x: 500, y: 500) // This should be improved to get actual screen center
            await MainActor.run {
                logger.debug("Using default center position for swipe")
            }
        }
        
        // Calculate end point based on direction and distance
        let endPoint: CGPoint
        switch direction {
        case .up:
            endPoint = CGPoint(x: startPoint.x, y: startPoint.y - CGFloat(distance))
        case .down:
            endPoint = CGPoint(x: startPoint.x, y: startPoint.y + CGFloat(distance))
        case .left:
            endPoint = CGPoint(x: startPoint.x - CGFloat(distance), y: startPoint.y)
        case .right:
            endPoint = CGPoint(x: startPoint.x + CGFloat(distance), y: startPoint.y)
        }
        
        // Execute swipe as a drag operation
        try await services.automation.swipe(
            from: startPoint,
            to: endPoint,
            duration: Int(duration * 1000),
            steps: 20
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
        
        await MainActor.run {
            logger.info("Executing 'dialog' command with action: \(action)")
            if let buttonText = buttonText {
                logger.debug("Target button: \(buttonText)")
            }
        }
        
        switch action {
        case "accept":
            if let buttonText = buttonText {
                _ = try await services.dialogs.clickButton(buttonText: buttonText, windowTitle: nil)
            } else {
                // Click the default OK/Yes button
                _ = try await services.dialogs.clickButton(buttonText: "OK", windowTitle: nil)
            }
        case "dismiss":
            if let buttonText = buttonText {
                _ = try await services.dialogs.clickButton(buttonText: buttonText, windowTitle: nil)
            } else {
                // Dismiss using force (ESC key)
                _ = try await services.dialogs.dismissDialog(force: true, windowTitle: nil)
            }
        case "input":
            guard let text = args["text"] as? String else {
                throw PeekabooError.invalidInput("Text parameter is required for input action")
            }
            await MainActor.run {
                logger.debug("Entering text into dialog: \(text.prefix(50))...")
            }
            _ = try await services.dialogs.enterText(text: text, fieldIdentifier: nil, clearExisting: true, windowTitle: nil)
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
        await MainActor.run {
            logger.info("Executing 'dock' command")
        }
        
        if let action = args["action"] as? String, action == "list" {
            await MainActor.run {
                logger.debug("Listing dock items")
            }
            let items = try await services.dock.listDockItems(includeAll: false)
            await MainActor.run {
                logger.debug("Found \(items.count) dock items")
            }
            let response: [String: Any] = [
                "success": true,
                "dock_items": items.map { item in
                    [
                        "title": item.title,
                        "type": item.itemType.rawValue,
                        "bundle_id": item.bundleIdentifier ?? "",
                        "is_running": item.isRunning ?? false
                    ]
                }
            ]
            return try self.createJSONOutput(response)
        } else if let appName = args["app"] as? String {
            await MainActor.run {
                logger.debug("Launching app from dock: \(appName)")
            }
            try await services.dock.launchFromDock(appName: appName)
            let response: [String: Any] = [
                "success": true,
                "message": "Clicked dock item: \(appName)"
            ]
            return try self.createJSONOutput(response)
        } else {
            throw PeekabooError.invalidInput("Either action='list' or app parameter is required")
        }
    }
    
    private func executeMove(args: [String: Any]) async throws -> String {
        await MainActor.run {
            logger.info("Executing 'move' command")
        }
        
        let toPoint: CGPoint
        let sessionId = args["session_id"] as? String
        
        if let position = args["position"] as? String {
            await MainActor.run {
                logger.debug("Moving to position: \(position)")
            }
            let components = position.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1]) else {
                throw PeekabooError.invalidInput("Invalid position format: \(position)")
            }
            toPoint = CGPoint(x: x, y: y)
        } else if let elementId = args["element_id"] as? String {
            await MainActor.run {
                logger.debug("Moving to element: \(elementId)")
            }
            guard let sessionId = sessionId,
                  let result = try? await services.sessions.getDetectionResult(sessionId: sessionId),
                  let element = result.elements.all.first(where: { $0.id == elementId }) else {
                throw PeekabooError.elementNotFound(elementId)
            }
            toPoint = CGPoint(
                x: element.bounds.midX,
                y: element.bounds.midY
            )
        } else if let text = args["text"] as? String, let sessionId = sessionId {
            await MainActor.run {
                logger.debug("Moving to text: \(text)")
            }
            // Find element by text
            guard let result = try? await services.sessions.getDetectionResult(sessionId: sessionId),
                  let element = result.elements.all.first(where: { ($0.label ?? "").contains(text) }) else {
                throw PeekabooError.elementNotFound("Element with text: \(text)")
            }
            toPoint = CGPoint(
                x: element.bounds.midX,
                y: element.bounds.midY
            )
        } else {
            throw PeekabooError.invalidInput("Either position, element_id, or text is required")
        }
        
        // Move mouse to position
        try await services.automation.moveMouse(to: toPoint, duration: 0, steps: 1)
        
        let response: [String: Any] = [
            "success": true,
            "message": "Mouse moved to (\(Int(toPoint.x)), \(Int(toPoint.y)))"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeSleep(args: [String: Any]) async throws -> String {
        let duration = args["duration"] as? Double ?? 1.0
        
        await MainActor.run {
            logger.info("Executing 'sleep' command for \(duration) seconds")
        }
        
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        let response: [String: Any] = [
            "success": true,
            "message": "Slept for \(duration) seconds"
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeAnalyze(args: [String: Any]) async throws -> String {
        guard let imagePath = args["image_path"] as? String else {
            throw PeekabooError.invalidInput("Image path is required")
        }
        
        let prompt = args["prompt"] as? String ?? "What is shown in this image?"
        let providerName = args["provider"] as? String
        
        await MainActor.run {
            logger.info("Executing 'analyze' command on image: \(imagePath)")
            logger.debug("Prompt: \(prompt)")
        }
        
        // Read image data
        let url = URL(fileURLWithPath: (imagePath as NSString).expandingTildeInPath)
        guard let imageData = try? Data(contentsOf: url),
              let base64String = imageData.base64EncodedString() as String? else {
            throw PeekabooError.invalidInput("Failed to read image at path: \(imagePath)")
        }
        
        // Get AI providers from environment or use default
        let providerList = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"] ?? "openai/gpt-4o,ollama/llava:latest"
        let providers = AIProviderFactory.createProviders(from: providerList)
        
        // Try to use specific provider if requested
        var analysisResult: String?
        var usedProvider: String?
        var usedModel: String?
        
        if let providerName = providerName,
           let provider = providers.first(where: { $0.name.lowercased() == providerName.lowercased() }) {
            do {
                analysisResult = try await provider.analyze(imageBase64: base64String, question: prompt)
                usedProvider = provider.name
                usedModel = provider.model
            } catch {
                await MainActor.run {
                    logger.error("Provider \(providerName) failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Fall back to trying all providers
        if analysisResult == nil {
            for provider in providers {
                if await provider.isAvailable {
                    do {
                        analysisResult = try await provider.analyze(imageBase64: base64String, question: prompt)
                        usedProvider = provider.name
                        usedModel = provider.model
                        break
                    } catch {
                        await MainActor.run {
                            logger.warning("Provider \(provider.name) failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        guard let result = analysisResult,
              let provider = usedProvider,
              let model = usedModel else {
            throw PeekabooError.invalidInput("No AI provider available to analyze image")
        }
        
        await MainActor.run {
            logger.info("Analysis completed successfully with \(provider)/\(model)")
            logger.debug("Result preview: \(result.prefix(200))...")
        }
        
        let response: [String: Any] = [
            "success": true,
            "analysis": result,
            "provider": provider,
            "model": model
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executePermissions(args: [String: Any]) async throws -> String {
        await MainActor.run {
            logger.info("Executing 'permissions' command")
        }
        
        // Check screen recording permission
        let hasScreenRecording = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) != nil
        
        // Check accessibility permission  
        let hasAccessibility = AXIsProcessTrusted()
        
        await MainActor.run {
            logger.debug("Permission check completed - Screen Recording: \(hasScreenRecording), Accessibility: \(hasAccessibility)")
        }
        
        let response: [String: Any] = [
            "success": true,
            "permissions": [
                "screen_recording": [
                    "status": hasScreenRecording ? "authorized" : "denied",
                    "message": hasScreenRecording ? "Screen Recording permission is granted" : "Screen Recording permission is required"
                ],
                "accessibility": [
                    "status": hasAccessibility ? "authorized" : "denied",  
                    "message": hasAccessibility ? "Accessibility permission is granted" : "Accessibility permission is required"
                ]
            ]
        ]
        
        return try self.createJSONOutput(response)
    }
    
    private func executeShell(args: [String: Any]) async throws -> String {
        guard let command = args["command"] as? String else {
            throw PeekabooError.invalidInput("Command parameter is required")
        }
        
        let timeout = args["timeout"] as? Int ?? 30
        
        await MainActor.run {
            logger.info("Executing 'shell' command: \(command)")
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
            throw PeekabooError.invalidInput("Failed to execute shell command: \(error.localizedDescription)")
        }
        
        // Wait for completion with timeout
        let startTime = Date()
        while process.isRunning && Date().timeIntervalSince(startTime) < Double(timeout) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        if process.isRunning {
            process.terminate()
            throw PeekabooError.invalidInput("Shell command timed out after \(timeout) seconds")
        }
        
        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        await MainActor.run {
            logger.info("Shell command completed with exit code: \(process.terminationStatus)")
            if !output.isEmpty {
                logger.debug("Output: \(output.prefix(500))...")
            }
            if !errorOutput.isEmpty {
                logger.debug("Error output: \(errorOutput.prefix(500))...")
            }
        }
        
        // Prepare response based on exit code
        let response: [String: Any]
        if process.terminationStatus == 0 {
            response = [
                "success": true,
                "output": output,
                "error_output": errorOutput,
                "exit_code": 0,
                "command": command
            ]
        } else {
            // Still return success: true but include the error details
            response = [
                "success": true,
                "output": output,
                "error_output": errorOutput,
                "exit_code": Int(process.terminationStatus),
                "command": command,
                "error": [
                    "code": "SHELL_COMMAND_FAILED",
                    "message": "Command exited with code \(process.terminationStatus)"
                ]
            ]
        }
        
        return try self.createJSONOutput(response)
    }
    
    // MARK: - Helper Methods
    
    private func determineWindowTarget(appName: String?, title: String?) -> WindowTarget {
        if let title = title {
            return .title(title)
        } else if let appName = appName {
            return .application(appName)
        } else {
            return .frontmost
        }
    }
    
    private func formatMenuItems(_ items: [MenuItem]) -> [[String: Any]] {
        items.map { item in
            var dict: [String: Any] = [
                "title": item.title,
                "path": item.path,
                "enabled": item.isEnabled,
                "has_submenu": !item.submenu.isEmpty
            ]
            if let shortcut = item.keyboardShortcut {
                dict["shortcut"] = shortcut.displayString
            }
            if !item.submenu.isEmpty {
                dict["children"] = formatMenuItems(item.submenu)
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
            self.makePeekabooTool("move", "Move mouse cursor to specific location"),
            self.makePeekabooTool("sleep", "Pause execution for specified duration"),
            self.makePeekabooTool("analyze", "Analyze images using AI vision models"),
            self.makePeekabooTool("permissions", "Check system permissions status"),
            self.makePeekabooTool("shell", "Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)"),
        ]
    }
    
    nonisolated func systemPrompt() -> String {
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
        - 'see': Capture screenshots and map UI elements
          The see command also extracts menu bar information showing available menus
        - 'analyze': Analyze any screenshot with vision AI to understand UI elements and content
        - 'image': Take screenshots of specific apps or screens

        UI INTERACTION:
        - 'click': Click on elements or coordinates
        - 'type': Type text into the currently focused element (no element parameter needed)
          NOTE: To press Enter after typing, use a separate 'hotkey' command with "return"
          For efficiency, group related actions when possible
        - 'scroll': Scroll in any direction
        - 'hotkey': Press keyboard shortcuts - provide keys as string: "cmd+s" or "cmd+shift+d"
          Common: "return" for Enter, "tab" for Tab, "escape" for Escape
        - 'drag': Drag and drop between elements
        - 'swipe': Perform swipe gestures

        APPLICATION CONTROL:
        - 'app': Launch, quit, focus, hide, or unhide applications
        - 'window': Close, minimize, maximize, move, resize, or focus windows
        - 'menu': Menu bar interaction - action='list' to discover menus, action='click' to click items
          Example: menu(action="list", app="Calculator") to list all menus
          Note: Use plain ellipsis "..." instead of Unicode "…" in menu paths (e.g., "Save..." not "Save…")
        - 'dock': Interact with Dock items
        - 'dialog': Handle system dialogs and alerts

        DISCOVERY & UTILITY:
        - 'list': List running apps or windows - USE THIS TO LIST APPLICATIONS!
        - 'wait': Pause execution for specified duration - AVOID USING THIS unless absolutely necessary
          Instead of waiting, use 'see' again if content seems to be loading
        - 'shell': Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)

        When given a task:
        1. **TO LIST APPLICATIONS**: Use 'list' with target='apps' - DO NOT use Activity Monitor or screenshots!
        2. **TO LIST WINDOWS**: Use 'list' with target='windows' and app='AppName'
        3. **TO DISCOVER MENUS**: Use 'menu' with action='list' and app='AppName' to get full menu structure OR 'see' command which includes basic menu_bar data
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
        
        IMPORTANT APP BEHAVIORS & OPTIMIZATIONS:
        - ALWAYS check window_count in app launch response BEFORE any other action
        - Safari launch pattern:
          1. Launch Safari and check window_count
          2. If window_count = 0, wait ONE second (agent processing time), then try 'see' ONCE
          3. If 'see' still fails, use 'app' focus command, then 'hotkey' "cmd+n" ONCE
          4. Do NOT repeat the see/cmd+n pattern multiple times
        - STOP trying if a window is created - one window is enough
        - Browser windows may take 1-2 seconds to fully appear after launch
        - NEVER use 'wait' commands - the agent processing time provides natural delays
        - If content appears to be loading, use 'see' again instead of 'wait'
        - BE EFFICIENT: Minimize redundant commands and retries
        
        SAVING FILES:
        - After opening Save dialog, type the filename then use 'hotkey' with "cmd+s" or "return" to save
        - To navigate to Desktop in save dialog: use 'hotkey' with "cmd+shift+d"

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
        3. Use 'see' to read the search results
        4. Extract and report the relevant information
        
        ALTERNATIVE METHOD - Manual browser control:
        1. First check for running browsers using: list(target="apps")
           Common browsers: Safari, Google Chrome, Firefox, Arc, Brave, Microsoft Edge, Opera
        2. If a browser is running:
           - Focus it using: app(action="focus", app="BrowserName")
           - Open new tab: hotkey(keys="cmd+t")
        3. If no browser is running:
           - Try launching browsers OR use shell(command="open https://...")
        4. Once browser window is open:
           - Navigate to address bar: hotkey(keys="cmd+l")
           - Type your search query
           - Press Enter: hotkey(keys="return")
        
        SHELL COMMAND USAGE:
        - shell(command="open https://google.com") - Opens URL in default browser
        - shell(command="open -a Safari https://example.com") - Opens in specific browser
        - shell(command="curl -s https://api.example.com") - Fetch API data directly
        - shell(command="echo 'Hello World'") - Run any shell command
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
                    "element": Property(type: "string", description: "Element ID from 'see' command (e.g., 'B1', 'T2')"),
                    "element_id": Property(type: "string", description: "Alternative name for element ID"),
                    "position": Property(type: "string", description: "x,y coordinates as alternative to element"),
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
            
        case "move":
            FunctionParameters(
                properties: [
                    "position": Property(type: "string", description: "Target position (x,y)"),
                    "element_id": Property(type: "string", description: "Element ID to move to"),
                    "text": Property(type: "string", description: "Text to find and move to"),
                    "session_id": Property(type: "string", description: "Session ID for element lookup"),
                ],
                required: [])
            
        case "sleep":
            FunctionParameters(
                properties: [
                    "duration": Property(type: "number", description: "Duration to sleep in seconds"),
                ],
                required: ["duration"])
            
        case "analyze":
            FunctionParameters(
                properties: [
                    "image_path": Property(type: "string", description: "Path to image file to analyze"),
                    "prompt": Property(type: "string", description: "Question or prompt about the image"),
                    "provider": Property(type: "string", description: "AI provider to use (optional)"),
                ],
                required: ["image_path"])
            
        case "permissions":
            FunctionParameters(
                properties: [:],
                required: [])
            
        case "shell":
            FunctionParameters(
                properties: [
                    "command": Property(type: "string", description: "Shell command to execute (e.g., 'open https://google.com', 'ls -la', 'echo Hello')"),
                    "timeout": Property(type: "integer", description: "Command timeout in seconds (default: 30)"),
                ],
                required: ["command"])
            
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