import Foundation

// MARK: - Network Extensions for Agent

extension URLSession {
    /// Performs a retryable data request with exponential backoff
    func retryableDataTask<T: Decodable>(
        for request: URLRequest,
        decodingType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<retryConfig.maxAttempts {
            do {
                let (data, response) = try await self.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AgentError.invalidResponse("Not an HTTP response")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - decode and return
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                    
                case 429:
                    // Rate limited - check for retry-after header
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { Double($0) }
                    throw AgentError.rateLimited(retryAfter: retryAfter)
                    
                case 401:
                    throw AgentError.apiError("Invalid API key")
                    
                case 400...499:
                    // Client error - try to decode error message
                    if let errorMessage = try? JSONDecoder().decode(OpenAIError.self, from: data).error.message {
                        throw AgentError.apiError(errorMessage)
                    } else {
                        throw AgentError.apiError("Client error: \(httpResponse.statusCode)")
                    }
                    
                case 500...599:
                    // Server error - will retry
                    throw AgentError.apiError("Server error: \(httpResponse.statusCode)")
                    
                default:
                    throw AgentError.invalidResponse("Unexpected status code: \(httpResponse.statusCode)")
                }
                
            } catch {
                lastError = error
                
                // Check if we should retry
                let shouldRetry = switch error {
                case is URLError where (error as! URLError).code == .timedOut,
                     is URLError where (error as! URLError).code == .networkConnectionLost,
                     AgentError.rateLimited:
                    true
                case AgentError.apiError(let msg) where msg.contains("Server error"):
                    true
                default:
                    false
                }
                
                if shouldRetry && attempt < retryConfig.maxAttempts - 1 {
                    let delay = retryConfig.delay(for: attempt)
                    
                    // If rate limited with retry-after, use that instead
                    if case .rateLimited(let retryAfter?) = error as? AgentError {
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    } else {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    continue
                } else {
                    // Don't retry, throw the error
                    throw error
                }
            }
        }
        
        throw lastError ?? AgentError.timeout
    }
    
    /// Performs a retryable data request returning raw data
    func retryableData(
        for request: URLRequest,
        retryConfig: RetryConfiguration = .default
    ) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        
        for attempt in 0..<retryConfig.maxAttempts {
            do {
                let (data, response) = try await self.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AgentError.invalidResponse("Not an HTTP response")
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    return (data, httpResponse)
                }
                
                // Handle errors same as above
                switch httpResponse.statusCode {
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { Double($0) }
                    throw AgentError.rateLimited(retryAfter: retryAfter)
                case 401:
                    throw AgentError.apiError("Invalid API key")
                case 400...499:
                    throw AgentError.apiError("Client error: \(httpResponse.statusCode)")
                case 500...599:
                    throw AgentError.apiError("Server error: \(httpResponse.statusCode)")
                default:
                    throw AgentError.invalidResponse("Unexpected status code: \(httpResponse.statusCode)")
                }
                
            } catch {
                lastError = error
                
                if attempt < retryConfig.maxAttempts - 1 {
                    let delay = retryConfig.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    throw error
                }
            }
        }
        
        throw lastError ?? AgentError.timeout
    }
}

// MARK: - OpenAI Error Response

struct OpenAIError: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Request Builders

extension URLRequest {
    static func openAIRequest(
        url: URL,
        method: String = "POST",
        apiKey: String,
        betaHeader: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let betaHeader = betaHeader {
            request.setValue(betaHeader, forHTTPHeaderField: "OpenAI-Beta")
        }
        request.timeoutInterval = 30.0
        return request
    }
    
    mutating func setJSONBody<T: Encodable>(_ body: T) throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        self.httpBody = try encoder.encode(body)
    }
}