// AXORCModels.swift - Response models and main types for AXORC CLI

import ArgumentParser
import AXorcistLib
import Foundation

// MARK: - Version and Configuration
let AXORC_VERSION = "0.1.2a-config_fix"

// MARK: - Response Models
// These should align with structs in AXorcistIntegrationTests.swift

struct SimpleSuccessResponse: Codable {
    let command_id: String
    let success: Bool
    let status: String? // e.g., "pong"
    let message: String
    let details: String?
    let debug_logs: [String]?
}

struct ErrorResponse: Codable {
    let command_id: String
    var success: Bool = false // Default to false for errors
    struct ErrorDetail: Codable {
        let message: String
    }
    let error: ErrorDetail
    let debug_logs: [String]?
}

// This is a pass-through structure. AXorcist.AXElement should be Codable itself.
// If AXorcist.AXElement is not Codable, then this needs to be manually constructed.
// For now, treating AXElement as having attributes: [String: AnyCodable] which should be Codable if AnyCodable is Codable.

struct AXElementForEncoding: Codable {
    let attributes: [String: AnyCodable]? // This will now use AXorcist.AnyCodable
    let path: [String]?

    init(from axElement: AXElement) { // axElement is AXorcist.AXElement
        self.attributes = axElement.attributes // Directly assign
        self.path = axElement.path
    }
}

struct QueryResponse: Codable {
    let command_id: String
    let success: Bool
    let command: String // Name of the command, e.g., "getFocusedElement"
    let data: AXElementForEncoding? // Contains the AX element's data, adapted for encoding
    let error: ErrorResponse.ErrorDetail?
    let debug_logs: [String]?

    // Custom initializer to bridge from HandlerResponse (from AXorcist module)
    init(command_id: String, success: Bool, command: String, handlerResponse: HandlerResponse, debug_logs: [String]?) {
        self.command_id = command_id
        self.success = success
        self.command = command
        if let axElement = handlerResponse.data {
            self.data = AXElementForEncoding(from: axElement) // Convert here
        } else {
            self.data = nil
        }
        if let errorMsg = handlerResponse.error {
            self.error = ErrorResponse.ErrorDetail(message: errorMsg)
        } else {
            self.error = nil
        }
        self.debug_logs = debug_logs
    }

    // Legacy initializer for compatibility
    init(success: Bool = true, commandId: String? = nil, command: String? = nil,
         axElement: AXElement? = nil, attributes: [String: AnyCodable]? = nil,
         error: String? = nil, debugLogs: [String]? = nil) {
        self.command_id = commandId ?? "unknown"
        self.success = success
        self.command = command ?? "unknown"
        self.data = axElement != nil ? AXElementForEncoding(from: axElement!) : nil
        if let errorMessage = error {
            self.error = ErrorResponse.ErrorDetail(message: errorMessage)
        } else {
            self.error = nil
        }
        self.debug_logs = debugLogs
    }
}

struct BatchOperationResponse: Codable {
    let command_id: String
    let success: Bool
    let results: [QueryResponse]
    let debug_logs: [String]?
}

// Helper for DecodingError display
extension DecodingError {
    var humanReadableDescription: String {
        switch self {
        case .typeMismatch(
            let type,
            let context
        ): return "Type mismatch for \(type): \(context.debugDescription) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(
            let type,
            let context
        ): return "Value not found for \(type): \(context.debugDescription) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .keyNotFound(
            let key,
            let context
        ): return "Key not found: \(key.stringValue) at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
        case .dataCorrupted(let context): return "Data corrupted: \(context.debugDescription) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        @unknown default: return self.localizedDescription
        }
    }
}
