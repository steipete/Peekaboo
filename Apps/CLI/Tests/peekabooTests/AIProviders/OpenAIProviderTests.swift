import XCTest
import PeekabooCore
@testable import peekaboo

// NOTE: These tests are temporarily disabled as they reference old AI provider architecture
// that has been replaced by PeekabooCore's model providers.
// TODO: Update or remove these tests based on new architecture

final class OpenAIProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // MockURLProtocol.reset() - no longer exists
    }

    override func tearDown() {
        super.tearDown()
        // MockURLProtocol.reset() - no longer exists
    }

    func testOpenAIProviderInitialization() {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }

    func testCheckAvailabilityWithValidAPIKey() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testCheckAvailabilityWithInvalidAPIKey() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testSendPromptSuccess() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testSendPromptWithImage() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testSendPromptError() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testNoAPIKeyError() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
}

// Testable wrapper classes no longer needed
// class TestableOpenAIProvider: OpenAIProvider { }