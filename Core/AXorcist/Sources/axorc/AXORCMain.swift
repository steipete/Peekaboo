// AXORCMain.swift - Main entry point for AXORC CLI

@preconcurrency import ArgumentParser
import AXorcist // For AXorcist instance
import CoreFoundation
import Foundation

// axorcVersion is now defined in AXORCModels.swift
// let axorcVersion = "0.1.0-dev"

@main
struct AXORCCommand: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "axorc",
        // Use axorcVersion from AXORCModels.swift or a shared constant place
        abstract: "AXORC CLI - Handles JSON commands via various input methods. Version \(axorcVersion)"
    )

    // `--debug` now enables *normal* diagnostic output. Use the new `--verbose` flag for the extremely chatty logs.
    @Flag(name: .long, help: "Enable debug logging (normal detail level). Use --verbose for maximum detail.")
    var debug: Bool = false

    @Flag(name: .long, help: "Enable *verbose* debug logging – every internal step. Produces large output.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Read JSON payload from STDIN.")
    var stdin: Bool = false

    @Option(name: .long, help: "Read JSON payload from the specified file path.")
    var file: String?

    @Option(name: .long, help: "Read JSON payload directly from this string argument, expecting a JSON string.")
    var json: String?

    @Option(name: .long, help: "Traversal timeout in seconds (overrides default 30).")
    var timeout: Int?

    @Flag(name: .long, help: "Traverse every node (ignore container role pruning). May be extremely slow.")
    var scanAll: Bool = false

    @Flag(name: .customLong("no-stop-first"), help: "Do not stop at first match; collect deeper matches as well.")
    var noStopFirst: Bool = false

    @Argument(
        help: "Read JSON payload directly from this string argument. If other input flags (--stdin, --file, --json) are used, this argument is ignored."
    )
    var directPayload: String?

    // Helper function to process and execute a CommandEnvelope
    @MainActor private func processAndExecuteCommand(command: CommandEnvelope, axorcist: AXorcist, debugCLI: Bool) {
        if debugCLI {
            axDebugLog("Successfully parsed command: \(command.command) (ID: \(command.commandId))")
        }

        let resultJsonString = CommandExecutor.execute(
            command: command,
            axorcist: axorcist,
            debugCLI: debugCLI
        )
        print(resultJsonString)
        fflush(stdout)

        if command.command == .observe {
            var observerSetupSucceeded = false
            if let resultData = resultJsonString.data(using: .utf8) {
                do {
                    if let jsonOutput = try JSONSerialization.jsonObject(with: resultData, options: []) as? [String: Any],
                       let success = jsonOutput["success"] as? Bool,
                       let status = jsonOutput["status"] as? String {
                        axInfoLog("AXORCMain: Parsed initial response for observe: success=\(success), status=\(status)")
                        if success && status == "observer_started" {
                            observerSetupSucceeded = true
                            axInfoLog("AXORCMain: Observer setup deemed SUCCEEDED for observe command.")
                        } else {
                            axInfoLog("AXORCMain: Observer setup deemed FAILED for observe command (success=\(success), status=\(status)).")
                        }
                    } else {
                        axErrorLog("AXORCMain: Failed to parse expected fields (success, status) from observe setup JSON.")
                    }
                } catch {
                    axErrorLog("AXORCMain: Could not parse result JSON from observe setup to check for success: \(error.localizedDescription)")
                }
            } else {
                axErrorLog("AXORCMain: Could not convert result JSON string to data for observe setup check.")
            }

            if observerSetupSucceeded {
                axInfoLog("AXORCMain: Observer setup successful. Process will remain alive by running current RunLoop.")
                #if DEBUG
                    axInfoLog("AXORCMain: DEBUG mode - entering RunLoop.current.run() for observer.")
                    RunLoop.current.run()
                    axInfoLog("AXORCMain: DEBUG mode - RunLoop.current.run() finished.")
                #else
                    fputs("{\"error\": \"The 'observe' command is intended for DEBUG builds or specific use cases. " +
                        "In release, it sets up the observer but will not keep the process alive indefinitely by itself. " +
                        "Exiting normally after setup.\"}\n", stderr)
                    fflush(stderr)
                #endif
            } else {
                axErrorLog("AXORCMain: Observe command setup reported failure or result was not a success status. Exiting.")
            }
        } else {
            axClearLogs()
        }
    }

    @MainActor mutating func run() async throws {
        fputs("AXORCMain.run: VERY FIRST LINE EXECUTED.\n", stderr)
        fflush(stderr)

        // Configure global logger according to flags.
        if verbose {
            GlobalAXLogger.shared.isLoggingEnabled = true
            GlobalAXLogger.shared.detailLevel = .verbose
        } else if debug {
            GlobalAXLogger.shared.isLoggingEnabled = true
            GlobalAXLogger.shared.detailLevel = .normal
        } else {
            GlobalAXLogger.shared.isLoggingEnabled = false
            GlobalAXLogger.shared.detailLevel = .minimal
        }

        // Set global brute-force / stop-first flags
        axorcScanAll = scanAll
        axorcStopAtFirstMatch = !noStopFirst

        // Honour timeout override
        if let timeout = timeout {
            axorcTraversalTimeout = TimeInterval(timeout)
        }

        // For clarity in stderr output
        fputs("AXORCMain.run: AXorc version \(axorcVersion) build \(axorcBuildStamp). Detail level: \(GlobalAXLogger.shared.detailLevel).\n", stderr)

        // <<< TEST LOGGING START >>>
        axErrorLog("AXORCMain.run: TEST ERROR LOG -- SHOULD ALWAYS APPEAR IN DEBUG OUTPUT IF LOGS ARE PRINTED")
        axDebugLog("AXORCMain.run: TEST DEBUG LOG -- SHOULD APPEAR IF CLI --debug IS ON")
        if debug {
            fputs("AXORCMain.run: STDERR - CLI --debug IS ON. TEST LOGGING.\n", stderr)
        }
        // <<< TEST LOGGING END >>>

        let inputResult = InputHandler.parseInput(
            stdin: stdin,
            file: file,
            json: json,
            directPayload: directPayload
        )

        let axorcistInstance = AXorcist.shared // Use the shared instance

        if let error = inputResult.error {
            let collectedLogs = debug ? axGetLogsAsStrings(format: .text) : nil
            let errorResponse = ErrorResponse(commandId: "input_error", error: error, debugLogs: collectedLogs)
            if let jsonData = try? JSONEncoder().encode(errorResponse), let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("{\"error\": \"Failed to encode error response\"}")
            }
            return
        }

        guard let jsonStringFromInput = inputResult.jsonString else {
            let collectedLogs = debug ? axGetLogsAsStrings(format: .text) : nil
            let errorResponse = ErrorResponse(commandId: "no_input", error: "No valid JSON input received", debugLogs: collectedLogs)
            if let jsonData = try? JSONEncoder().encode(errorResponse), let jsonStr = String(data: jsonData, encoding: .utf8) {
                print(jsonStr)
            } else {
                print("{\"error\": \"Failed to encode error response\"}")
            }
            return
        }
        axDebugLog("AXORCMain Test: Received jsonStringFromInput: [\(jsonStringFromInput)] (length: \(jsonStringFromInput.count))")

        if let data = jsonStringFromInput.data(using: .utf8) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let commands = try decoder.decode([CommandEnvelope].self, from: data)
                if let command = commands.first {
                    axDebugLog("AXORCMain Test: Decode attempt 1: Successfully decoded [CommandEnvelope] and got first command.")
                    processAndExecuteCommand(command: command, axorcist: axorcistInstance, debugCLI: debug)
                } else {
                    axDebugLog("AXORCMain Test: Decode attempt 1: Decoded [CommandEnvelope] but array was empty.")
                    let anError = NSError(domain: "AXORCErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Decoded empty command array from [CommandEnvelope] attempt."])
                    throw anError
                }
            } catch let arrayDecodeError {
                axDebugLog("AXORCMain Test: Decode attempt 1 (as [CommandEnvelope]) FAILED. Error: \(arrayDecodeError). Will try as single CommandEnvelope.")
                do {
                    let command = try decoder.decode(CommandEnvelope.self, from: data)
                    axDebugLog("AXORCMain Test: Decode attempt 2: Successfully decoded as SINGLE CommandEnvelope.")
                    processAndExecuteCommand(command: command, axorcist: axorcistInstance, debugCLI: debug)
                } catch let singleDecodeError {
                    axDebugLog("AXORCMain Test: Decode attempt 2 (as single CommandEnvelope) ALSO FAILED. Error: \(singleDecodeError). Original array decode error was: \(arrayDecodeError)")
                    let errorResponse = ErrorResponse(
                        commandId: "decode_error",
                        error: "Failed to decode JSON input: \(singleDecodeError.localizedDescription)",
                        debugLogs: debug ? axGetLogsAsStrings() : nil
                    )
                    if let jsonData = try? JSONEncoder().encode(errorResponse), let jsonErrorString = String(data: jsonData, encoding: .utf8) {
                        print(jsonErrorString)
                    } else {
                        print("{\"error\": \"Failed to encode decode error response: \(singleDecodeError.localizedDescription)\"}")
                    }
                    return
                }
            }
        } else {
            axDebugLog("AXORCMain Test: Failed to convert jsonStringFromInput to data.")
            let errorResponse = ErrorResponse(commandId: "data_conversion_error", error: "Failed to convert JSON string to data", debugLogs: debug ? axGetLogsAsStrings() : nil)
            if let jsonData = try? JSONEncoder().encode(errorResponse), let jsonErrorString = String(data: jsonData, encoding: .utf8) {
                print(jsonErrorString)
            } else {
                print("{\"error\": \"Failed to encode data conversion error response\"}")
            }
            return
        }

        // After processing all commands or if an error occurs
        if debug && commandShouldPrintLogsAtEnd() {
            let logMessages = axGetLogsAsStrings(format: .text)
            if !logMessages.isEmpty {
                fputs("\n--- Debug Logs (axorc run end) ---\n", stderr)
                for logMessage in logMessages {
                    fputs(logMessage + "\n", stderr)
                }
                fputs("--- End Debug Logs ---\n", stderr)
                fflush(stderr)
            }
        }
    }

    private func commandShouldPrintLogsAtEnd() -> Bool {
        // This is a simplified check. A more robust way would be to check
        // the actual command type if it's available here.
        // For now, if stdin is true or json is provided, assume it might be an observe command.
        // This is imperfect.
        if let jsonString = InputHandler.parseInput(stdin: stdin, file: file, json: json, directPayload: directPayload).jsonString,
           let inputData = jsonString.data(using: .utf8) { // Corrected optional chaining and conditional binding
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let commands = try? decoder.decode([CommandEnvelope].self, from: inputData),
               commands.first?.command == .observe {
                return false
            }
            if let command = try? decoder.decode(CommandEnvelope.self, from: inputData),
               command.command == .observe {
                return false
            }
        }
        return true
    }
}

// ErrorResponse struct is now defined in AXORCModels.swift
// struct ErrorResponse: Codable {
// var commandId: String
// var status: String = "error"
// var error: String
// var debugLogs: [String]?
// }
