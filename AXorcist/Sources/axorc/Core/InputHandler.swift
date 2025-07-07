// InputHandler.swift - Handles input parsing for AXORC CLI

import AXorcist // For ax...Log helpers
import Foundation

enum InputHandler {
    // MARK: Internal

    struct ParseResult {
        let jsonString: String?
        let sourceDescription: String
        let error: String?
    }

    static func parseInput(
        stdin: Bool,
        file: String?,
        json: String?,
        directPayload: String?
    ) -> ParseResult {
        axDebugLog("InputHandler: Parsing input...")

        let activeInputFlags = (stdin ? 1 : 0) + (file != nil ? 1 : 0) + (json != nil ? 1 : 0)
        let positionalPayloadProvided = directPayload != nil &&
            !(directPayload?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if activeInputFlags > 1 {
            return handleMultipleInputFlags()
        } else if stdin {
            return handleStdinInput()
        } else if let filePath = file {
            return handleFileInput(filePath: filePath)
        } else if let jsonString = json {
            axDebugLog("Using --json flag with payload of \(jsonString.count) characters.")
            let trimmedJsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedJsonString.isEmpty {
                let error = "Error: --json argument was provided but the string is empty or only whitespace."
                axErrorLog(error)
                return ParseResult(jsonString: nil, sourceDescription: "--json argument", error: error)
            }
            return ParseResult(jsonString: trimmedJsonString, sourceDescription: "--json argument", error: nil)
        } else if positionalPayloadProvided {
            return handleDirectPayload(directPayload: directPayload)
        } else {
            return handleNoInput()
        }
    }

    // MARK: Private

    // MARK: - Helper Functions

    private static func handleMultipleInputFlags() -> ParseResult {
        let error = "Error: Multiple input flags specified (--stdin, --file, --json). Only one is allowed."
        axErrorLog(error)
        return ParseResult(jsonString: nil, sourceDescription: error, error: error)
    }

    private static func handleStdinInput() -> ParseResult {
        let stdInputHandle = FileHandle.standardInput
        let stdinData = stdInputHandle.readDataToEndOfFile()

        if let str = String(data: stdinData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty
        {
            axDebugLog("Successfully read \(str.count) characters from STDIN.")
            return ParseResult(jsonString: str, sourceDescription: "STDIN", error: nil)
        } else {
            let error = "No data received from STDIN or data was empty."
            axErrorLog("Failed to read from STDIN or received empty data.")
            return ParseResult(jsonString: nil, sourceDescription: "STDIN", error: error)
        }
    }

    private static func handleFileInput(
        filePath: String
    ) -> ParseResult {
        let sourceDescription = "File: \(filePath)"

        do {
            let rawFileContent = try String(contentsOfFile: filePath, encoding: .utf8) // Read raw
            axDebugLog(
                "HFI_DEBUG: Raw file content for [\(filePath)]: '\(rawFileContent)' (length: \(rawFileContent.count))"
            )

            let str = rawFileContent.trimmingCharacters(in: .whitespacesAndNewlines)
            axDebugLog("HFI_DEBUG: Trimmed file content: '\(str)' (length: \(str.count))")

            if !str.isEmpty {
                axDebugLog("Successfully read \(str.count) characters from file: \(filePath)")
                return ParseResult(jsonString: str, sourceDescription: sourceDescription, error: nil)
            } else {
                let error = "File \(filePath) is empty or contains only whitespace."
                axWarningLog("File \(filePath) was empty or contained only whitespace.")
                return ParseResult(jsonString: nil, sourceDescription: sourceDescription, error: error)
            }
        } catch {
            let errorMsg = "Failed to read file \(filePath): \(error.localizedDescription)"
            axErrorLog("Error reading file \(filePath): \(error)")
            return ParseResult(jsonString: nil, sourceDescription: sourceDescription, error: errorMsg)
        }
    }

    private static func handleDirectPayload(
        directPayload: String?
    ) -> ParseResult {
        let jsonString = directPayload?.trimmingCharacters(in: .whitespacesAndNewlines)
        axDebugLog("Using direct payload argument with \(jsonString?.count ?? 0) characters.")
        return ParseResult(jsonString: jsonString, sourceDescription: "Direct argument", error: nil)
    }

    private static func handleNoInput() -> ParseResult {
        let error =
            "No input provided. Use --stdin, --file <path>, --json <json_string>, or provide JSON as a direct argument."
        axErrorLog("No input method specified and no direct payload provided.")
        return ParseResult(jsonString: nil, sourceDescription: "No input", error: error)
    }
}
