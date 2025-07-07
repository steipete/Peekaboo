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

        // Parse JSON arguments
        guard let argsData = arguments.data(using: .utf8) else {
            return self.createErrorJSON(.invalidArguments("Invalid UTF-8 string"))
        }

        let args: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                return self.createErrorJSON(.invalidArguments("Arguments must be a JSON object"))
            }
            args = parsed
        } catch {
            return self.createErrorJSON(.invalidArguments("Failed to parse JSON: \(error.localizedDescription)"))
        }

        // Log execution if verbose
        if self.verbose {
            print("🔧 Executing: \(commandName) with args: \(arguments)")
        }

        // Execute the appropriate function
        do {
            let result = try await executeInternalFunction(command: commandName, args: args)
            if self.verbose {
                print("   ✅ Result: \(result.prefix(200))...")
            }
            return result
        } catch {
            return self.createErrorJSON(.commandFailed(error.localizedDescription))
        }
    }

    @MainActor
    private func executeInternalFunction(command: String, args: [String: Any]) async throws -> String {
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

        default:
            throw AgentError.invalidArguments("Unknown command: \(command)")
        }
    }

    // MARK: - Command Implementations

    @MainActor
    private func executeSee(args: [String: Any]) async throws -> String {
        var seeCommand = SeeCommand()

        // Set parameters
        if let app = args["app"] as? String {
            seeCommand.app = app
        }
        if let windowTitle = args["window_title"] as? String {
            seeCommand.windowTitle = windowTitle
        }

        // Always use JSON output for agent
        seeCommand.jsonOutput = true

        // Capture output
        let output = CaptureOutput()
        output.start()

        do {
            try await seeCommand.run()
        } catch {
            _ = output.stop()
            throw error
        }

        let result = output.stop()

        // If we have a result, enhance it with vision analysis if requested
        if !result.isEmpty, let analyze = args["analyze"] as? Bool, analyze {
            // Parse the JSON to get the screenshot path
            if let data = result.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let resultData = json["data"] as? [String: Any],
               let screenshotPath = resultData["screenshot_raw"] as? String
            {
                // Analyze the screenshot
                if let analysis = try? await analyzeWithVision(
                    imagePath: screenshotPath,
                    question: "Describe what you see on the screen, including visible applications, windows, and UI elements")
                {
                    // Add analysis to the result
                    var enhancedJson = json
                    var enhancedData = resultData
                    enhancedData["vision_analysis"] = analysis
                    enhancedJson["data"] = enhancedData

                    if let enhancedResult = try? JSONSerialization.data(withJSONObject: enhancedJson),
                       let enhancedString = String(data: enhancedResult, encoding: .utf8)
                    {
                        return enhancedString
                    }
                }
            }
        }

        return result.isEmpty ? self.createSuccessJSON("Screenshot captured") : result
    }

    @MainActor
    private func executeClick(args: [String: Any]) async throws -> String {
        var clickCommand = ClickCommand()

        // Set parameters
        if let element = args["element"] as? String {
            clickCommand.on = element
        } else if let x = args["x"] as? Double, let y = args["y"] as? Double {
            clickCommand.coords = "\(Int(x)),\(Int(y))"
        }

        if let sessionId = args["session_id"] as? String {
            clickCommand.session = sessionId
        }

        if let doubleClick = args["double_click"] as? Bool, doubleClick {
            clickCommand.double = true
        }

        clickCommand.jsonOutput = true

        // Capture output
        let output = CaptureOutput()
        output.start()

        do {
            try await clickCommand.run()
        } catch {
            _ = output.stop()
            throw error
        }

        let result = output.stop()
        return result.isEmpty ? self.createSuccessJSON("Click executed") : result
    }

    @MainActor
    private func executeType(args: [String: Any]) async throws -> String {
        var typeCommand = TypeCommand()

        // Set parameters
        guard let text = args["text"] as? String else {
            throw AgentError.invalidArguments("Type command requires 'text' parameter")
        }
        typeCommand.text = text

        if let sessionId = args["session_id"] as? String {
            typeCommand.session = sessionId
        }

        if let clearFirst = args["clear_first"] as? Bool, clearFirst {
            typeCommand.clear = true
        }

        typeCommand.jsonOutput = true

        // Capture output
        let output = CaptureOutput()
        output.start()

        do {
            try await typeCommand.run()
        } catch {
            _ = output.stop()
            throw error
        }

        let result = output.stop()
        return result.isEmpty ? self.createSuccessJSON("Text typed") : result
    }

    @MainActor
    private func executeApp(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String,
              let name = args["name"] as? String
        else {
            throw AgentError.invalidArguments("App command requires 'action' and 'name' parameters")
        }

        // Create appropriate subcommand based on action
        switch action {
        case "launch":
            var launchCommand = AppCommand.LaunchSubcommand()
            launchCommand.app = name
            launchCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await launchCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("App launched") : result

        case "quit":
            var quitCommand = AppCommand.QuitSubcommand()
            quitCommand.app = name
            quitCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await quitCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("App quit") : result

        case "focus", "switch":
            var switchCommand = AppCommand.SwitchSubcommand()
            switchCommand.to = name
            switchCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await switchCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("App focused") : result

        case "hide":
            var hideCommand = AppCommand.HideSubcommand()
            hideCommand.app = name
            hideCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await hideCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("App hidden") : result

        case "unhide":
            var unhideCommand = AppCommand.UnhideSubcommand()
            unhideCommand.app = name
            unhideCommand.jsonOutput = true

            let output = CaptureOutput()
            output.start()
            try await unhideCommand.run()
            let result = output.stop()
            return result.isEmpty ? self.createSuccessJSON("App unhidden") : result

        default:
            throw AgentError.invalidArguments("Unknown app action: \(action)")
        }
    }

    @MainActor
    private func executeWindow(args: [String: Any]) async throws -> String {
        guard let action = args["action"] as? String else {
            throw AgentError.invalidArguments("Window command requires 'action' parameter")
        }

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
        var hotkeyCommand = HotkeyCommand()

        guard let keys = args["keys"] as? [String] else {
            throw AgentError.invalidArguments("Hotkey command requires 'keys' array")
        }

        hotkeyCommand.keys = keys.joined(separator: ",")
        hotkeyCommand.jsonOutput = true

        // Capture output
        let output = CaptureOutput()
        output.start()

        do {
            try await hotkeyCommand.run()
        } catch {
            _ = output.stop()
            throw error
        }

        let result = output.stop()
        return result.isEmpty ? self.createSuccessJSON("Hotkey pressed") : result
    }

    @MainActor
    private func executeScroll(args: [String: Any]) async throws -> String {
        var scrollCommand = ScrollCommand()

        if let direction = args["direction"] as? String {
            scrollCommand.direction = ScrollCommand.ScrollDirection(rawValue: direction) ?? .down
        }
        if let amount = args["amount"] as? Int {
            scrollCommand.amount = amount
        }
        if let element = args["element"] as? String {
            scrollCommand.on = element
        }

        scrollCommand.jsonOutput = true

        // Capture output
        let output = CaptureOutput()
        output.start()

        do {
            try await scrollCommand.run()
        } catch {
            _ = output.stop()
            throw error
        }

        let result = output.stop()
        return result.isEmpty ? self.createSuccessJSON("Scrolled") : result
    }

    @MainActor
    private func executeAnalyzeScreenshot(args: [String: Any]) async throws -> String {
        guard let screenshotPath = args["screenshot_path"] as? String else {
            throw AgentError.invalidArguments("analyze_screenshot requires 'screenshot_path' parameter")
        }

        let question = args["question"] as? String ?? "What is shown in this screenshot?"

        // Use the vision API to analyze the screenshot
        let analysis = try await analyzeWithVision(imagePath: screenshotPath, question: question)

        return self.createSuccessJSON(analysis)
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
