import XCTest
@testable import peekaboo

final class AIProviderFactoryTests: XCTestCase {
    func testCreateProvider() {
        let openaiConfig = AIProviderConfig(from: "openai/gpt-4o")
        let openaiProvider = AIProviderFactory.createProvider(from: openaiConfig)
        XCTAssertNotNil(openaiProvider)
        XCTAssertEqual(openaiProvider?.name, "openai")
        XCTAssertEqual(openaiProvider?.model, "gpt-4o")

        let ollamaConfig = AIProviderConfig(from: "ollama/llava:latest")
        let ollamaProvider = AIProviderFactory.createProvider(from: ollamaConfig)
        XCTAssertNotNil(ollamaProvider)
        XCTAssertEqual(ollamaProvider?.name, "ollama")
        XCTAssertEqual(ollamaProvider?.model, "llava:latest")

        let unknownConfig = AIProviderConfig(from: "unknown/model")
        let unknownProvider = AIProviderFactory.createProvider(from: unknownConfig)
        XCTAssertNil(unknownProvider)
    }

    func testCreateProviders() {
        let providers1 = AIProviderFactory.createProviders(from: "openai/gpt-4o,ollama/llava:latest")
        XCTAssertEqual(providers1.count, 2)
        XCTAssertEqual(providers1[0].name, "openai")
        XCTAssertEqual(providers1[1].name, "ollama")

        let providers2 = AIProviderFactory.createProviders(from: "invalid,openai/gpt-4o,unknown/model")
        XCTAssertEqual(providers2.count, 1)
        XCTAssertEqual(providers2[0].name, "openai")

        let providers3 = AIProviderFactory.createProviders(from: nil)
        XCTAssertEqual(providers3.count, 0)

        let providers4 = AIProviderFactory.createProviders(from: "")
        XCTAssertEqual(providers4.count, 0)
    }

    func testGetDefaultModel() {
        XCTAssertEqual(AIProviderFactory.getDefaultModel(for: "openai"), "gpt-4o")
        XCTAssertEqual(AIProviderFactory.getDefaultModel(for: "ollama"), "llava:latest")
        XCTAssertEqual(AIProviderFactory.getDefaultModel(for: "unknown"), "unknown")
        XCTAssertEqual(AIProviderFactory.getDefaultModel(for: "OPENAI"), "gpt-4o") // Case insensitive
    }

    func testFindAvailableProvider() async {
        let providers: [AIProvider] = [
            MockUnavailableProvider(name: "unavailable1"),
            MockUnavailableProvider(name: "unavailable2"),
            MockSuccessProvider(name: "available"),
            MockSuccessProvider(name: "also-available"),
        ]

        let availableProvider = await AIProviderFactory.findAvailableProvider(from: providers)
        XCTAssertNotNil(availableProvider)
        XCTAssertEqual(availableProvider?.name, "available")

        let noProviders: [AIProvider] = []
        let noAvailable = await AIProviderFactory.findAvailableProvider(from: noProviders)
        XCTAssertNil(noAvailable)

        let allUnavailable: [AIProvider] = [
            MockUnavailableProvider(name: "unavailable1"),
            MockUnavailableProvider(name: "unavailable2"),
        ]
        let noneAvailable = await AIProviderFactory.findAvailableProvider(from: allUnavailable)
        XCTAssertNil(noneAvailable)
    }

    func testDetermineProviderAuto() async throws {
        let providers: [AIProvider] = [
            MockUnavailableProvider(name: "unavailable"),
            MockSuccessProvider(name: "available", model: "test-model"),
        ]

        let provider = try await AIProviderFactory.determineProvider(
            requestedType: "auto",
            requestedModel: nil,
            configuredProviders: providers)

        XCTAssertEqual(provider.name, "available")
        XCTAssertEqual(provider.model, "test-model")
    }

    func testDetermineProviderSpecific() async throws {
        let providers: [AIProvider] = [
            MockSuccessProvider(name: "openai", model: "gpt-4o"),
            MockSuccessProvider(name: "ollama", model: "llava:latest"),
        ]

        let provider = try await AIProviderFactory.determineProvider(
            requestedType: "ollama",
            requestedModel: nil,
            configuredProviders: providers)

        XCTAssertEqual(provider.name, "ollama")
        XCTAssertEqual(provider.model, "llava:latest")
    }

    func testDetermineProviderNotConfigured() async {
        let providers: [AIProvider] = [
            MockSuccessProvider(name: "openai", model: "gpt-4o"),
        ]

        do {
            _ = try await AIProviderFactory.determineProvider(
                requestedType: "anthropic",
                requestedModel: nil,
                configuredProviders: providers)
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("not enabled") ?? false)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDetermineProviderUnavailable() async {
        let providers: [AIProvider] = [
            MockUnavailableProvider(name: "openai"),
        ]

        do {
            _ = try await AIProviderFactory.determineProvider(
                requestedType: "openai",
                requestedModel: nil,
                configuredProviders: providers)
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?.contains("not currently available") ?? false)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDetermineProviderNoAvailable() async {
        let providers: [AIProvider] = [
            MockUnavailableProvider(name: "openai"),
            MockUnavailableProvider(name: "ollama"),
        ]

        do {
            _ = try await AIProviderFactory.determineProvider(
                requestedType: nil,
                requestedModel: nil,
                configuredProviders: providers)
            XCTFail("Expected error to be thrown")
        } catch let error as AIProviderError {
            XCTAssertTrue(error.errorDescription?
                .contains("No configured AI providers are currently operational") ?? false)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
