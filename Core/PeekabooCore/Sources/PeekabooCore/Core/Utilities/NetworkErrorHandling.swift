import Foundation

// MARK: - API Error Response Protocol

/// Common protocol for API error responses
public protocol APIErrorResponse: Decodable {
    var message: String { get }
    var code: String? { get }
    var type: String? { get }
}

// MARK: - Generic Error Response

/// Generic error response that works with most APIs
public struct GenericErrorResponse: APIErrorResponse {
    public let message: String
    public let code: String?
    public let type: String?
    
    // Support various field names
    private enum CodingKeys: String, CodingKey {
        case message
        case error
        case errorMessage = "error_message"
        case code
        case errorCode = "error_code"
        case type
        case errorType = "error_type"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try different message fields
        if let message = try? container.decode(String.self, forKey: .message) {
            self.message = message
        } else if let error = try? container.decode(String.self, forKey: .error) {
            self.message = error
        } else if let errorMessage = try? container.decode(String.self, forKey: .errorMessage) {
            self.message = errorMessage
        } else {
            // Try nested error object
            if let errorDict = try? container.decode([String: String].self, forKey: .error),
               let message = errorDict["message"] {
                self.message = message
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.message,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "No error message found"
                    )
                )
            }
        }
        
        self.code = try? container.decode(String.self, forKey: .code) ??
                    container.decode(String.self, forKey: .errorCode)
        self.type = try? container.decode(String.self, forKey: .type) ??
                    container.decode(String.self, forKey: .errorType)
    }
}

// MARK: - HTTP Error Handling

extension URLSession {
    /// Handle error responses in a generic way
    public func handleErrorResponse(
        data: Data,
        response: URLResponse,
        context: String
    ) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PeekabooError.networkError("Invalid response type")
        }
        
        // Success codes don't need error handling
        guard httpResponse.statusCode >= 400 else { return }
        
        // Try to decode error response
        if let errorResponse = try? JSONCoding.decoder.decode(GenericErrorResponse.self, from: data) {
            let errorMessage = formatAPIError(
                errorResponse,
                statusCode: httpResponse.statusCode,
                context: context
            )
            throw PeekabooError.apiError(
                code: httpResponse.statusCode,
                message: errorMessage
            )
        }
        
        // Fallback to raw response
        let rawResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw PeekabooError.apiError(
            code: httpResponse.statusCode,
            message: "\(context): HTTP \(httpResponse.statusCode) - \(rawResponse)"
        )
    }
    
    /// Handle provider-specific error response
    public func handleErrorResponse<E: APIErrorResponse>(
        _ type: E.Type,
        data: Data,
        response: URLResponse,
        context: String
    ) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PeekabooError.networkError("Invalid response type")
        }
        
        // Success codes don't need error handling
        guard httpResponse.statusCode >= 400 else { return }
        
        // Try to decode specific error type
        if let errorResponse = try? JSONCoding.decoder.decode(type, from: data) {
            let errorMessage = formatAPIError(
                errorResponse,
                statusCode: httpResponse.statusCode,
                context: context
            )
            throw PeekabooError.apiError(
                code: httpResponse.statusCode,
                message: errorMessage
            )
        }
        
        // Fallback to generic handling
        try handleErrorResponse(data: data, response: response, context: context)
    }
}

// MARK: - Error Formatting

private func formatAPIError(
    _ error: APIErrorResponse,
    statusCode: Int,
    context: String
) -> String {
    var message = "\(context): \(error.message)"
    
    if let code = error.code {
        message += " (code: \(code))"
    }
    
    if let type = error.type {
        message += " [type: \(type)]"
    }
    
    message += " [HTTP \(statusCode)]"
    
    return message
}

// MARK: - Common HTTP Status Handling

extension PeekabooError {
    /// Create appropriate PeekabooError based on HTTP status code
    public static func fromHTTPStatus(
        _ statusCode: Int,
        message: String,
        context: String
    ) -> PeekabooError {
        switch statusCode {
        case 400:
            return .invalidInput("\(context): Bad request - \(message)")
        case 401:
            return .authenticationFailed("\(context): \(message)")
        case 403:
            return .permissionDenied("\(context): \(message)")
        case 404:
            return .notFound("\(context): \(message)")
        case 429:
            return .rateLimited(retryAfter: nil, message: "\(context): \(message)")
        case 500...599:
            return .serverError("\(context): \(message)")
        default:
            return .apiError(code: statusCode, message: "\(context): \(message)")
        }
    }
}