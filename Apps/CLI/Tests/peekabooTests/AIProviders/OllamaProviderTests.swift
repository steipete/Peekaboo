import Testing
@testable import peekaboo

// NOTE: These tests are temporarily disabled as they reference old AI provider architecture
// that has been replaced by PeekabooCore's model providers.
// TODO: Update or remove these tests based on new architecture

@Suite("Ollama Provider Tests", .disabled("Old AI provider architecture has been replaced"), .bug("PEEK-001: Migrate to new AI provider architecture"))
struct OllamaProviderTests {
    
    @Test("Ollama provider initialization")
    func providerInitialization() {
        // Test disabled - OllamaProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }

    @Test("Check availability with running Ollama server")
    func checkAvailabilityWithRunningServer() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Check availability with stopped Ollama server")
    func checkAvailabilityWithStoppedServer() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Send prompt to Ollama successfully")
    func sendPromptSuccess() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Send prompt with image to Ollama")
    func sendPromptWithImage() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
    
    @Test("Handle Ollama send prompt error")
    func sendPromptError() async {
        // Test disabled - OllamaProvider is now in PeekabooCore
        withKnownIssue("Old AI provider architecture has been replaced") {
            #expect(false)
        }
    }
}

// Testable wrapper classes no longer needed
// class TestableOllamaProvider: OllamaProvider { }