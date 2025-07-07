import Foundation

// MARK: - Command Executor

struct PeekabooCommandExecutor {
    let verbose: Bool
    let sessionManager = SessionManager.shared

    /// Executes a Peekaboo function and returns JSON response
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

        // Get session ID if provided
        let sessionId = args["session_id"] as? String

        // Log execution if verbose
        if self.verbose {
            print("🔧 Executing: \(commandName) with args: \(arguments)")
        }

        // Build and execute command
        do {
            let cliArgs = try buildCommandArguments(command: commandName, args: args)
            let output = try await executeCommand(cliArgs)

            // Update session if needed
            if let sessionId {
                await self.updateSession(sessionId, command: commandName, output: output)
            }

            return output
        } catch {
            return self.createErrorJSON(.commandFailed(error.localizedDescription))
        }
    }

    private func buildCommandArguments(command: String, args: [String: Any]) throws -> [String] {
        var cliArgs = [command]
        var hasSubcommand = false

        // Defer adding json-output for commands with subcommands
        let commandsWithSubcommands = ["app", "list", "config", "window", "menu", "dock", "dialog"]
        let shouldDeferJsonOutput = commandsWithSubcommands.contains(command)

        switch command {
        case "see":
            if let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            if let title = args["window_title"] as? String {
                cliArgs.append("--window-title")
                cliArgs.append(title)
            }
            // Note: see command creates sessions, doesn't accept them as input

        case "click":
            if let element = args["element"] as? String {
                cliArgs.append("--on")
                cliArgs.append(element)
            } else if let x = args["x"] as? Double, let y = args["y"] as? Double {
                cliArgs.append("--coords")
                cliArgs.append("\(Int(x)),\(Int(y))")
            } else {
                throw AgentError.invalidArguments("Click requires either 'element' or 'x,y' coordinates")
            }

            if let sessionId = args["session_id"] as? String {
                cliArgs.append("--session")
                cliArgs.append(sessionId)
            }

            if let doubleClick = args["double_click"] as? Bool, doubleClick {
                cliArgs.append("--double")
            }

        case "type":
            guard let text = args["text"] as? String else {
                throw AgentError.invalidArguments("Type command requires 'text' parameter")
            }
            cliArgs.append(text)

            // Map session_id to --session
            if let sessionId = args["session_id"] as? String {
                cliArgs.append("--session")
                cliArgs.append(sessionId)
            }

            if let clearFirst = args["clear_first"] as? Bool, clearFirst {
                cliArgs.append("--clear")
            }

        case "scroll":
            if let direction = args["direction"] as? String {
                cliArgs.append("--direction")
                cliArgs.append(direction)
            }
            if let amount = args["amount"] as? Int {
                cliArgs.append("--amount")
                cliArgs.append(String(amount))
            }
            if let element = args["element"] as? String {
                cliArgs.append("--on")
                cliArgs.append(element)
            }

        case "hotkey":
            guard let keys = args["keys"] as? [String] else {
                throw AgentError.invalidArguments("Hotkey command requires 'keys' array")
            }
            cliArgs.append(contentsOf: keys)

        case "image":
            if let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            if let mode = args["mode"] as? String {
                cliArgs.append("--mode")
                cliArgs.append(mode)
            }
            if let path = args["path"] as? String {
                cliArgs.append("--path")
                cliArgs.append(path)
            }
            if let format = args["format"] as? String {
                cliArgs.append("--format")
                cliArgs.append(format)
            }

        case "window":
            guard let action = args["action"] as? String else {
                throw AgentError.invalidArguments("Window command requires 'action' parameter")
            }
            cliArgs.append(action)
            hasSubcommand = true

            if let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            if let title = args["title"] as? String {
                cliArgs.append("--window-title")
                cliArgs.append(title)
            }

            // Position/size parameters
            if action == "move" {
                if let x = args["x"] as? Double, let y = args["y"] as? Double {
                    cliArgs.append("--position")
                    cliArgs.append("\(Int(x)),\(Int(y))")
                }
            } else if action == "resize" {
                if let width = args["width"] as? Double, let height = args["height"] as? Double {
                    cliArgs.append("--size")
                    cliArgs.append("\(Int(width)),\(Int(height))")
                }
            }

        case "app":
            guard let action = args["action"] as? String,
                  let name = args["name"] as? String
            else {
                throw AgentError.invalidArguments("App command requires 'action' and 'name' parameters")
            }
            cliArgs.append(action)
            hasSubcommand = true

            // For app commands, the name is NOT a flag, it's a positional argument
            // But some actions like "switch" use --to flag
            if action == "switch" {
                cliArgs.append("--to")
                cliArgs.append(name)
            } else {
                cliArgs.append(name)
            }

        case "wait":
            // Map wait to sleep command but preserve the command structure
            cliArgs[0] = "sleep"
            guard let duration = args["duration"] as? Double else {
                throw AgentError.invalidArguments("Wait command requires 'duration' parameter")
            }
            // Convert to milliseconds and add as argument
            cliArgs.append(String(Int(duration * 1000)))

        case "sleep":
            guard let duration = args["duration"] as? Double else {
                throw AgentError.invalidArguments("Sleep command requires 'duration' parameter")
            }
            // Add duration in milliseconds
            cliArgs.append(String(Int(duration * 1000)))

        case "analyze_screenshot":
            // Map to analyze command
            cliArgs[0] = "analyze"
            guard let screenshotPath = args["screenshot_path"] as? String else {
                throw AgentError.invalidArguments("analyze_screenshot requires 'screenshot_path' parameter")
            }
            cliArgs.append(screenshotPath)

            if let question = args["question"] as? String {
                cliArgs.append(question)
            }

        case "list":
            guard let target = args["target"] as? String else {
                throw AgentError.invalidArguments("List command requires 'target' parameter")
            }
            cliArgs.append(target)
            hasSubcommand = true

            if target == "windows", let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }

        case "menu":
            // Check for subcommand - default to click if not specified
            let subcommand = args["subcommand"] as? String ?? "click"
            cliArgs.append(subcommand)
            hasSubcommand = true

            if let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            if let item = args["item"] as? String {
                cliArgs.append("--item")
                cliArgs.append(item)
            }
            if let path = args["path"] as? String {
                cliArgs.append("--path")
                cliArgs.append(path)
            }

        case "dialog":
            guard let action = args["action"] as? String else {
                throw AgentError.invalidArguments("Dialog command requires 'action' parameter")
            }

            switch action {
            case "click":
                cliArgs.append("click")
                hasSubcommand = true
                if let button = args["button"] as? String {
                    cliArgs.append("--button")
                    cliArgs.append(button)
                }
            case "input":
                cliArgs.append("input")
                hasSubcommand = true
                if let text = args["text"] as? String {
                    cliArgs.append("--text")
                    cliArgs.append(text)
                }
                if let field = args["field"] as? String {
                    cliArgs.append("--field")
                    cliArgs.append(field)
                }
            case "dismiss":
                cliArgs.append("dismiss")
                hasSubcommand = true
            default:
                throw AgentError.invalidArguments("Unknown dialog action: \(action)")
            }

        case "drag":
            if let from = args["from"] as? String {
                cliArgs.append("--from")
                cliArgs.append(from)
            } else if let fromCoords = args["from_coords"] as? String {
                cliArgs.append("--from-coords")
                cliArgs.append(fromCoords)
            }

            if let to = args["to"] as? String {
                cliArgs.append("--to")
                cliArgs.append(to)
            } else if let toCoords = args["to_coords"] as? String {
                cliArgs.append("--to-coords")
                cliArgs.append(toCoords)
            }

            if let duration = args["duration"] as? Int {
                cliArgs.append("--duration")
                cliArgs.append(String(duration))
            }

            if let sessionId = args["session_id"] as? String {
                cliArgs.append("--session")
                cliArgs.append(sessionId)
            }

        case "dock":
            guard let action = args["action"] as? String else {
                throw AgentError.invalidArguments("Dock command requires 'action' parameter")
            }
            cliArgs.append(action)
            hasSubcommand = true

            if let app = args["app"] as? String {
                cliArgs.append(app)
            }

            if action == "right-click", let select = args["select"] as? String {
                cliArgs.append("--select")
                cliArgs.append(select)
            }

        case "swipe":
            if let from = args["from"] as? String {
                cliArgs.append("--from")
                cliArgs.append(from)
            } else if let fromCoords = args["from_coords"] as? String {
                cliArgs.append("--from-coords")
                cliArgs.append(fromCoords)
            }

            if let to = args["to"] as? String {
                cliArgs.append("--to")
                cliArgs.append(to)
            } else if let toCoords = args["to_coords"] as? String {
                cliArgs.append("--to-coords")
                cliArgs.append(toCoords)
            }

            if let duration = args["duration"] as? Int {
                cliArgs.append("--duration")
                cliArgs.append(String(duration))
            }

            if let sessionId = args["session_id"] as? String {
                cliArgs.append("--session")
                cliArgs.append(sessionId)
            }

        default:
            // For unknown commands, pass through all arguments
            for (key, value) in args {
                if key != "session_id" { // Skip session ID as it's internal
                    cliArgs.append("--\(key.replacingOccurrences(of: "_", with: "-"))")
                    cliArgs.append(String(describing: value))
                }
            }
        }

        // Add json-output flag after subcommands and arguments
        // For commands with subcommands, we always add it at the end
        // For commands without subcommands, we also add it
        cliArgs.append("--json-output")

        return cliArgs
    }

    private func executeCommand(_ args: [String]) async throws -> String {
        // Get the path to the current executable
        let executablePath = CommandLine.arguments[0]

        // Ensure we have an absolute path
        let absolutePath: String
        if executablePath.hasPrefix("/") {
            absolutePath = executablePath
        } else {
            // Convert relative path to absolute
            let currentDirectory = FileManager.default.currentDirectoryPath
            absolutePath = (currentDirectory as NSString).appendingPathComponent(executablePath)
        }

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: absolutePath)
        process.arguments = args

        if self.verbose {
            print("   Executing: \(absolutePath) \(args.joined(separator: " "))")
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Run process
        try process.run()

        // Read output asynchronously
        let outputData = try await withCheckedThrowingContinuation { continuation in
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                handle.readabilityHandler = nil
                continuation.resume(returning: data)
            }
        }

        let errorData = try await withCheckedThrowingContinuation { continuation in
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                handle.readabilityHandler = nil
                continuation.resume(returning: data)
            }
        }

        process.waitUntilExit()

        // Check termination status
        if process.terminationStatus == 0 {
            var output = String(data: outputData, encoding: .utf8) ?? ""

            // If no output, check stderr (some commands might output there)
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                output = String(data: errorData, encoding: .utf8) ?? ""
            }

            // Validate JSON
            if !output.isEmpty,
               let data = output.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data)
            {
                return output
            } else {
                // Command succeeded but didn't return JSON
                return """
                {
                    "success": true,
                    "message": "Command completed successfully"
                }
                """
            }
        } else {
            // Command failed
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            let regularOutput = String(data: outputData, encoding: .utf8) ?? ""

            // Try to parse as JSON error first
            if let data = regularOutput.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data)
            {
                return regularOutput
            }

            // Otherwise create error JSON
            return self.createErrorJSON(.commandFailed(
                errorOutput.isEmpty ? "Exit code: \(process.terminationStatus)" : errorOutput))
        }
    }

    private func updateSession(_ sessionId: String, command: String, output: String) async {
        // Parse output to extract element mappings or screenshot info
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["success"] as? Bool == true
        else {
            return
        }

        // Update session based on command type
        if command == "see", let elements = json["elements"] as? [[String: Any]] {
            // Store element mappings in session
            var sessionData = await sessionManager.getSession(sessionId) ?? SessionManager.SessionData(
                id: sessionId,
                createdAt: Date(),
                elementMappings: [:],
                screenshots: [],
                context: [:])

            for element in elements {
                if let id = element["id"] as? String,
                   let description = element["description"] as? String,
                   let bounds = element["bounds"] as? [String: Double],
                   let x = bounds["x"],
                   let y = bounds["y"],
                   let width = bounds["width"],
                   let height = bounds["height"]
                {
                    let mapping = SessionManager.ElementMapping(
                        id: id,
                        description: description,
                        bounds: CGRect(x: x, y: y, width: width, height: height),
                        type: element["type"] as? String ?? "unknown",
                        confidence: element["confidence"] as? Double ?? 1.0)
                    sessionData.addMapping(mapping)
                }
            }

            await self.sessionManager.updateSession(sessionId, with: sessionData)
        }
    }

    private func createErrorJSON(_ error: AgentError) -> String {
        let response = createAgentErrorResponse(error)
        if let data = try? JSONEncoder().encode(response),
           let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        return """
        {
            "success": false,
            "error": {
                "message": "\(error.localizedDescription)",
                "code": "\(error.errorCode)"
            }
        }
        """
    }
}
