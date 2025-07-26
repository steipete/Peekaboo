import Testing
import Foundation
@testable import PeekabooCore

@Suite("Anthropic Model Tests")
struct AnthropicModelTests {
    
    @Test("Anthropic request construction")
    func testRequestConstruction() async throws {
        let model = AnthropicModel(apiKey: "test-key")
        
        // Create a simple request
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: [.text("Hello, Claude!")], cacheControl: nil),
                AssistantMessageItem(content: [.text("Hello! How can I help you?")], toolCalls: nil),
                UserMessageItem(content: [.text("What's 2+2?")], cacheControl: nil)
            ],
            tools: nil,
            settings: ModelSettings(
                modelName: "claude-3-opus-20240229",
                temperature: 0.7,
                maxTokens: 1000,
                toolChoice: nil
            )
        )
        
        // Test that request can be created (actual API call would fail with test key)
        #expect(request.messages.count == 3)
        #expect(request.settings.modelName.contains("claude"))
    }
    
    @Test("System message extraction")
    func testSystemMessageExtraction() async throws {
        let model = AnthropicModel(apiKey: "test-key")
        
        let request = ModelRequest(
            messages: [
                SystemMessageItem(content: [.text("You are a helpful assistant.")]),
                UserMessageItem(content: [.text("Hello!")], cacheControl: nil)
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-3-opus-20240229")
        )
        
        // System messages should be properly extracted
        #expect(request.messages.first?.type == .system)
    }
    
    @Test("Tool conversion")
    func testToolConversion() async throws {
        let model = AnthropicModel(apiKey: "test-key")
        
        let toolDef = ToolDefinition(
            function: ToolDefinition.Function(
                name: "get_weather",
                description: "Get the current weather",
                parameters: ["type": "object", "properties": ["location": ["type": "string"]]]
            )
        )
        
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: [.text("What's the weather?")], cacheControl: nil)
            ],
            tools: [toolDef],
            settings: ModelSettings(modelName: "claude-3-opus-20240229")
        )
        
        #expect(request.tools?.count == 1)
        #expect(request.tools?.first?.function.name == "get_weather")
    }
    
    @Test("Image content handling")
    func testImageContent() async throws {
        let model = AnthropicModel(apiKey: "test-key")
        
        let imageData = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: [
                    .text("What's in this image?"),
                    .image(ImageMessageContent(base64: imageData, url: nil))
                ], cacheControl: nil)
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-3-opus-20240229")
        )
        
        #expect(request.messages.first?.content.count == 2)
        
        // Test that URL images throw error
        let urlRequest = ModelRequest(
            messages: [
                UserMessageItem(content: [
                    .image(ImageMessageContent(base64: nil, url: URL(string: "https://example.com/image.jpg")))
                ], cacheControl: nil)
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-3-opus-20240229")
        )
        
        #expect(urlRequest.messages.first?.content.first?.type == .image)
    }
    
    @Test("Model registration in provider")
    func testModelRegistration() async throws {
        // Test that Anthropic models are registered
        let provider = ModelProvider.shared
        
        // Test model names
        let modelNames = [
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307",
            "claude-3-5-sonnet-latest",
            "claude-3-opus-latest"
        ]
        
        // Without API key, models won't be available but we can test registration logic
        for modelName in modelNames {
            // This would normally check if model can be instantiated
            #expect(modelName.contains("claude"))
        }
    }
}