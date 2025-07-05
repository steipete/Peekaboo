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
        """
    )
    
    @Argument(help: "Path to the script file (.peekaboo.json)")
    var scriptPath: String
    
    @Option(help: "Save results to file instead of stdout")
    var output: String?
    
    @Flag(help: "Continue execution even if a step fails")
    var noFailFast = false
    
    @Flag(help: "Show detailed step execution")
    var verbose = false
    
    mutating func run() async throws {
        let startTime = Date()
        
        do {
            // Load and validate script
            let script = try loadScript(from: scriptPath)
            
            // Execute script
            let results = try await executeScript(
                script,
                failFast: !noFailFast,
                verbose: verbose
            )
            
            // Prepare output
            let output = ScriptExecutionResult(
                success: results.allSatisfy { $0.success },
                scriptPath: scriptPath,
                description: script.description,
                totalSteps: script.steps.count,
                completedSteps: results.filter { $0.success }.count,
                failedSteps: results.filter { !$0.success }.count,
                executionTime: Date().timeIntervalSince(startTime),
                steps: results
            )
            
            // Write output
            if let outputPath = self.output {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(output)
                try data.write(to: URL(fileURLWithPath: outputPath))
                
                if !verbose {
                    print("✅ Script completed. Results saved to: \(outputPath)")
                }
            } else {
                outputSuccessCodable(data: output)
            }
            
            // Exit with failure if any steps failed
            if !output.success {
                throw ExitCode.failure
            }
            
        } catch {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
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
    
    private func executeScript(_ script: PeekabooScript,
                             failFast: Bool,
                             verbose: Bool) async throws -> [StepResult] {
        var results: [StepResult] = []
        var sessionId: String?
        
        for (index, step) in script.steps.enumerated() {
            let stepNumber = index + 1
            
            if verbose {
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
                    currentSessionId: sessionId
                )
                
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
                    executionTime: Date().timeIntervalSince(stepStartTime)
                )
                
                results.append(result)
                
                if verbose {
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
                    executionTime: Date().timeIntervalSince(stepStartTime)
                )
                
                results.append(result)
                
                if verbose {
                    print("   ❌ Step \(stepNumber) failed: \(error.localizedDescription)")
                }
                
                if failFast {
                    break
                }
            }
        }
        
        return results
    }
    
    private func executeStep(_ step: ScriptStep,
                           currentSessionId: String?) async throws -> (output: String?, sessionId: String?) {
        // Build command arguments
        var args = [step.command]
        
        // Add parameters
        if let params = step.params {
            // Handle session ID propagation
            if step.command != "see" && step.command != "sleep" && step.command != "hotkey" {
                if let sessionId = params["session-id"] as? String ?? currentSessionId {
                    args.append("--session-id")
                    args.append(sessionId)
                }
            }
            
            // Add other parameters
            for (key, value) in params where key != "session-id" {
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
        if step.command == "see", let output = output {
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["data"] as? [String: Any],
               let sessionId = responseData["sessionId"] as? String {
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stepId = try container.decode(String.self, forKey: .stepId)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        command = try container.decode(String.self, forKey: .command)
        
        // Decode params as dictionary with Any values
        if let paramsContainer = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .params) {
            params = paramsContainer.mapValues { $0.value }
        } else {
            params = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stepId, forKey: .stepId)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(command, forKey: .command)
        
        if let params = params {
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