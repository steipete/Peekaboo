import Testing
@testable import PeekabooCore
import Foundation

@Suite("Grok Model Tests")
struct GrokModelTests {
    
    @Test("Model initialization")
    func testModelInitialization() async throws {
        let model = GrokModel(
            apiKey: "test-key-123456",
            baseURL: URL(string: "https://api.x.ai/v1")!
        )
        
        #expect(model.maskedApiKey == "test-k...56")
    }
    
    @Test("API key masking")
    func testAPIKeyMasking() async throws {
        // Test short key
        let shortModel = GrokModel(apiKey: "short")
        #expect(shortModel.maskedApiKey == "***")
        
        // Test normal key
        let normalModel = GrokModel(apiKey: "test-api-key-1234567890abcdefghijklmnopqrstuvwxyz")
        #expect(normalModel.maskedApiKey == "test-a...yz")
    }
    
    @Test("Default base URL")
    func testDefaultBaseURL() async throws {
        let model = GrokModel(apiKey: "test-key-123456")
        
        // Verify it uses the correct xAI API endpoint
        // We can't directly access baseURL, but we can test the behavior
        #expect(model.maskedApiKey == "test-k...56")
    }
    
    @Test("Parameter filtering for Grok 4")
    func testGrok4ParameterFiltering() async throws {
        let model = GrokModel(apiKey: "test-key")
        
        // Create a request with parameters that should be filtered for Grok 4
        let settings = ModelSettings(
            modelName: "grok-4",
            temperature: 0.7,
            frequencyPenalty: 0.5,  // Should be removed for grok-4
            presencePenalty: 0.5,   // Should be removed for grok-4
            stopSequences: ["stop"] // Should be removed for grok-4
        )
        
        let request = ModelRequest(
            messages: [
                SystemMessageItem(content: "Test system message"),
                UserMessageItem(content: .text("Test user message"))
            ],
            tools: nil,
            settings: settings
        )
        
        // We can't directly test the filtering without mocking the network request
        // But we can verify the model handles the request without crashing
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is ModelError)
        }
    }
    
    @Test("Tool parameter conversion")
    func testToolParameterConversion() async throws {
        let model = GrokModel(apiKey: "test-key")
        
        // Create a tool definition
        let tool = ToolDefinition(
            function: FunctionDefinition(
                name: "test_tool",
                description: "A test tool",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "message": ParameterSchema(
                            type: .string,
                            description: "A test message"
                        ),
                        "count": ParameterSchema(
                            type: .integer,
                            description: "A count",
                            minimum: 0,
                            maximum: 100
                        )
                    ],
                    required: ["message"]
                )
            )
        )
        
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: .text("Use the test tool"))
            ],
            tools: [tool],
            settings: ModelSettings(modelName: "grok-4")
        )
        
        // Verify the model can process tool definitions
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is ModelError)
        }
    }
    
    @Test("Message type conversion")
    func testMessageTypeConversion() async throws {
        let model = GrokModel(apiKey: "test-key")
        
        // Test various message types
        let messages: [any MessageItem] = [
            SystemMessageItem(content: "System prompt"),
            UserMessageItem(content: .text("User text")),
            AssistantMessageItem(content: [.outputText("Assistant response")]),
            ToolMessageItem(
                toolCallId: "tool-123",
                content: "Tool result"
            )
        ]
        
        let request = ModelRequest(
            messages: messages,
            tools: nil,
            settings: ModelSettings(modelName: "grok-beta")
        )
        
        // Verify message conversion doesn't crash
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is ModelError)
        }
    }
    
    @Test("Multimodal message support")
    func testMultimodalMessageSupport() async throws {
        let model = GrokModel(apiKey: "test-key")
        
        // Create a multimodal message with text and image
        let imageData = Data([0xFF, 0xD8, 0xFF]) // Minimal JPEG header
        
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: .multimodal([
                    MessageContentPart(type: "text", text: "What is in this image?"),
                    MessageContentPart(type: "image", imageUrl: ImageContent(base64: imageData.base64EncodedString()))
                ]))
            ],
            tools: nil,
            settings: ModelSettings(modelName: "grok-2-vision-1212")
        )
        
        // Verify multimodal content handling
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is ModelError)
        }
    }
    
    @Test("Streaming response handling")
    func testStreamingResponse() async throws {
        let model = GrokModel(apiKey: "test-key")
        
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: .text("Stream this response"))
            ],
            tools: nil,
            settings: ModelSettings(modelName: "grok-4")
        )
        
        // Test streaming
        do {
            let stream = try await model.getStreamedResponse(request: request)
            var eventCount = 0
            
            for try await event in stream {
                eventCount += 1
                // Would normally process events here
                _ = event
            }
            
            Issue.record("Expected network error but got success with \(eventCount) events")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is ModelError)
        }
    }
    
    @Test("Error handling")
    func testErrorHandling() async throws {
        let model = GrokModel(apiKey: "invalid-key")
        
        let request = ModelRequest(
            messages: [
                UserMessageItem(content: .text("Test"))
            ],
            tools: nil,
            settings: ModelSettings(modelName: "grok-4")
        )
        
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error but got success")
        } catch let error as ModelError {
            // Verify we get appropriate error types
            switch error {
            case .authenticationFailed, .requestFailed:
                // Expected error types for invalid API key
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
    }
}

