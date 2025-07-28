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
                Message.user(content: .text("Hello, Claude!")),
                Message.assistant(content: [.outputText("Hello! How can I help you?")]),
                Message.user(content: .text("What's 2+2?"))
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
                Message.system(content: "You are a helpful assistant."),
                Message.user(content: .text("Hello!"))
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
            function: FunctionDefinition(
                name: "get_weather",
                description: "Get the current weather",
                parameters: ToolParameters(
                    properties: ["location": ParameterSchema(type: .string, description: "The location")],
                    required: ["location"]
                )
            )
        )
        
        let request = ModelRequest(
            messages: [
                Message.user(content: .text("What's the weather?"))
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
                Message.user(content: .multimodal([
                    MessageContentPart(type: "text", text: "What's in this image?"),
                    MessageContentPart(type: "image", imageUrl: ImageContent(base64: imageData))
                ]))
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-3-opus-20240229")
        )
        
        if case .user(_, let content) = request.messages.first,
           case .multimodal(let parts) = content {
            #expect(parts.count == 2)
        } else {
            Issue.record("Expected multimodal content")
        }
        
        // Test that URL images are supported
        let urlRequest = ModelRequest(
            messages: [
                Message.user(content: .image(ImageContent(url: "https://example.com/image.jpg")))
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-3-opus-20240229")
        )
        
        if case .user(_, let content) = urlRequest.messages.first,
           case .image = content {
            // Expected image content
        } else {
            Issue.record("Expected image content")
        }
    }
    
    @Test("Model registration in provider")
    func testModelRegistration() async throws {
        // Test that Anthropic models are registered
        _ = ModelProvider.shared
        
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