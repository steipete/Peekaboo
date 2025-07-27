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
                
                // Safety check for dangerous commands
                let dangerousCommands = ["rm -rf /", "dd if=", "mkfs", "format"]
                for dangerous in dangerousCommands {
                    if command.contains(dangerous) {
                        throw PeekabooError.invalidInput("Command appears to be potentially destructive and was blocked for safety")
                    }
                }
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                
                if let workingDirectory = workingDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory.expandedPath)
                }
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                try process.run()
                
                // Set up timeout
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout) * TimeInterval.longDelay.nanoseconds)
                    if process.isRunning {
                        process.terminate()
                    }
                }
                
                process.waitUntilExit()
                timeoutTask.cancel()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus != 0 {
                    var errorMessage = "Command failed with exit code \(process.terminationStatus)"
                    if !errorOutput.isEmpty {
                        errorMessage += "\n\nError output:\n\(errorOutput)"
                    }
                    if !output.isEmpty {
                        errorMessage += "\n\nStandard output:\n\(output)"
                    }
                    throw PeekabooError.operationError(message: errorMessage)
                }
                
                var result = output
                if result.isEmpty {
                    result = "Command completed successfully (no output)"
                }
                
                // Truncate very long outputs
                if result.count > 5000 {
                    result = String(result.prefix(5000)) + "\n\n[Output truncated - \(result.count) total characters]"
                }
                
                return .success(
                    result,
                    metadata: [
                        "command": command,
                        "exitCode": "0",
                        "workingDirectory": workingDirectory?.expandedPath ?? FileManager.default.currentDirectoryPath
                    ]
                )
            }
        )
    }
}