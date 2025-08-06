import CoreGraphics
import Foundation
import Tachikoma

// MARK: - Timeout State Actor

@available(macOS 14.0, *)
private actor TimeoutState {
    private var timedOut = false

    func setTimedOut() {
        self.timedOut = true
    }

    var wasTimedOut: Bool {
        self.timedOut
    }
}

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct ShellToolDefinitions {
    public static let shell = PeekabooToolDefinition(
        name: "shell",
        commandName: "shell",
        abstract: "Execute a shell command",
        discussion: """
            Executes a shell command using bash and captures the output.
            Commands run with a configurable timeout and safety checks.

            EXAMPLES:
              peekaboo shell "ls -la"
              peekaboo shell "git status" --working-directory ~/Projects
              peekaboo shell "find . -name '*.swift'" --timeout 60
        """,
        category: .system,
        parameters: [
            ParameterDefinition(
                name: "command",
                type: .string,
                description: "Shell command to execute",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "working-directory",
                type: .string,
                description: "Working directory for the command",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option, longName: "working-directory")),
            ParameterDefinition(
                name: "timeout",
                type: .integer,
                description: "Command timeout in seconds (default: 30)",
                required: false,
                defaultValue: "30",
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"command": "ls -la"}"#,
            #"{"command": "git status", "working_directory": "~/Projects"}"#,
            #"{"command": "python3 script.py", "timeout": 60}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - Commands run in bash with -c flag
            - Output is truncated to 5000 characters
            - Default timeout is 30 seconds
            - Some dangerous commands are blocked for safety
            - Shows exit code and execution time
            - Working directory defaults to current directory
            - Use quotes for complex commands with pipes
        """)
}

// MARK: - Shell Tools

/// Shell command execution tool
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the shell tool
    func createShellTool() -> Tachikoma.AgentTool {
        let definition = ShellToolDefinitions.shell

        return Tachikoma.AgentTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentToolParameters(),
            execute: { [services] params in
                guard let command = params.optionalStringValue("command") else {
                    throw PeekabooError.invalidInput("Command parameter is required")
                }
                let workingDirectory = params.optionalStringValue("working-directory")
                let timeout = params.optionalIntegerValue("timeout") ?? 30

                let startTime = Date()

                // Safety check for dangerous commands
                let dangerousCommands = ["rm -rf /", "dd if=", "mkfs", "format"]
                for dangerous in dangerousCommands {
                    if command.contains(dangerous) {
                        throw PeekabooError
                            .invalidInput("Command appears to be potentially destructive and was blocked for safety")
                    }
                }

                // Extract the actual command name for better reporting
                let commandParts = command.split(separator: " ", maxSplits: 1)
                let commandName = String(commandParts.first ?? "shell")

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]

                let actualWorkingDir: String
                if let workingDirectory {
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

                // Set up timeout using actor for safe concurrent access
                let timeoutState = TimeoutState()
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout) * TimeInterval.longDelay.nanoseconds)
                    if process.isRunning {
                        await timeoutState.setTimedOut()
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

                if await timeoutState.wasTimedOut {
                    throw PeekabooError
                        .operationError(message: "Command timed out after \(timeout) seconds and was terminated")
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
                let lineCount = output.components(separatedBy: .newlines).count(where: { !$0.isEmpty })
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
                if !result.isEmpty, !result.contains("completed successfully") {
                    finalOutput += "\n" + result
                }

                return .string(finalOutput.trimmingCharacters(in: .whitespacesAndNewlines))
            })
    }
}
