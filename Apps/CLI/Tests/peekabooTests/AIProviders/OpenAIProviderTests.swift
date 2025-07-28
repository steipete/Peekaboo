import Testing
@testable import peekaboo

// NOTE: These tests are temporarily disabled as they reference old AI provider architecture
// that has been replaced by PeekabooCore's model providers.
// TODO: Update or remove these tests based on new architecture

@Suite("OpenAI Provider Tests", .disabled("Old AI provider architecture has been replaced"), .bug("PEEK-001: Migrate to new AI provider architecture"))
struct OpenAIProviderTests {
    
    @Test("OpenAI provider initialization")
    func providerInitialization() {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }

    @Test("Check availability with valid API key")
    func checkAvailabilityWithValidAPIKey() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Check availability with invalid API key")
    func checkAvailabilityWithInvalidAPIKey() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Send prompt successfully")
    func sendPromptSuccess() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Send prompt with image attachment")
    func sendPromptWithImage() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Handle send prompt error")
    func sendPromptError() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Handle missing API key error")
    func noAPIKeyError() async {
        // Test disabled - OpenAIProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
}

// Testable wrapper classes no longer needed
// class TestableOpenAIProvider: OpenAIProvider { }