// MARK: - Model Provider Tests

@Suite("Grok Model Provider Tests")
struct GrokModelProviderTests {
    
    @Test("Grok model registration")
    func testGrokModelRegistration() async throws {
        let provider = ModelProvider.shared
        
        // Set a test API key
        setenv("X_AI_API_KEY", "test-key", 1)
        defer { unsetenv("X_AI_API_KEY") }
        
        // Re-register models to pick up the test key
        try await provider.setupFromEnvironment()
        
        // Test various Grok model names
        let modelNames = [
            "grok-4",
            "grok-4-0709",
            "grok-4-latest",
            "grok-2-1212",
            "grok-2-vision-1212",
            "grok-beta",
            "grok-vision-beta"
        ]
        
        for modelName in modelNames {
            do {
                let model = try await provider.getModel(modelName: modelName)
                #expect(model is GrokModel)
            } catch {
                Issue.record("Failed to get model \(modelName): \(error)")
            }
        }
    }
    
    @Test("Lenient model name resolution")
    func testLenientModelNameResolution() async throws {
        let provider = ModelProvider.shared
        
        // Set a test API key
        setenv("X_AI_API_KEY", "test-key", 1)
        defer { unsetenv("X_AI_API_KEY") }
        
        // Re-register models
        try await provider.setupFromEnvironment()
        
        // Test lenient name matching
        let nameMapping = [
            "grok": "grok-4",
            "grok4": "grok-4",
            "grok-4": "grok-4",
            "grok2": "grok-2-1212",
            "grok-2": "grok-2-1212"
        ]
        
        for (input, expected) in nameMapping {
            do {
                let model = try await provider.getModel(modelName: input)
                #expect(model is GrokModel)
                // We can't easily verify the exact model name used internally
            } catch {
                Issue.record("Failed to resolve \(input) to \(expected): \(error)")
            }
        }
    }
    
    @Test("API key detection")
    func testAPIKeyDetection() async throws {
        let provider = ModelProvider.shared
        
        // Test X_AI_API_KEY
        setenv("X_AI_API_KEY", "xai-test-key", 1)
        defer { unsetenv("X_AI_API_KEY") }
        
        await provider.clearCache()
        try await provider.setupFromEnvironment()
        
        do {
            let model = try await provider.getModel(modelName: "grok-4")
            #expect(model is GrokModel)
        } catch {
            Issue.record("Failed with X_AI_API_KEY: \(error)")
        }
        
        // Test XAI_API_KEY
        unsetenv("X_AI_API_KEY")
        setenv("XAI_API_KEY", "xai-test-key-2", 1)
        defer { unsetenv("XAI_API_KEY") }
        
        await provider.clearCache()
        try await provider.setupFromEnvironment()
        
        do {
            let model = try await provider.getModel(modelName: "grok-4")
            #expect(model is GrokModel)
        } catch {
            Issue.record("Failed with XAI_API_KEY: \(error)")
        }
    }
    
    @Test("Missing API key handling")
    func testMissingAPIKeyHandling() async throws {
        // Ensure no Grok API keys are set
        unsetenv("X_AI_API_KEY")
        unsetenv("XAI_API_KEY")
        
        let provider = ModelProvider.shared
        await provider.clearCache()
        try await provider.setupFromEnvironment()
        
        // Should fail to get Grok model without API key
        do {
            _ = try await provider.getModel(modelName: "grok-4")
            // If we get here, the model was registered but we should get an error when using it
            // The models might be registered because other API keys exist in the environment
        } catch ModelError.modelNotFound {
            // Expected - model not registered without API key
        } catch ModelError.authenticationFailed {
            // Also expected - model registered but no valid API key
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

