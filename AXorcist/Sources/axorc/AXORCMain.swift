// AXORCMain.swift - Main entry point for AXORC CLI

import ArgumentParser
import AXorcistLib
import Foundation

@main
struct AXORCCommand: AsyncParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "axorc",
        abstract: "AXORC CLI - Handles JSON commands via various input methods. Version \(AXORC_VERSION)"
    )

    @Flag(name: .long, help: "Enable debug logging for the command execution.")
    var debug: Bool = false

    @Flag(name: .long, help: "Read JSON payload from STDIN.")
    var stdin: Bool = false

    @Option(name: .long, help: "Read JSON payload from the specified file path.")
    var file: String?

    @Option(name: .long, help: "Read JSON payload directly from this string argument, expecting a JSON string.")
    var json: String?

    @Argument(
        help: "Read JSON payload directly from this string argument. If other input flags (--stdin, --file, --json) are used, this argument is ignored."
    )
    var directPayload: String?

    mutating func run() async throws {
        // Parse input using InputHandler
        let inputResult = InputHandler.parseInput(
            stdin: stdin,
            file: file,
            json: json,
            directPayload: directPayload,
            debug: debug
        )

        var localDebugLogs = inputResult.debugLogs

        // Handle input errors
        if let error = inputResult.error {
            let errorResponse = ErrorResponse(
                command_id: "input_error",
                error: ErrorResponse.ErrorDetail(
                    message: error
                ),
                debug_logs: debug ? localDebugLogs : nil
            )

            if let jsonData = try? JSONEncoder().encode(errorResponse),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("{\"error\": \"Failed to encode error response\"}")
            }
            return
        }

        guard let jsonString = inputResult.jsonString else {
            let errorResponse = ErrorResponse(
                command_id: "no_input",
                error: ErrorResponse.ErrorDetail(
                    message: "No valid JSON input received"
                ),
                debug_logs: debug ? localDebugLogs : nil
            )

            if let jsonData = try? JSONEncoder().encode(errorResponse),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                print(jsonStr)
            } else {
                print("{\"error\": \"Failed to encode error response\"}")
            }
            return
        }

        // Parse JSON command
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("{\"error\": \"Failed to convert JSON string to data\"}")
            return
        }

        if debug {
            localDebugLogs.append("AXORCMain: jsonString before decode: [\(jsonString)]")
            localDebugLogs.append("AXORCMain: jsonData.count before decode: \(jsonData.count)")
        }

        do {
            let command = try JSONDecoder().decode(CommandEnvelope.self, from: jsonData)

            if debug {
                localDebugLogs.append("Successfully parsed command: \(command.command)")
            }

            // Execute command using CommandExecutor
            let axorcist = AXorcist()
            let result = await CommandExecutor.execute(
                command: command,
                axorcist: axorcist,
                debug: debug
            )

            print(result)

        } catch {
            // FORCED DEBUGGING FOR THIS ERROR PATH
            // debug = true // Temporarily enable debug logs for this error block if needed

            var errorSpecificDebugLogs = localDebugLogs // Copy existing logs
            errorSpecificDebugLogs.append("DECODE_ERROR_DEBUG: Original jsonString that led to this error: [\(jsonString)]")
            errorSpecificDebugLogs.append("DECODE_ERROR_DEBUG: jsonData.count that led to this error: \(jsonData.count)")
            errorSpecificDebugLogs.append("DECODE_ERROR_DEBUG: Raw error.localizedDescription: \(error.localizedDescription)")
            errorSpecificDebugLogs.append("DECODE_ERROR_DEBUG: Full error object: \(error)")

            let errorMessage = "Failed to parse JSON command. Raw Error: \(error.localizedDescription). JSON Input (first 100 chars): \(jsonString.prefix(100))..."

            let errorResponse = ErrorResponse(
                command_id: "decode_error",
                error: ErrorResponse.ErrorDetail(
                    message: errorMessage
                ),
                // Always include these enhanced debug logs for decode_error for now
                debug_logs: errorSpecificDebugLogs
            )

            if let responseData = try? JSONEncoder().encode(errorResponse),
               let responseStr = String(data: responseData, encoding: .utf8) {
                print(responseStr)
            } else {
                // Fallback if even error encoding fails
                let fallbackErrorMsg = "{\"error\": \"Failed to encode error response. Original error for decode: \(error.localizedDescription). Input was: \(jsonString)\"}"
                print(fallbackErrorMsg)
            }
        }
    }
}
