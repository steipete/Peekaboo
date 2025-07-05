@testable import peekaboo
import XCTest

final class AIProviderTests: XCTestCase {
    // MARK: - AIProviderConfig Tests

    func testAIProviderConfigParsing() {
        let config1 = AIProviderConfig(from: "openai/gpt-4o")
        XCTAssertEqual(config1.provider, "openai")
        XCTAssertEqual(config1.model, "gpt-4o")
        XCTAssertTrue(config1.isValid)

        let config2 = AIProviderConfig(from: "ollama/llava:latest")
        XCTAssertEqual(config2.provider, "ollama")
        XCTAssertEqual(config2.model, "llava:latest")
        XCTAssertTrue(config2.isValid)

        let config3 = AIProviderConfig(from: "invalid")
        XCTAssertEqual(config3.provider, "invalid")
        XCTAssertEqual(config3.model, "")
        XCTAssertFalse(config3.isValid)

        let config4 = AIProviderConfig(from: "")
        XCTAssertEqual(config4.provider, "")
        XCTAssertEqual(config4.model, "")
        XCTAssertFalse(config4.isValid)
    }

    func testParseAIProviders() {
        let providers1 = parseAIProviders(from: "openai/gpt-4o,ollama/llava:latest")
        XCTAssertEqual(providers1.count, 2)
        XCTAssertEqual(providers1[0].provider, "openai")
        XCTAssertEqual(providers1[0].model, "gpt-4o")
        XCTAssertEqual(providers1[1].provider, "ollama")
        XCTAssertEqual(providers1[1].model, "llava:latest")

        let providers2 = parseAIProviders(from: "openai/gpt-4o, ollama/llava:latest , anthropic/claude-3")
        XCTAssertEqual(providers2.count, 3)
        XCTAssertEqual(providers2[2].provider, "anthropic")
        XCTAssertEqual(providers2[2].model, "claude-3")

        let providers3 = parseAIProviders(from: "invalid,openai/gpt-4o,/nomodel,noprovider/")
        XCTAssertEqual(providers3.count, 1)
        XCTAssertEqual(providers3[0].provider, "openai")

        let providers4 = parseAIProviders(from: nil)
        XCTAssertEqual(providers4.count, 0)

        let providers5 = parseAIProviders(from: "")
        XCTAssertEqual(providers5.count, 0)
    }

    // MARK: - AIProviderError Tests

    func testAIProviderErrorDescriptions() {
        let error1 = AIProviderError.notConfigured("Test message")
        XCTAssertEqual(error1.errorDescription, "Provider not configured: Test message")

        let error2 = AIProviderError.serverUnreachable("Connection failed")
        XCTAssertEqual(error2.errorDescription, "Server unreachable: Connection failed")

        let error3 = AIProviderError.invalidResponse("Bad JSON")
        XCTAssertEqual(error3.errorDescription, "Invalid response: Bad JSON")

        let error4 = AIProviderError.modelNotAvailable("gpt-5")
        XCTAssertEqual(error4.errorDescription, "Model not available: gpt-5")

        let error5 = AIProviderError.apiKeyMissing("No key found")
        XCTAssertEqual(error5.errorDescription, "API key missing: No key found")

        let error6 = AIProviderError.analysisTimeout
        XCTAssertEqual(error6.errorDescription, "Analysis request timed out")

        let error7 = AIProviderError.unknown("Something went wrong")
        XCTAssertEqual(error7.errorDescription, "Unknown error: Something went wrong")
    }

    // MARK: - Mock Provider Tests

    func testMockSuccessProvider() async throws {
        let provider = MockSuccessProvider(
            name: "test",
            model: "test-model",
            mockResponse: "Test analysis result"
        )

        XCTAssertEqual(provider.name, "test")
        XCTAssertEqual(provider.model, "test-model")

        let isAvailable = await provider.isAvailable
        XCTAssertTrue(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertTrue(status.available)
        XCTAssertNil(status.error)
        XCTAssertEqual(status.details?.modelAvailable, true)

        let result = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
        XCTAssertEqual(result, "Test analysis result")
    }

    func testMockFailureProvider() async throws {
        let provider = MockFailureProvider(
            error: .apiKeyMissing("Test API key error")
        )

        let isAvailable = await provider.isAvailable
        XCTAssertFalse(isAvailable)

        let status = await provider.checkAvailability()
        XCTAssertFalse(status.available)
        XCTAssertNotNil(status.error)

        do {
            _ = try await provider.analyze(imageBase64: "fake-base64", question: "What is this?")
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertEqual(error.errorDescription, "API key missing: Test API key error")
        }
    }

    func testMockProviderWithDelay() async throws {
        let provider = MockSuccessProvider(mockDelay: 0.1)

        let startTime = Date()
        let result = try await provider.analyze(imageBase64: "fake-base64", question: "Test")
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
        XCTAssertEqual(result, "Mock analysis result")
    }
}
