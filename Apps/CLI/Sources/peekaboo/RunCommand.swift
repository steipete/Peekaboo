import ArgumentParser
import Foundation

/// Executes a batch script of Peekaboo commands.
/// Supports .peekaboo.json files with sequential command execution.
@available(macOS 14.0, *)
struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute a Peekaboo automation script",
        discussion: """
            The 'run' command executes a batch script containing multiple
            Peekaboo commands in sequence. Scripts are JSON files that
            define a series of UI automation steps.

            EXAMPLES:
              peekaboo run login-flow.peekaboo.json
              peekaboo run test-suite.json --output results.json
              peekaboo run automation.json --no-fail-fast

            SCRIPT FORMAT:
              Scripts use the .peekaboo.json extension and contain:
              - A description of the automation
              - An array of steps with commands and parameters
              - Optional step IDs and comments

            Each step in the script corresponds to a Peekaboo command
            (see, click, type, scroll, etc.) with its parameters.
        """)

    @Argument(help: "Path to the script file (.peekaboo.json)")
    var scriptPath: String

    @Option(help: "Save results to file instead of stdout")
    var output: String?

    @Flag(help: "Continue execution even if a step fails")
    var noFailFast = false

    @Flag(help: "Show detailed step execution")
    var verbose = false

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        let startTime = Date()

        do {
            // Load and validate script
            let script = try loadScript(from: scriptPath)

            // Execute script
            let results = try await executeScript(
                script,
                failFast: !self.noFailFast,
                verbose: self.verbose,
                jsonOutput: self.jsonOutput)

            // Prepare output
            let output = ScriptExecutionResult(
                success: results.allSatisfy(\.success),
                scriptPath: self.scriptPath,
                description: script.description,
                totalSteps: script.steps.count,
                completedSteps: results.count { $0.success },
                failedSteps: results.count { !$0.success },
                executionTime: Date().timeIntervalSince(startTime),
                steps: results)

            // Write output
            if let outputPath = self.output {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(output)
                try data.write(to: URL(fileURLWithPath: outputPath))

                if !self.verbose, !self.jsonOutput {
                    print("✅ Script completed. Results saved to: \(outputPath)")
                }
            } else if self.jsonOutput {
                outputSuccessCodable(data: output)
            } else {
                // Human-readable output
                if output.success {
                    print("✅ Script completed successfully")
                    print("   Total steps: \(output.totalSteps)")
                    print("   Completed: \(output.completedSteps)")
                    print("   Failed: \(output.failedSteps)")
                    print("   Execution time: \(String(format: "%.2f", output.executionTime))s")
                } else {
                    print("❌ Script failed")
                    print("   Total steps: \(output.totalSteps)")
                    print("   Completed: \(output.completedSteps)")
                    print("   Failed: \(output.failedSteps)")
                    print("   Execution time: \(String(format: "%.2f", output.executionTime))s")

                    // Show failed steps
                    let failedSteps = output.steps.filter { !$0.success }
                    if !failedSteps.isEmpty {
                        print("\nFailed steps:")
                        for step in failedSteps {
                            print("   - Step \(step.stepNumber) (\(step.command)): \(step.error ?? "Unknown error")")
                        }
                    }
                }
            }

            // Exit with failure if any steps failed
            if !output.success {
                throw ExitCode.failure
            }

        } catch {
            if self.jsonOutput {
                outputError(message: error.localizedDescription, code: .INVALID_ARGUMENT)
            } else {
                print("❌ Error: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }

    private func loadScript(from path: String) throws -> PeekabooScript {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("Script file not found: \(path)")
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        do {
            return try decoder.decode(PeekabooScript.self, from: data)
        } catch {
            throw ValidationError("Invalid script format: \(error.localizedDescription)")
        }
    }

    private func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool,
        jsonOutput: Bool) async throws -> [StepResult]
    {
        var results: [StepResult] = []
        var sessionId: String?

        for (index, step) in script.steps.enumerated() {
            let stepNumber = index + 1

            if verbose, !jsonOutput {
                print("\n🔄 Step \(stepNumber)/\(script.steps.count): \(step.command)")
                if let comment = step.comment {
                    print("   💬 \(comment)")
                }
            }

            let stepStartTime = Date()

            do {
                // Execute the step
                let (output, newSessionId) = try await executeStep(
                    step,
                    currentSessionId: sessionId)

                // Update session ID if a new one was created
                if let newId = newSessionId {
                    sessionId = newId
                }

                let result = StepResult(
                    stepId: step.stepId,
                    stepNumber: stepNumber,
                    command: step.command,
                    success: true,
                    output: output,
                    error: nil,
                    executionTime: Date().timeIntervalSince(stepStartTime))

                results.append(result)

                if verbose, !jsonOutput {
                    print("   ✅ Step \(stepNumber) completed in \(String(format: "%.2f", result.executionTime))s")
                }

            } catch {
                let result = StepResult(
                    stepId: step.stepId,
                    stepNumber: stepNumber,
                    command: step.command,
                    success: false,
                    output: nil,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(stepStartTime))

                results.append(result)

                if verbose, !jsonOutput {
                    print("   ❌ Step \(stepNumber) failed: \(error.localizedDescription)")
                }

                if failFast {
                    break
                }
            }
        }

        return results
    }

    private func executeStep(
        _ step: ScriptStep,
        currentSessionId: String?) async throws -> (output: String?, sessionId: String?)
    {
        // Build command arguments
        var args = [step.command]

        // Add parameters
        if let params = step.params {
            // Handle session ID propagation
            if step.command != "see" && step.command != "sleep" && step.command != "hotkey" {
                if let sessionId = params["session-id"] as? String ?? params["session"] as? String ?? currentSessionId {
                    args.append("--session")
                    args.append(sessionId)
                }
            }

            // Handle special cases for commands with positional arguments
            if step.command == "sleep" {
                // Sleep takes duration as positional argument
                if let duration = params["duration"] {
                    if let numberValue = duration as? NSNumber {
                        args.append(numberValue.stringValue)
                    } else if let stringValue = duration as? String {
                        args.append(stringValue)
                    }
                }
            } else if step.command == "click" {
                // Click can take query as positional argument
                if let query = params["query"] as? String {
                    args.append(query)
                }
                // Add other click parameters as flags
                for (key, value) in params where key != "session-id" && key != "query" && key != "session" {
                    args.append("--\(key)")

                    if let stringValue = value as? String {
                        args.append(stringValue)
                    } else if let boolValue = value as? Bool, boolValue {
                        // Flag parameters don't need a value
                    } else if let numberValue = value as? NSNumber {
                        args.append(numberValue.stringValue)
                    }
                }
            } else if step.command == "type" {
                // Type takes text as positional argument
                if let text = params["text"] as? String {
                    args.append(text)
                }
                // Add other type parameters as flags
                for (key, value) in params where key != "session-id" && key != "session" && key != "text" {
                    args.append("--\(key)")

                    if let stringValue = value as? String {
                        args.append(stringValue)
                    } else if let boolValue = value as? Bool, boolValue {
                        // Flag parameters don't need a value
                    } else if let numberValue = value as? NSNumber {
                        args.append(numberValue.stringValue)
                    }
                }
            } else if step.command == "see" {
                // See command uses all parameters as flags
                for (key, value) in params {
                    args.append("--\(key)")

                    if let stringValue = value as? String {
                        args.append(stringValue)
                    } else if let boolValue = value as? Bool, boolValue {
                        // Flag parameters don't need a value
                    } else if let numberValue = value as? NSNumber {
                        args.append(numberValue.stringValue)
                    }
                }
            } else if step.command == "swipe" {
                // Swipe uses all parameters as flags
                for (key, value) in params where key != "session-id" && key != "session" {
                    args.append("--\(key)")

                    if let stringValue = value as? String {
                        args.append(stringValue)
                    } else if let boolValue = value as? Bool, boolValue {
                        // Flag parameters don't need a value
                    } else if let numberValue = value as? NSNumber {
                        args.append(numberValue.stringValue)
                    }
                }
            } else if step.command == "scroll" || step.command == "hotkey" {
                // These commands use all parameters as flags
                for (key, value) in params where key != "session-id" && key != "session" {
                    args.append("--\(key)")

                    if let stringValue = value as? String {
                        args.append(stringValue)
                    } else if let boolValue = value as? Bool, boolValue {
                        // Flag parameters don't need a value
                    } else if let numberValue = value as? NSNumber {
                        args.append(numberValue.stringValue)
                    }
                }
            } else {
                // Default: Add all parameters as flags
                for (key, value) in params where key != "session-id" && key != "session" {
                    args.append("--\(key)")

                    if let stringValue = value as? String {
                        args.append(stringValue)
                    } else if let boolValue = value as? Bool, boolValue {
                        // Flag parameters don't need a value
                    } else if let numberValue = value as? NSNumber {
                        args.append(numberValue.stringValue)
                    }
                }
            }
        }

        // Add JSON output flag
        args.append("--json-output")

        // Execute the command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        process.arguments = args

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ValidationError("Command '\(step.command)' failed with exit code \(process.terminationStatus)")
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)

        // Extract session ID from see command output
        var newSessionId: String?
        if step.command == "see", let output {
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["data"] as? [String: Any],
               let sessionId = responseData["session_id"] as? String
            {
                newSessionId = sessionId
            }
        }

        return (output, newSessionId)
    }
}

