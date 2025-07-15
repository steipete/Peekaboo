// AXORCModels.swift - Response models and main types for AXORC CLI

import ArgumentParser

// Potentially AXorcist if common types are defined there and used here
import AXorcist
import Foundation

// MARK: - Version and Configuration

let axorcVersion = "0.1.3"

/// Returns a human-readable build stamp (yyMMddHHmm) evaluated at runtime.
/// Good enough for confirming we're on the binary we just built.
var axorcBuildStamp: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyMMddHHmm"
    return formatter.string(from: Date())
}

// MARK: - Shared Error Detail

// Moved ErrorDetail to be a top-level struct
struct ErrorDetail: Codable {
    let message: String
}

// MARK: - Response Models

// These should align with structs in AXorcistIntegrationTests.swift

struct SimpleSuccessResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case commandId
        case success
        case status
        case message
        case details
        case debugLogs
    }

    let commandId: String
    let success: Bool
    let status: String? // e.g., "pong"
    let message: String
    let details: String?
    let debugLogs: [String]?
}

struct ErrorResponse: Codable {
    // MARK: Lifecycle

    init(commandId: String, error: String, debugLogs: [String]? = nil) {
        self.commandId = commandId
        self.success = false
        self.error = ErrorDetail(message: error)
        self.debugLogs = debugLogs
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case commandId
        case success
        case error
        case debugLogs
    }

    let commandId: String
    var success: Bool = false // Default to false for errors
    let error: ErrorDetail
    let debugLogs: [String]?
}

// This is a pass-through structure. AXorcist.AXElement should be Codable itself.
// If AXorcist.AXElement is not Codable, then this needs to be manually constructed.
// For now, treating AXElement as having attributes: [String: AnyCodable] which should be Codable if AnyCodable is
// Codable.

struct AXElementForEncoding: Codable {
    // MARK: Lifecycle

    init(from axElement: AXElement) {
        self.attributes = axElement.attributes
        self.path = axElement.path
    }

    // MARK: Internal

    let attributes: [String: AnyCodable]?
    let path: [String]?
}

struct QueryResponse: Codable {
    // MARK: Lifecycle

    // Custom initializer to bridge from HandlerResponse (from AXorcist module)
    init(commandId: String, success: Bool, command: String, handlerResponse: HandlerResponse, debugLogs: [String]?) {
        self.commandId = commandId
        self.success = success
        self.command = command
        if let anyCodableData = handlerResponse.data,
           let axElement = anyCodableData.value as? AXElement
        {
            self.data = AXElementForEncoding(from: axElement) // Convert here
        } else {
            self.data = nil
        }
        if let errorMsg = handlerResponse.error {
            self.error = ErrorDetail(message: errorMsg)
        } else {
            self.error = nil
        }
        self.debugLogs = debugLogs
    }

    // Legacy initializer for compatibility
    init(success: Bool = true,
         commandId: String? = nil,
         command: String? = nil,
         axElement: AXElement? = nil,
         attributes _: [String: AnyCodable]? = nil,
         error: String? = nil,
         debugLogs: [String]? = nil)
    {
        self.commandId = commandId ?? "unknown"
        self.success = success
        self.command = command ?? "unknown"
        self.data = axElement != nil ? AXElementForEncoding(from: axElement!) : nil
        if let errorMessage = error {
            self.error = ErrorDetail(message: errorMessage)
        } else {
            self.error = nil
        }
        self.debugLogs = debugLogs
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case commandId
        case success
        case command
        case data
        case error
        case debugLogs
    }

    let commandId: String
    let success: Bool
    let command: String // Name of the command, e.g., "getFocusedElement"
    let data: AXElementForEncoding? // Contains the AX element's data, adapted for encoding
    let error: ErrorDetail?
    let debugLogs: [String]?
}

struct BatchResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case commandId
        case success
        case results
        case debugLogs
    }

    let commandId: String
    let success: Bool
    let results: [QueryResponse]
    let debugLogs: [String]?
}

// For batch operations that may have mixed results
struct BatchQueryResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case commandId
        case status
        case message
        case data
        case errors
        case debugLogs
    }

    let commandId: String
    let status: String
    var message: String?
    var data: [AnyCodable?]?
    var errors: [String]?
    var debugLogs: [String]?
}

// Generic query response for commands (renamed to avoid conflict)
struct GenericQueryResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case commandId
        case commandType
        case status
        case data
        case message
        case debugLogs
    }

    let commandId: String
    let commandType: String
    let status: String
    let data: AnyCodable?
    let message: String?
    var debugLogs: [String]?
}

// Helper for DecodingError display
extension DecodingError {
    var humanReadableDescription: String {
        switch self {
        case let .typeMismatch(
            type,
            context
        ): return "Type mismatch for \(type): \(context.debugDescription) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .valueNotFound(
            type,
            context
        ): return "Value not found for \(type): \(context.debugDescription) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .keyNotFound(
            key,
            context
        ): return "Key not found: \(key.stringValue) at \(context.codingPath.map(\.stringValue).joined(separator: ".")) - \(context.debugDescription)"
        case let .dataCorrupted(context): return "Data corrupted: \(context.debugDescription) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default: return self.localizedDescription
        }
    }
}
