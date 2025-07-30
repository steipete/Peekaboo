import Foundation
import CoreGraphics

// MARK: - Shell Tools

/// Shell command execution tool
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the shell tool
    func createShellTool() -> Tool<PeekabooServices> {
        createTool(
            name: "shell",
            description: "Execute a shell command",
            parameters: .object(
                properties: [
                    "command": ParameterSchema.string(
                        description: "Shell command to execute"
                    ),
                    "working_directory": ParameterSchema.string(
                        description: "Optional: Working directory for the command"
                    ),
                    "timeout": ParameterSchema.integer(
                        description: "Command timeout in seconds (default: 30)"
                    )
                ],
                required: ["command"]
            ),
            handler: { params, context in
                let command = try params.string("command")
                let workingDirectory = params.string("working_directory", default: nil)
                let timeout = params.int("timeout", default: 30) ?? 30
                
                let startTime = Date()
                
                // Safety check for dangerous commands
                let dangerousCommands = ["rm -rf /", "dd if=", "mkfs", "format"]
                for dangerous in dangerousCommands {
                    if command.contains(dangerous) {
                        throw PeekabooError.invalidInput("Command appears to be potentially destructive and was blocked for safety")
                    }
                }
                
                // Extract the actual command name for better reporting
                let commandParts = command.split(separator: " ", maxSplits: 1)
                let commandName = String(commandParts.first ?? "shell")
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                
                let actualWorkingDir: String
                if let workingDirectory = workingDirectory {
                    let expandedPath = workingDirectory.expandedPath
                    process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)
                    actualWorkingDir = expandedPath
                } else {
                    actualWorkingDir = FileManager.default.currentDirectoryPath
                }
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                try process.run()
                
                // Set up timeout
                var timedOut = false
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout) * TimeInterval.longDelay.nanoseconds)
                    if process.isRunning {
                        timedOut = true
                        process.terminate()
                    }
                }
                
                process.waitUntilExit()
                timeoutTask.cancel()
                
                let duration = Date().timeIntervalSince(startTime)
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if timedOut {
                    throw PeekabooError.operationError(message: "Command timed out after \(timeout) seconds and was terminated")
                }
                
                if process.terminationStatus != 0 {
                    var errorMessage = "'\(commandName)' failed with exit code \(process.terminationStatus) after \(String(format: "%.2fs", duration))"
                    if !errorOutput.isEmpty {
                        errorMessage += "\n\nError output:\n\(errorOutput)"
                    }
                    if !output.isEmpty {
                        errorMessage += "\n\nStandard output:\n\(output)"
                    }
                    throw PeekabooError.operationError(message: errorMessage)
                }
                
                var result = output
                let lineCount = output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
                var truncated = false
                
                if result.isEmpty {
                    result = "✓ '\(commandName)' completed successfully (no output)"
                } else if result.count > 5000 {
                    result = String(result.prefix(5000))
                    truncated = true
                }
                
                // Create a summary line
                var summary = "Executed '\(commandName)'"
                if lineCount > 0 {
                    summary += " → \(lineCount) lines"
                }
                summary += " in \(String(format: "%.2fs", duration))"
                if truncated {
                    summary += " (truncated from \(output.count) characters)"
                }
                
                // Format the final output
                var finalOutput = summary + "\n"
                if !result.isEmpty && !result.contains("completed successfully") {
                    finalOutput += "\n" + result
                }
                
                return .success(
                    finalOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: [
                        "command": command,
                        "commandName": commandName,
                        "exitCode": "0",
                        "workingDirectory": actualWorkingDir,
                        "duration": String(format: "%.2fs", duration),
                        "lineCount": String(lineCount),
                        "outputSize": String(output.count),
                        "truncated": String(truncated)
                    ]
                )
            }
        )
    }
}