// MARK: - Script Data Models

struct PeekabooScript: Codable {
    let description: String?
    let steps: [ScriptStep]
}

struct ScriptStep: Codable {
    let stepId: String
    let comment: String?
    let command: String
    let params: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case stepId, comment, command, params
    }

    init(stepId: String, comment: String?, command: String, params: [String: Any]?) {
        self.stepId = stepId
        self.comment = comment
        self.command = command
        self.params = params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.stepId = try container.decode(String.self, forKey: .stepId)
        self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
        self.command = try container.decode(String.self, forKey: .command)

        // Decode params as dictionary with Any values
        if let paramsContainer = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .params) {
            self.params = paramsContainer.mapValues { $0.value }
        } else {
            self.params = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.stepId, forKey: .stepId)
        try container.encodeIfPresent(self.comment, forKey: .comment)
        try container.encode(self.command, forKey: .command)

        if let params {
            let codableParams = params.mapValues { AnyCodable($0) }
            try container.encode(codableParams, forKey: .params)
        }
    }
}

// MARK: - Output Models

struct ScriptExecutionResult: Codable {
    let success: Bool
    let scriptPath: String
    let description: String?
    let totalSteps: Int
    let completedSteps: Int
    let failedSteps: Int
    let executionTime: TimeInterval
    let steps: [StepResult]
}

struct StepResult: Codable {
    let stepId: String
    let stepNumber: Int
    let command: String
    let success: Bool
    let output: String?
    let error: String?
    let executionTime: TimeInterval
}
