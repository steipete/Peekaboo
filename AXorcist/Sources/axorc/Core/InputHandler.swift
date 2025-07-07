// InputHandler.swift - Handles input parsing for AXORC CLI

import Foundation

struct InputHandler {

    static func parseInput(
        stdin: Bool,
        file: String?,
        json: String?,
        directPayload: String?,
        debug: Bool
    ) -> (jsonString: String?, sourceDescription: String, error: String?, debugLogs: [String]) {

        var localDebugLogs: [String] = []
        if debug {
            localDebugLogs.append("Debug logging enabled by --debug flag.")
        }

        let activeInputFlags = (stdin ? 1 : 0) + (file != nil ? 1 : 0) + (json != nil ? 1 : 0)
        let positionalPayloadProvided = directPayload != nil &&
            !(directPayload?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if activeInputFlags > 1 {
            return handleMultipleInputFlags(&localDebugLogs)
        } else if stdin {
            return handleStdinInput(debug: debug, debugLogs: &localDebugLogs)
        } else if let filePath = file {
            return handleFileInput(filePath: filePath, debug: debug, debugLogs: &localDebugLogs)
        } else if let jsonString = json {
            if debug {
                localDebugLogs.append("Using --json flag with payload of \\(jsonString.count) characters.")
            }
            let trimmedJsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedJsonString.isEmpty {
                let error = "Error: --json argument was provided but the string is empty or only whitespace."
                if debug { localDebugLogs.append(error) }
                return (nil, "--json argument", error, localDebugLogs)
            }
            return (trimmedJsonString, "--json argument", nil, localDebugLogs)
        } else if positionalPayloadProvided {
            return handleDirectPayload(directPayload: directPayload, debug: debug, debugLogs: &localDebugLogs)
        } else {
            return handleNoInput(debug: debug, debugLogs: &localDebugLogs)
        }
    }

    // MARK: - Helper Functions

    private static func handleMultipleInputFlags(
        _ debugLogs: inout [String]
    ) -> (jsonString: String?, sourceDescription: String, error: String?, debugLogs: [String]) {
        let error = "Error: Multiple input flags specified (--stdin, --file, --json). Only one is allowed."
        return (nil, error, error, debugLogs)
    }

    private static func handleStdinInput(
        debug: Bool,
        debugLogs: inout [String]
    ) -> (jsonString: String?, sourceDescription: String, error: String?, debugLogs: [String]) {
        let stdInputHandle = FileHandle.standardInput
        let stdinData = stdInputHandle.readDataToEndOfFile()

        if let str = String(data: stdinData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            if debug {
                debugLogs.append("Successfully read \(str.count) characters from STDIN.")
            }
            return (str, "STDIN", nil, debugLogs)
        } else {
            let error = "No data received from STDIN or data was empty."
            if debug {
                debugLogs.append("Failed to read from STDIN or received empty data.")
            }
            return (nil, "STDIN", error, debugLogs)
        }
    }

    private static func handleFileInput(
        filePath: String,
        debug: Bool,
        debugLogs: inout [String]
    ) -> (jsonString: String?, sourceDescription: String, error: String?, debugLogs: [String]) {
        let sourceDescription = "File: \(filePath)"

        do {
            let rawFileContent = try String(contentsOfFile: filePath, encoding: .utf8) // Read raw
            if debug {
                debugLogs.append("HFI_DEBUG: Raw file content for [\(filePath)]: '\(rawFileContent)' (length: \(rawFileContent.count))")
            }

            let str = rawFileContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if debug {
                debugLogs.append("HFI_DEBUG: Trimmed file content: '\(str)' (length: \(str.count))")
            }

            if !str.isEmpty {
                if debug {
                    debugLogs.append("Successfully read \(str.count) characters from file: \(filePath)")
                }
                return (str, sourceDescription, nil, debugLogs)
            } else {
                let error = "File \(filePath) is empty or contains only whitespace."
                if debug {
                    debugLogs.append("File \(filePath) was empty or contained only whitespace.")
                }
                return (nil, sourceDescription, error, debugLogs)
            }
        } catch {
            let errorMsg = "Failed to read file \(filePath): \(error.localizedDescription)"
            if debug {
                debugLogs.append("Error reading file \(filePath): \(error)")
            }
            return (nil, sourceDescription, errorMsg, debugLogs)
        }
    }

    private static func handleDirectPayload(
        directPayload: String?,
        debug: Bool,
        debugLogs: inout [String]
    ) -> (jsonString: String?, sourceDescription: String, error: String?, debugLogs: [String]) {
        let jsonString = directPayload?.trimmingCharacters(in: .whitespacesAndNewlines)
        if debug {
            debugLogs.append("Using direct payload argument with \(jsonString?.count ?? 0) characters.")
        }
        return (jsonString, "Direct argument", nil, debugLogs)
    }

    private static func handleNoInput(
        debug: Bool,
        debugLogs: inout [String]
    ) -> (jsonString: String?, sourceDescription: String, error: String?, debugLogs: [String]) {
        let error = "No input provided. Use --stdin, --file <path>, --json <json_string>, or provide JSON as a direct argument."
        if debug {
            debugLogs.append("No input method specified and no direct payload provided.")
        }
        return (nil, "No input", error, debugLogs)
    }
}
