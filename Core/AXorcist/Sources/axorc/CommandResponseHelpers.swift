// CommandResponseHelpers.swift - Response handling and encoding utilities

import AXorcist
import Foundation

// MARK: - Response Types

struct FinalResponse: Codable {
    let commandId: String
    let commandType: String
    let status: String
    let data: AnyCodable?
    let error: String?
    var debugLogs: [String]?
}

struct ProcessTrustedResponse: Codable {
    let commandId: String
    let status: String
    let trusted: Bool
}

struct AXFeatureEnabledResponse: Codable {
    let commandId: String
    let status: String
    let enabled: Bool
}

// MARK: - Response Helpers

func finalizeAndEncodeResponse(
    commandId: String,
    commandType: String,
    handlerResponse: HandlerResponse,
    debugCLI: Bool,
    commandDebugLogging: Bool
) -> String {
    let responseStatus = handlerResponse.error == nil ? "success" : "error"

    var finalResponseObject = FinalResponse(
        commandId: commandId,
        commandType: commandType,
        status: responseStatus,
        data: handlerResponse.data,
        error: handlerResponse.error
    )

    if debugCLI || commandDebugLogging {
        let logsForResponse = axGetLogsAsStrings()
        finalResponseObject.debugLogs = logsForResponse
    }

    if let encoded = encodeToJson(finalResponseObject) {
        return encoded
    }

    return "{\"error\": \"JSON encoding failed\", \"commandId\": \"\(commandId)\"}"
}

func encodeToJson(_ object: some Encodable) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.keyEncodingStrategy = .convertToSnakeCase

    do {
        let data = try encoder.encode(object)
        return String(data: data, encoding: .utf8)
    } catch let encodingError as EncodingError {
        axErrorLog("JSON encoding failed with EncodingError: \(encodingError.detailedDescription)")
        return nil
    } catch {
        axErrorLog("JSON encoding failed: \(error.localizedDescription)")
        return nil
    }
}

extension EncodingError {
    @preconcurrency nonisolated var detailedDescription: String {
        switch self {
        case let .invalidValue(value, context):
            let pathDescription = MainActor.assumeIsolated {
                context.codingPath.map { $0.stringValue }.joined(separator: ".")
            }
            return [
                "InvalidValue: '\(value)' attempting to encode at path '\(pathDescription)'.",
                "Debug: \(context.debugDescription)"
            ].joined(separator: " ")
        @unknown default:
            return "Unknown encoding error. Localized: \(self.localizedDescription)"
        }
    }
}
