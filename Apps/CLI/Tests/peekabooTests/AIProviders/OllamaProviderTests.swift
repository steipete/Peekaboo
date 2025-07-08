import XCTest
@testable import peekaboo

final class OllamaProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.reset()
    }

    func testOllamaProviderInitialization() {
        let provider = OllamaProvider(model: "llava:latest")
        XCTAssertEqual(provider.name, "ollama")
        XCTAssertEqual(provider.model, "llava:latest")

        let defaultProvider = OllamaProvider()
        XCTAssertEqual(defaultProvider.model, "llava:latest")
    }

    func testCheckAvailabilityWithRunningServer() async {
        let mockTagsResponse = """
        {
            "models": [
                {"name": "llava:latest", "modified_at": "2024-01-01T00:00:00Z", "size": 1000000},
                {"name": "llama2:latest", "modified_at": "2024-01-01T00:00:00Z", "size": 2000000}
            ]
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/tags")!
        MockURLProtocol.mockResponses[url] = (
            data: mockTagsResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil)

        let provider = TestableOllamaProvider(model: "llava:latest", session: session)

        let isAvailable = await provider.isAvailable
        XCTAssertTrue(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertTrue(status.available)
        XCTAssertNil(status.error)
        XCTAssertEqual(status.details?.serverReachable, true)
        XCTAssertEqual(status.details?.modelAvailable, true)
        XCTAssertEqual(status.details?.modelList?.count, 2)
    }

    func testCheckAvailabilityWithoutModel() async {
        let mockTagsResponse = """
        {
            "models": [
                {"name": "llama2:latest", "modified_at": "2024-01-01T00:00:00Z", "size": 2000000}
            ]
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/tags")!
        MockURLProtocol.mockResponses[url] = (
            data: mockTagsResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil)

        let provider = TestableOllamaProvider(model: "llava:latest", session: session)

        let isAvailable = await provider.isAvailable
        XCTAssertFalse(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertFalse(status.available)
        XCTAssertNotNil(status.error)
        XCTAssertTrue(status.error?.contains("Model 'llava:latest' not found") ?? false)
        XCTAssertEqual(status.details?.serverReachable, true)
        XCTAssertEqual(status.details?.modelAvailable, false)
    }

    func testCheckAvailabilityServerNotRunning() async {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/tags")!
        MockURLProtocol.mockResponses[url] = (
            data: nil,
            response: nil,
            error: URLError(.cannotConnectToHost))

        let provider = TestableOllamaProvider(session: session)

        let isAvailable = await provider.isAvailable
        XCTAssertFalse(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertFalse(status.available)
        XCTAssertNotNil(status.error)
        XCTAssertTrue(status.error?.contains("not reachable") ?? false)
        XCTAssertEqual(status.details?.serverReachable, false)
    }

    func testAnalyzeSuccessResponse() async throws {
        let mockGenerateResponse = """
        {
            "model": "llava:latest",
            "created_at": "2024-01-01T00:00:00Z",
            "response": "This image shows a beautiful landscape with mountains.",
            "done": true,
            "context": [1, 2, 3],
            "total_duration": 1000000000,
            "load_duration": 100000000,
            "prompt_eval_count": 10,
            "prompt_eval_duration": 50000000,
            "eval_count": 20,
            "eval_duration": 100000000
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/generate")!
        MockURLProtocol.mockResponses[url] = (
            data: mockGenerateResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil)

        let provider = TestableOllamaProvider(session: session)
        let result = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")

        XCTAssertEqual(result, "This image shows a beautiful landscape with mountains.")
    }

    func testAnalyzeEmptyQuestion() async throws {
        let mockGenerateResponse = """
        {
            "model": "llava:latest",
            "created_at": "2024-01-01T00:00:00Z",
            "response": "This appears to be a screenshot of a terminal.",
            "done": true
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/generate")!
        MockURLProtocol.mockResponses[url] = (
            data: mockGenerateResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil)

        let provider = TestableOllamaProvider(session: session)
        let result = try await provider.analyze(imageBase64: "fake-base64", question: "")

        // Should use default prompt when question is empty
        XCTAssertEqual(result, "This appears to be a screenshot of a terminal.")
    }

    func testAnalyzeServerError() async throws {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/generate")!
        MockURLProtocol.mockResponses[url] = (
            data: "Model not found".data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil),
            error: nil)

        let provider = TestableOllamaProvider(session: session)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("HTTP 404") ?? false)
        }
    }

    func testAnalyzeEmptyResponse() async throws {
        let mockGenerateResponse = """
        {
            "model": "llava:latest",
            "created_at": "2024-01-01T00:00:00Z",
            "response": "",
            "done": true
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/generate")!
        MockURLProtocol.mockResponses[url] = (
            data: mockGenerateResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil)

        let provider = TestableOllamaProvider(session: session)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("Empty response from Ollama") ?? false)
        }
    }

    func testCustomBaseURL() {
        // Test with environment variable set
        let provider = TestableOllamaProvider(baseURL: "http://custom-server:12345")
        XCTAssertEqual(provider.testBaseURL.absoluteString, "http://custom-server:12345")
    }

    func testModelMatching() async {
        // Test various model name matching scenarios
        let mockTagsResponse = """
        {
            "models": [
                {"name": "llava:13b", "modified_at": "2024-01-01T00:00:00Z", "size": 1000000},
                {"name": "llava:latest", "modified_at": "2024-01-01T00:00:00Z", "size": 2000000},
                {"name": "llama2:7b-chat", "modified_at": "2024-01-01T00:00:00Z", "size": 3000000}
            ]
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "http://localhost:11434/api/tags")!
        MockURLProtocol.mockResponses[url] = (
            data: mockTagsResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil)

        // Test exact match
        let provider1 = TestableOllamaProvider(model: "llava:latest", session: session)
        let status1 = await provider1.checkAvailability()
        XCTAssertTrue(status1.available)

        // Test prefix match
        let provider2 = TestableOllamaProvider(model: "llava", session: session)
        let status2 = await provider2.checkAvailability()
        XCTAssertTrue(status2.available)

        // Test no match
        let provider3 = TestableOllamaProvider(model: "mistral:latest", session: session)
        let status3 = await provider3.checkAvailability()
        XCTAssertFalse(status3.available)
    }
}

// MARK: - Testable Ollama Provider

private class TestableOllamaProvider: OllamaProvider {
    private let testSession: URLSession?
    private let customBaseURL: String?

    var testBaseURL: URL {
        let urlString = self.customBaseURL ?? ProcessInfo.processInfo
            .environment["PEEKABOO_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        return URL(string: urlString)!
    }

    init(model: String = "llava:latest", session: URLSession? = nil, baseURL: String? = nil) {
        self.testSession = session
        self.customBaseURL = baseURL
        super.init(model: model)
    }

    // Note: Can't override session property from PeekabooCore's OllamaProvider
    // Tests would need to be refactored to work with the actual implementation
    
    override var baseURL: URL {
        self.testBaseURL
    }
}
