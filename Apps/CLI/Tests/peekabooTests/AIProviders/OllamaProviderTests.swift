import XCTest
@testable import peekaboo

// NOTE: These tests are temporarily disabled as they reference old AI provider architecture
// that has been replaced by PeekabooCore's model providers.
// TODO: Update or remove these tests based on new architecture

final class OllamaProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // MockURLProtocol.reset() - no longer exists
    }

    override func tearDown() {
        super.tearDown()
        // MockURLProtocol.reset() - no longer exists
    }

    func testOllamaProviderInitialization() {
        // Test disabled - OllamaProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }

    func testCheckAvailabilityWithRunningServer() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testCheckAvailabilityWithStoppedServer() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testSendPromptSuccess() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testSendPromptWithImage() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
    
    func testSendPromptError() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
}

// Testable wrapper classes no longer needed
// class TestableOllamaProvider: OllamaProvider { }