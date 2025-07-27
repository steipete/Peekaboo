import XCTest
@testable import peekaboo

// NOTE: These tests are temporarily disabled as they reference old AI provider architecture
// that has been replaced by PeekabooCore's model providers.
// TODO: Update or remove these tests based on new architecture

final class AIProviderTests: XCTestCase {
    // MARK: - AIProviderConfig Tests

    func testAIProviderConfigParsing() {
        // Test disabled - AIProviderConfig no longer exists
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }

    func testParseAIProviders() {
        // Test disabled - parseAIProviders no longer exists
        XCTSkip("Test disabled - old AI provider architecture has been replaced")
    }
}