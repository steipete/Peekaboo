//
//  ShellTool.swift
//  PeekabooCore
//

import Foundation
import MCP
import os.log
import TachikomaMCP

/// MCP tool for executing shell commands
public struct ShellTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "ShellTool")

    public let name = "shell"

    public var description: String {
        """
        Execute shell commands with bash.

        Usage:
        - Executes commands using /bin/bash -c
        - Returns command output on success
        - Returns error output on failure
        - Exit code is available in error messages

        Examples:
        - List files: { "command": "ls -la" }
        - Check status: { "command": "git status" }
        - Run script: { "command": "./build.sh" }

        Security note: Use with caution. Commands run with user privileges.
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "command": SchemaBuilder.string(
                    description: "Shell command to execute"),
            ],
            required: ["command"])
    }

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        guard let command = arguments.getString("command") else {
            return ToolResponse(
                content: [.text("Command is required")],
                isError: true)
        }

        self.logger.info("Executing shell command: \(command)")

        // Execute shell command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                let message = error.isEmpty ? output : error
                self.logger.error("Command failed with exit code \(process.terminationStatus): \(message)")
                return ToolResponse(
                    content: [.text("Command failed (exit code \(process.terminationStatus)): \(message)")],
                    isError: true)
            }

            self.logger.debug("Command completed successfully")
            let summary = ToolEventSummary(
                command: command,
                workingDirectory: FileManager.default.currentDirectoryPath,
                notes: nil)
            let meta = ToolEventSummary.merge(summary: summary, into: nil)
            return ToolResponse(
                content: [.text(output)],
                isError: false,
                meta: meta)
        } catch {
            self.logger.error("Failed to execute command: \(error.localizedDescription)")
            return ToolResponse(
                content: [.text("Failed to execute command: \(error.localizedDescription)")],
                isError: true)
        }
    }
}
