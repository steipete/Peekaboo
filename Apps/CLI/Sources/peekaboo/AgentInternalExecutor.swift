import AppKit
import AXorcist
import Foundation
import PeekabooCore

/// Internal executor for agent commands that uses native functions instead of CLI
@available(macOS 14.0, *)
struct AgentInternalExecutor {
    let verbose: Bool
    let sessionManager = SessionManager.shared

    /// Execute a Peekaboo function and return JSON response
    func executeFunction(name: String, arguments: String) async throws -> String {
        // Parse the function name
        let commandName = name.replacingOccurrences(of: "peekaboo_", with: "")

        // Agent executing function

        // Parse JSON arguments
        guard let argsData = arguments.data(using: .utf8) else {
            // Failed to convert arguments to UTF-8 data
            return self.createErrorJSON(.invalidArguments("Invalid UTF-8 string"))
        }

        let args: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                return self.createErrorJSON(.invalidArguments("Arguments must be a JSON object"))
            }
            args = parsed
        } catch {
            // Failed to parse JSON arguments
            return self.createErrorJSON(.invalidArguments("Failed to parse JSON: \(error.localizedDescription)"))
        }

        // Log parsed arguments
        // Parsed arguments

        // Log execution if verbose (keep terminal output for compatibility)
        if self.verbose {
            print("🔧 Executing: \(commandName) with args: \(arguments)")
        }

        // Execute the appropriate function
        do {
            // Starting execution of command
            let startTime = Date()

            let result = try await executeInternalFunction(command: commandName, args: args)

            _ = Date().timeIntervalSince(startTime)
            // Command completed successfully

            if self.verbose {
                print("   ✅ Result: \(result.prefix(200))...")
            }
            return result
        } catch {
            // Command failed
            return self.createErrorJSON(.commandFailed(error.localizedDescription))
        }
    }

    @MainActor
    private func executeInternalFunction(command: String, args: [String: Any]) async throws -> String {
        // Routing to command handler

        switch command {
        case "see":
            return try await self.executeSee(args: args)

        case "click":
            return try await self.executeClick(args: args)

        case "type":
            return try await self.executeType(args: args)

        case "app":
            return try await self.executeApp(args: args)

        case "window":
            return try await self.executeWindow(args: args)

        case "image":
            return try await self.executeImage(args: args)

        case "wait", "sleep":
            return try await self.executeWait(args: args)

        case "hotkey":
            return try await self.executeHotkey(args: args)

        case "scroll":
            return try await self.executeScroll(args: args)

        case "analyze_screenshot":
            return try await self.executeAnalyzeScreenshot(args: args)

        case "list":
            return try await self.executeList(args: args)

        default:
            // Unknown command received
            throw AgentError.invalidArguments("Unknown command: \(command)")
        }
    }

    // MARK: - Command Implementations

    @MainActor
    private func executeSee(args: [String: Any]) async throws -> String {
        // Use PeekabooServices directly instead of command structs
        let services = PeekabooServices.shared
        
        do {
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
                throw AgentError.commandFailed("Failed to save screenshot: \(error)")
            }
            
            // Create session and detect elements
            let sessionId = try await services.sessions.createSession()
            let detectionResult = try await services.automation.detectElements(
                in: captureResult.imageData,
                sessionId: nil
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
            
            let responseData: [String: Any] = [
                "screenshot_raw": screenshotPath,
                "session_id": sessionId,
                "elements": elements
            ]
            
            let response: [String: Any] = [
                "success": true,
                "data": responseData
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }

    }

    @MainActor
    private func executeClick(args: [String: Any]) async throws -> String {
        let services = PeekabooServices.shared
        
        do {
            // Determine click target
            let clickTarget: ClickTarget
            if let element = args["element"] as? String {
                clickTarget = .elementId(element)
            } else if let x = args["x"] as? Double, let y = args["y"] as? Double {
                clickTarget = .coordinates(CGPoint(x: x, y: y))
            } else {
                throw AgentError.invalidArguments("Click requires either 'element' or 'x,y' coordinates")
            }
            
            // Get click type
            let clickType: ClickType = (args["double_click"] as? Bool ?? false) ? .double : .single
            
            // Get session ID
            let sessionId = args["session_id"] as? String
            
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
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    @MainActor
    private func executeType(args: [String: Any]) async throws -> String {
        let services = PeekabooServices.shared
        
        do {
            guard let text = args["text"] as? String else {
                throw AgentError.invalidArguments("Type command requires 'text' parameter")
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
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    @MainActor
    private func executeApp(args: [String: Any]) async throws -> String {
        let services = PeekabooServices.shared
        
        do {
            guard let action = args["action"] as? String,
                  let name = args["name"] as? String
            else {
                throw AgentError.invalidArguments("App command requires 'action' and 'name' parameters")
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
                throw AgentError.invalidArguments("Unknown app action: \(action)")
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
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    @MainActor
    private func executeWindow(args: [String: Any]) async throws -> String {
        // Log removed

        guard let action = args["action"] as? String else {
            // Log removed
            throw AgentError.invalidArguments("Window command requires 'action' parameter")
        }

        // Log removed")

        // All window subcommands share these common parameters
        let app = args["app"] as? String
        let title = args["title"] as? String

        switch action {
        case "close":
            var closeCommand = CloseSubcommand()
            closeCommand.windowOptions.app = app
            closeCommand.windowOptions.windowTitle = title
            closeCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await closeCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("Window closed") : result

        case "minimize":
            var minimizeCommand = MinimizeSubcommand()
            minimizeCommand.windowOptions.app = app
            minimizeCommand.windowOptions.windowTitle = title
            minimizeCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await minimizeCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("Window minimized") : result

        case "maximize":
            var maximizeCommand = MaximizeSubcommand()
            maximizeCommand.windowOptions.app = app
            maximizeCommand.windowOptions.windowTitle = title
            maximizeCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await maximizeCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("Window maximized") : result

        case "focus":
            var focusCommand = FocusSubcommand()
            focusCommand.windowOptions.app = app
            focusCommand.windowOptions.windowTitle = title
            focusCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await focusCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("Window focused") : result

        case "move":
            var moveCommand = MoveSubcommand()
            moveCommand.windowOptions.app = app
            moveCommand.windowOptions.windowTitle = title
            if let x = args["x"] as? Double {
                moveCommand.x = Int(x)
            } else {
                throw AgentError.invalidArguments("Move command requires 'x' parameter")
            }
            if let y = args["y"] as? Double {
                moveCommand.y = Int(y)
            } else {
                throw AgentError.invalidArguments("Move command requires 'y' parameter")
            }
            moveCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await moveCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("Window moved") : result

        case "resize":
            var resizeCommand = ResizeSubcommand()
            resizeCommand.windowOptions.app = app
            resizeCommand.windowOptions.windowTitle = title
            if let width = args["width"] as? Double {
                resizeCommand.width = Int(width)
            } else {
                throw AgentError.invalidArguments("Resize command requires 'width' parameter")
            }
            if let height = args["height"] as? Double {
                resizeCommand.height = Int(height)
            } else {
                throw AgentError.invalidArguments("Resize command requires 'height' parameter")
            }
            resizeCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await resizeCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("Window resized") : result

        default:
            throw AgentError.invalidArguments("Unknown window action: \(action)")
        }
    }

    @MainActor
    private func executeImage(args: [String: Any]) async throws -> String {
        // Log removed
        var imageCommand = ImageCommand()

        // Set parameters
        if let app = args["app"] as? String {
            imageCommand.app = app
        }
        if let mode = args["mode"] as? String {
            imageCommand.mode = CaptureMode(rawValue: mode)
        }
        if let path = args["path"] as? String {
            imageCommand.path = path
        }
        if let format = args["format"] as? String, let imageFormat = ImageFormat(rawValue: format) {
            imageCommand.format = imageFormat
        }

        imageCommand.jsonOutput = true

        // Capture output
        let output = CaptureOutput()
        output.start()

        do {
            try await imageCommand.run()
        } catch {
            _ = output.stop()
            throw error
        }

        let result = output.stop()
        return result.isEmpty ? self.createSuccessJSON("Image captured") : result
    }

    @MainActor
    private func executeWait(args: [String: Any]) async throws -> String {
        guard let duration = args["duration"] as? Double else {
            throw AgentError.invalidArguments("Wait command requires 'duration' parameter")
        }

        // Convert seconds to nanoseconds
        let nanoseconds = UInt64(duration * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)

        return self.createSuccessJSON("Waited for \(duration) seconds")
    }

    @MainActor
    private func executeHotkey(args: [String: Any]) async throws -> String {
        let services = PeekabooServices.shared
        
        do {
            let keys: [String]
            if let keysArray = args["keys"] as? [String] {
                keys = keysArray
            } else if let keysString = args["keys"] as? String {
                keys = keysString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            } else {
                throw AgentError.invalidArguments("Hotkey command requires 'keys' (array or string)")
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
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    @MainActor
    private func executeScroll(args: [String: Any]) async throws -> String {
        let services = PeekabooServices.shared
        
        do {
            let direction = PeekabooCore.ScrollDirection(rawValue: args["direction"] as? String ?? "down") ?? .down
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
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    @MainActor
    private func executeAnalyzeScreenshot(args: [String: Any]) async throws -> String {
        do {
            guard let screenshotPath = args["screenshot_path"] as? String else {
                throw AgentError.invalidArguments("analyze_screenshot requires 'screenshot_path' parameter")
            }
            
            let question = args["question"] as? String ?? "What is shown in this screenshot?"
            
            // Use the vision API to analyze the screenshot
            let analysis = try await analyzeWithVision(imagePath: screenshotPath, question: question)
            
            // Prepare response
            let response: [String: Any] = [
                "success": true,
                "data": [
                    "analysis": analysis,
                    "screenshot_path": screenshotPath,
                    "question": question
                ]
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    @MainActor
    private func executeList(args: [String: Any]) async throws -> String {
        let services = PeekabooServices.shared
        
        do {
            guard let target = args["target"] as? String else {
                throw AgentError.invalidArguments("List command requires 'target' parameter")
            }
            
            switch target {
            case "apps":
                let apps = try await services.applications.listApplications()
                let appData = apps.map { app -> [String: Any] in
                    return [
                        "name": app.name,
                        "bundleIdentifier": app.bundleIdentifier,
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
                
                if let data = try? JSONSerialization.data(withJSONObject: response),
                   let jsonString = String(data: data, encoding: .utf8) {
                    return jsonString
                }
                
            case "windows":
                let appName = args["app"] as? String
                guard let app = appName else {
                    throw AgentError.invalidArguments("List windows requires 'app' parameter")
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
                
                if let data = try? JSONSerialization.data(withJSONObject: response),
                   let jsonString = String(data: data, encoding: .utf8) {
                    return jsonString
                }
                
            default:
                throw AgentError.invalidArguments("Unknown list target: \(target)")
            }
            
            throw AgentError.commandFailed("Failed to serialize response")
        } catch {
            throw error
        }
    }

    // MARK: - Vision Analysis

    private func analyzeWithVision(imagePath: String, question: String) async throws -> String {
        // Get API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw AgentError.missingAPIKey
        }

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
            "model": "gpt-4o",
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
            throw AgentError.apiError("Vision API request failed")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AgentError.apiError("Failed to parse vision API response")
        }
        return content
    }

    // MARK: - Helper Functions

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

    private func createErrorJSON(_ error: AgentError) -> String {
        let response = createAgentErrorResponse(error)
        if let data = try? JSONEncoder().encode(response),
           let string = String(data: data, encoding: .utf8)
        {
            return string
        }

        return #"{"success": false, "error": {"message": "\#(error.localizedDescription)", "code": "\#(error.errorCode)"}}"#
    }
}

// MARK: - Output Capture

/// Helper class to capture stdout
final class CaptureOutput: @unchecked Sendable {
    private var pipe: Pipe?
    private var oldStdout: Int32?
    private var outputData = Data()
    private let lock = NSLock()

    func start() {
        pipe = Pipe()
        self.oldStdout = dup(STDOUT_FILENO)

        guard let pipe else { return }

        // Redirect stdout to our pipe
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        // Start reading from the pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.lock.lock()
            self?.outputData.append(data)
            self?.lock.unlock()
        }
    }

    func stop() -> String {
        guard let oldStdout else { return "" }

        // Restore stdout
        dup2(oldStdout, STDOUT_FILENO)
        close(oldStdout)

        // Close the pipe
        self.pipe?.fileHandleForWriting.closeFile()
        self.pipe?.fileHandleForReading.readabilityHandler = nil
        self.pipe?.fileHandleForReading.closeFile()

        // Return captured output
        self.lock.lock()
        let result = String(data: outputData, encoding: .utf8) ?? ""
        self.lock.unlock()
        return result
    }
}
