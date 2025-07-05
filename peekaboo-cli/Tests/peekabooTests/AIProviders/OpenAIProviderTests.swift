@testable import peekaboo
import XCTest

final class OpenAIProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.reset()
    }

    func testOpenAIProviderInitialization() {
        let provider = OpenAIProvider(model: "gpt-4o")
        XCTAssertEqual(provider.name, "openai")
        XCTAssertEqual(provider.model, "gpt-4o")

        let defaultProvider = OpenAIProvider()
        XCTAssertEqual(defaultProvider.model, "gpt-4o")
    }

    func testCheckAvailabilityWithoutAPIKey() async {
        // Create a provider without API key
        let provider = TestableOpenAIProvider(apiKey: nil)

        let isAvailable = await provider.isAvailable
        XCTAssertFalse(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertFalse(status.available)
        XCTAssertNotNil(status.error)
        XCTAssertTrue(status.error?.contains("OPENAI_API_KEY") ?? false)
        XCTAssertEqual(status.details?.apiKeyPresent, false)
    }

    func testCheckAvailabilityWithAPIKey() async {
        let provider = TestableOpenAIProvider(apiKey: "test-api-key")

        let isAvailable = await provider.isAvailable
        XCTAssertTrue(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertTrue(status.available)
        XCTAssertNil(status.error)
        XCTAssertEqual(status.details?.apiKeyPresent, true)
    }

    func testAnalyzeWithoutAPIKey() async throws {
        let provider = TestableOpenAIProvider(apiKey: nil)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("OPENAI_API_KEY") ?? false)
        }
    }

    func testAnalyzeSuccessResponse() async throws {
        let mockResponse = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "This is a test image showing a cat."
                },
                "finish_reason": "stop"
            }]
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        MockURLProtocol.mockResponses[url] = (
            data: mockResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil
        )

        let provider = TestableOpenAIProvider(apiKey: "test-key", session: session)
        let result = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")

        XCTAssertEqual(result, "This is a test image showing a cat.")
    }

    func testAnalyzeEmptyQuestion() async throws {
        let mockResponse = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "This appears to be a screenshot."
                },
                "finish_reason": "stop"
            }]
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        MockURLProtocol.mockResponses[url] = (
            data: mockResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil
        )

        let provider = TestableOpenAIProvider(apiKey: "test-key", session: session)
        let result = try await provider.analyze(imageBase64: "fake-base64", question: "")

        // Should use default prompt when question is empty
        XCTAssertEqual(result, "This appears to be a screenshot.")
    }

    func testAnalyzeUnauthorizedError() async throws {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        MockURLProtocol.mockResponses[url] = (
            data: "Unauthorized".data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil),
            error: nil
        )

        let provider = TestableOpenAIProvider(apiKey: "invalid-key", session: session)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("Invalid OpenAI API key") ?? false)
        }
    }

    func testAnalyzeServerError() async throws {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        MockURLProtocol.mockResponses[url] = (
            data: "Internal Server Error".data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil),
            error: nil
        )

        let provider = TestableOpenAIProvider(apiKey: "test-key", session: session)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("HTTP 500") ?? false)
        }
    }

    func testAnalyzeNoContent() async throws {
        let mockResponse = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4o",
            "choices": []
        }
        """

        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        MockURLProtocol.mockResponses[url] = (
            data: mockResponse.data(using: .utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            error: nil
        )

        let provider = TestableOpenAIProvider(apiKey: "test-key", session: session)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("No content in OpenAI response") ?? false)
        }
    }
}

// MARK: - Testable OpenAI Provider

private class TestableOpenAIProvider: OpenAIProvider {
    private let testAPIKey: String?
    private let testSession: URLSession?

    init(apiKey: String? = nil, session: URLSession? = nil) {
        testAPIKey = apiKey
        testSession = session
        super.init(model: "gpt-4o")
    }

    override var apiKey: String? {
        testAPIKey
    }

    override var session: URLSession {
        testSession ?? URLSession.shared
    }
}
