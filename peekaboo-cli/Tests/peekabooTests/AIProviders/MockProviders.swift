import Foundation
@testable import peekaboo

// MARK: - Mock Providers for Testing

struct MockSuccessProvider: AIProvider {
    let name: String
    let model: String
    let mockResponse: String
    let mockDelay: TimeInterval

    init(
        name: String = "mock",
        model: String = "test-model",
        mockResponse: String = "Mock analysis result",
        mockDelay: TimeInterval = 0
    ) {
        self.name = name
        self.model = model
        self.mockResponse = mockResponse
        self.mockDelay = mockDelay
    }

    var isAvailable: Bool {
        get async {
            true
        }
    }

    func checkAvailability() async -> AIProviderStatus {
        AIProviderStatus(
            available: true,
            error: nil,
            details: AIProviderDetails(
                modelAvailable: true,
                serverReachable: true,
                apiKeyPresent: true,
                modelList: ["test-model", "other-model"]
            )
        )
    }

    func analyze(imageBase64: String, question: String) async throws -> String {
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        return mockResponse
    }
}

struct MockFailureProvider: AIProvider {
    let name: String
    let model: String
    let error: AIProviderError

    init(name: String = "mock-fail", model: String = "fail-model", error: AIProviderError = .unknown("Mock error")) {
        self.name = name
        self.model = model
        self.error = error
    }

    var isAvailable: Bool {
        get async {
            false
        }
    }

    func checkAvailability() async -> AIProviderStatus {
        AIProviderStatus(
            available: false,
            error: error.localizedDescription,
            details: AIProviderDetails(
                modelAvailable: false,
                serverReachable: false,
                apiKeyPresent: false,
                modelList: nil
            )
        )
    }

    func analyze(imageBase64: String, question: String) async throws -> String {
        throw error
    }
}

struct MockUnavailableProvider: AIProvider {
    let name: String
    let model: String

    init(name: String = "mock-unavailable", model: String = "unavailable-model") {
        self.name = name
        self.model = model
    }

    var isAvailable: Bool {
        get async {
            false
        }
    }

    func checkAvailability() async -> AIProviderStatus {
        AIProviderStatus(
            available: false,
            error: "Provider not available",
            details: AIProviderDetails(
                modelAvailable: false,
                serverReachable: false,
                apiKeyPresent: true,
                modelList: []
            )
        )
    }

    func analyze(imageBase64: String, question: String) async throws -> String {
        throw AIProviderError.notConfigured("Provider not available")
    }
}

// MARK: - Mock HTTP Session for Testing Real Providers

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockResponses: [URL: (data: Data?, response: URLResponse?, error: Error?)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let mockResponse = MockURLProtocol.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if let response = mockResponse.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = mockResponse.data {
            client?.urlProtocol(self, didLoad: data)
        }

        if let error = mockResponse.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        // Nothing to do
    }

    static func reset() {
        mockResponses.removeAll()
    }
}
