// ResponseModels.swift - Contains response model structs for AXorcist commands

import Foundation

// Response for query command (single element)
public struct QueryResponse: Codable {
    public var command_id: String
    public var success: Bool
    public var command: String
    public var data: AXElement?
    public var attributes: ElementAttributes?
    public var error: String?
    public var debug_logs: [String]?

    public init(command_id: String, success: Bool = true, command: String = "getFocusedElement", data: AXElement? = nil,
                attributes: ElementAttributes? = nil, error: String? = nil, debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.success = success
        self.command = command
        self.data = data
        self.attributes = attributes
        self.error = error
        self.debug_logs = debug_logs
    }

    // Custom init for HandlerResponse integration
    public init(command_id: String, success: Bool, command: String, handlerResponse: HandlerResponse, debug_logs: [String]?) {
        self.command_id = command_id
        self.success = success
        self.command = command
        self.data = handlerResponse.data
        // If HandlerResponse has attributes, map them from its data field.
        self.attributes = handlerResponse.data?.attributes
        self.error = handlerResponse.error
        self.debug_logs = debug_logs
    }
}

// Extension to add JSON encoding functionality to QueryResponse
extension QueryResponse {
    public func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// Response for collect_all command (multiple elements)
public struct MultiQueryResponse: Codable {
    public var command_id: String
    public var elements: [ElementAttributes]?
    public var count: Int?
    public var error: String?
    public var debug_logs: [String]?

    public init(command_id: String, elements: [ElementAttributes]? = nil, count: Int? = nil, error: String? = nil,
                debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.elements = elements
        self.count = count ?? elements?.count
        self.error = error
        self.debug_logs = debug_logs
    }
}

// Response for perform_action command
public struct PerformResponse: Codable {
    public var command_id: String
    public var success: Bool
    public var error: String?
    public var debug_logs: [String]?

    public init(command_id: String, success: Bool, error: String? = nil, debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.success = success
        self.error = error
        self.debug_logs = debug_logs
    }
}

// Response for extract_text command
public struct TextContentResponse: Codable {
    public var command_id: String
    public var text_content: String?
    public var error: String?
    public var debug_logs: [String]?

    public init(command_id: String, text_content: String? = nil, error: String? = nil, debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.text_content = text_content
        self.error = error
        self.debug_logs = debug_logs
    }
}

// Generic error response
public struct ErrorResponse: Codable {
    public var command_id: String
    public var success: Bool
    public var error: ErrorDetail
    public var debug_logs: [String]?

    public init(command_id: String, error: String, debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.success = false
        self.error = ErrorDetail(message: error)
        self.debug_logs = debug_logs
    }
}

public struct ErrorDetail: Codable {
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

// Simple success response, e.g. for ping
public struct SimpleSuccessResponse: Codable, Equatable {
    public var command_id: String
    public var success: Bool
    public var status: String
    public var message: String
    public var details: String?
    public var debug_logs: [String]?

    public init(command_id: String, status: String, message: String, details: String? = nil,
                debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.success = true
        self.status = status
        self.message = message
        self.details = details
        self.debug_logs = debug_logs
    }
}

public struct HandlerResponse: Codable {
    public var data: AXElement?
    public var error: String?
    public var debug_logs: [String]?

    public init(data: AXElement? = nil, error: String? = nil, debug_logs: [String]? = nil) {
        self.data = data
        self.error = error
        self.debug_logs = debug_logs
    }
}

public struct BatchResponse: Codable {
    public var command_id: String
    public var success: Bool
    public var results: [HandlerResponse] // Array of HandlerResponses for each sub-command
    public var error: String? // For an overall batch error, if any
    public var debug_logs: [String]?

    public init(command_id: String, success: Bool, results: [HandlerResponse], error: String? = nil, debug_logs: [String]? = nil) {
        self.command_id = command_id
        self.success = success
        self.results = results
        self.error = error
        self.debug_logs = debug_logs
    }
}

// Structure for custom JSON output of handleCollectAll
internal struct CollectAllOutput: Encodable {
    let command_id: String
    let success: Bool
    let command: String
    let collected_elements: [AXElement]
    let app_bundle_id: String?
    let debug_logs: [String]?
}
