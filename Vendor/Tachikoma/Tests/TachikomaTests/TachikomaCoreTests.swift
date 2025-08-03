import Foundation
import Testing
@testable import Tachikoma

@Suite("Tachikoma Core Tests")
struct TachikomaCoreTests {
    @Test("Tachikoma singleton initialization")
    func singletonInitialization() async throws {
        let tachikoma1 = Tachikoma.shared
        let tachikoma2 = Tachikoma.shared
        
        // Should be the same instance
        #expect(tachikoma1 === tachikoma2)
    }

    @Test("Model registration and retrieval")
    func modelRegistrationAndRetrieval() async throws {
        let tachikoma = Tachikoma.shared

        // Register a test model
        await tachikoma.registerModel(name: "test-model", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "gpt-4.1")
        })

        // Should be able to retrieve it
        do {
            let model = try await tachikoma.getModel("test-model")
            #expect(model is OpenAIModel)
        } catch {
            Issue.record("Failed to retrieve registered model: \(error)")
        }
    }

    @Test("Model not found error")
    func modelNotFoundError() async throws {
        let tachikoma = Tachikoma.shared

        // Should throw error for non-existent model
        do {
            _ = try await tachikoma.getModel("nonexistent-model")
            Issue.record("Expected error for nonexistent model")
        } catch let error as TachikomaError {
            switch error {
            case .modelNotFound:
                // Expected
                break
            default:
                Issue.record("Expected modelNotFound error, got: \(error)")
            }
        }
    }

    @Test("Provider configuration")
    func providerConfiguration() async throws {
        let tachikoma = Tachikoma.shared

        // Test OpenAI configuration
        let openaiConfig = ProviderConfiguration.OpenAI(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        await tachikoma.configureOpenAI(openaiConfig)

        // Test Anthropic configuration
        let anthropicConfig = ProviderConfiguration.Anthropic(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.anthropic.com/v1")!
        )
        await tachikoma.configureAnthropic(anthropicConfig)

        // Test Grok configuration
        let grokConfig = ProviderConfiguration.Grok(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.x.ai/v1")!
        )
        await tachikoma.configureGrok(grokConfig)

        // Test Ollama configuration
        let ollamaConfig = ProviderConfiguration.Ollama(
            baseURL: URL(string: "http://localhost:11434")!
        )
        await tachikoma.configureOllama(ollamaConfig)
    }

    @Test("Model factory functions")
    func modelFactoryFunctions() async throws {
        let tachikoma = Tachikoma.shared

        // Test that factory functions work correctly
        await tachikoma.registerModel(name: "factory-openai", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "gpt-4.1")
        })

        await tachikoma.registerModel(name: "factory-anthropic", factory: {
            AnthropicModel(apiKey: "test-key", modelName: "claude-opus-4-20250514")
        })

        await tachikoma.registerModel(name: "factory-grok", factory: {
            GrokModel(apiKey: "test-key", modelName: "grok-4")
        })

        await tachikoma.registerModel(name: "factory-ollama", factory: {
            OllamaModel(modelName: "llama3.3")
        })

        // Test retrieval
        let modelNames = ["factory-openai", "factory-anthropic", "factory-grok", "factory-ollama"]
        
        for modelName in modelNames {
            do {
                let model = try await tachikoma.getModel(modelName)
                #expect(model is any ModelInterface)
            } catch {
                Issue.record("Failed to get \(modelName): \(error)")
            }
        }
    }

    @Test("Concurrent model access")
    func concurrentModelAccess() async throws {
        let tachikoma = Tachikoma.shared

        // Register a model
        await tachikoma.registerModel(name: "concurrent-test", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "gpt-4.1")
        })

        // Access it concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        let model = try await tachikoma.getModel("concurrent-test")
                        #expect(model is OpenAIModel)
                    } catch {
                        Issue.record("Concurrent access failed for iteration \(i): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Message Type Tests

@Suite("Message Type Tests")
struct MessageTypeTests {
    @Test("System message creation")
    func systemMessageCreation() {
        let message = Message.system(content: "You are a helpful assistant.")
        
        if case let .system(id, content) = message {
            #expect(id == nil)
            #expect(content == "You are a helpful assistant.")
        } else {
            Issue.record("Expected system message")
        }
    }

    @Test("User message with text content")
    func userMessageWithTextContent() {
        let message = Message.user(content: .text("Hello, AI!"))
        
        if case let .user(id, content) = message {
            #expect(id == nil)
            if case let .text(text) = content {
                #expect(text == "Hello, AI!")
            } else {
                Issue.record("Expected text content")
            }
        } else {
            Issue.record("Expected user message")
        }
    }

    @Test("User message with multimodal content")
    func userMessageWithMultimodalContent() {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let message = Message.user(content: .multimodal([
            MessageContentPart(type: "text", text: "What's in this image?"),
            MessageContentPart(type: "image_url", imageUrl: ImageContent(base64: imageData.base64EncodedString()))
        ]))
        
        if case let .user(_, content) = message {
            if case let .multimodal(parts) = content {
                #expect(parts.count == 2)
                
                #expect(parts[0].type == "text")
                #expect(parts[0].text == "What's in this image?")
                
                #expect(parts[1].type == "image_url")
                #expect(parts[1].imageUrl != nil)
            } else {
                Issue.record("Expected multimodal content")
            }
        } else {
            Issue.record("Expected user message")
        }
    }

    @Test("Assistant message creation")
    func assistantMessageCreation() {
        let message = Message.assistant(content: [
            .outputText("Hello! How can I help you?")
        ])
        
        if case let .assistant(id, content, status) = message {
            #expect(id == nil)
            #expect(status == .completed)
            #expect(content.count == 1)
            
            if case let .outputText(text) = content[0] {
                #expect(text == "Hello! How can I help you?")
            } else {
                Issue.record("Expected output text content")
            }
        } else {
            Issue.record("Expected assistant message")
        }
    }

    @Test("Tool call message")
    func toolCallMessage() {
        let toolCall = ToolCallItem(
            id: "call_123",
            type: .function,
            function: FunctionCall(
                name: "get_weather",
                arguments: "{\"location\": \"San Francisco\"}"
            )
        )
        
        let message = Message.assistant(content: [.toolCall(toolCall)])
        
        if case let .assistant(_, content, _) = message {
            if case let .toolCall(call) = content[0] {
                #expect(call.id == "call_123")
                #expect(call.function.name == "get_weather")
                #expect(call.function.arguments == "{\"location\": \"San Francisco\"}")
            } else {
                Issue.record("Expected tool call content")
            }
        } else {
            Issue.record("Expected assistant message")
        }
    }

    @Test("Tool result message")
    func toolResultMessage() {
        let message = Message.tool(
            toolCallId: "call_123",
            content: "The weather in San Francisco is 72°F and sunny."
        )
        
        if case let .tool(id, toolCallId, content) = message {
            #expect(id == nil)
            #expect(toolCallId == "call_123")
            #expect(content == "The weather in San Francisco is 72°F and sunny.")
        } else {
            Issue.record("Expected tool message")
        }
    }

    @Test("Reasoning message")
    func reasoningMessage() {
        let message = Message.reasoning(content: "Let me think about this step by step...")
        
        if case let .reasoning(id, content) = message {
            #expect(id == nil)
            #expect(content == "Let me think about this step by step...")
        } else {
            Issue.record("Expected reasoning message")
        }
    }

    @Test("Message with custom ID")
    func messageWithCustomID() {
        let message = Message.user(id: "custom-123", content: .text("Hello"))
        
        if case let .user(id, _) = message {
            #expect(id == "custom-123")
        } else {
            Issue.record("Expected user message with custom ID")
        }
    }

    @Test("Message type property")
    func messageTypeProperty() {
        let messages: [Message] = [
            .system(content: "System"),
            .user(content: .text("User")),
            .assistant(content: [.outputText("Assistant")]),
            .tool(toolCallId: "call", content: "Tool"),
            .reasoning(content: "Reasoning")
        ]
        
        let expectedTypes: [Message.MessageType] = [.system, .user, .assistant, .tool, .reasoning]
        
        for (message, expectedType) in zip(messages, expectedTypes) {
            #expect(message.type == expectedType)
        }
    }
}

// MARK: - MessageContent Tests

@Suite("MessageContent Tests")
struct MessageContentTests {
    @Test("Text content")
    func textContent() {
        let content = MessageContent.text("Hello, world!")
        
        if case let .text(text) = content {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Image content with base64")
    func imageContentWithBase64() {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let imageContent = ImageContent(base64: imageData.base64EncodedString())
        let content = MessageContent.image(imageContent)
        
        if case let .image(url) = content {
            #expect(url.base64 == imageData.base64EncodedString())
            #expect(url.url == nil)
        } else {
            Issue.record("Expected image content")
        }
    }

    @Test("Image content with URL")
    func imageContentWithURL() {
        let imageContent = ImageContent(url: "https://example.com/image.jpg")
        let content = MessageContent.image(imageContent)
        
        if case let .image(url) = content {
            #expect(url.url == "https://example.com/image.jpg")
            #expect(url.base64 == nil)
        } else {
            Issue.record("Expected image content")
        }
    }

    @Test("Audio content")
    func audioContent() {
        let audioData = AudioContent(
            transcript: "Hello, this is a test.",
            duration: 5.0
        )
        let content = MessageContent.audio(audioData)
        
        if case let .audio(audio) = content {
            #expect(audio.transcript == "Hello, this is a test.")
            #expect(audio.duration == 5.0)
        } else {
            Issue.record("Expected audio content")
        }
    }

    @Test("File content")
    func fileContent() {
        let fileData = FileContent(
            filename: "test.txt",
            content: "File content here",
            mimeType: "text/plain"
        )
        let content = MessageContent.file(fileData)
        
        if case let .file(file) = content {
            #expect(file.filename == "test.txt")
            #expect(file.content == "File content here")
            #expect(file.mimeType == "text/plain")
        } else {
            Issue.record("Expected file content")
        }
    }

    @Test("Multimodal content")
    func multimodalContent() {
        let parts: [MessageContentPart] = [
            MessageContentPart(type: "text", text: "Describe this image:"),
            MessageContentPart(type: "image_url", imageUrl: ImageContent(url: "https://example.com/image.jpg")),
            MessageContentPart(type: "text", text: "What do you see?")
        ]
        let content = MessageContent.multimodal(parts)
        
        if case let .multimodal(contentParts) = content {
            #expect(contentParts.count == 3)
            
            #expect(contentParts[0].type == "text")
            #expect(contentParts[0].text == "Describe this image:")
            
            #expect(contentParts[1].type == "image")
            #expect(contentParts[1].imageUrl != nil)
            
            #expect(contentParts[2].type == "text")
            #expect(contentParts[2].text == "What do you see?")
        } else {
            Issue.record("Expected multimodal content")
        }
    }
}

// MARK: - Error Handling Tests

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    @Test("TachikomaError cases")
    func tachikomaErrorCases() {
        let errors: [TachikomaError] = [
            .modelNotFound("test-model"),
            .invalidRequest("Invalid parameters"),
            .authenticationFailed,
            .apiError(message: "Rate limit exceeded", code: "429"),
            .networkError(underlying: URLError(.notConnectedToInternet)),
            .configurationError("Missing configuration"),
            .streamingError("Stream interrupted"),
        ]
        
        // Verify all error cases can be created
        #expect(errors.count == 9)
        
        // Test error descriptions
        for error in errors {
            let description = error.localizedDescription
            #expect(!description.isEmpty)
        }
    }

    @Test("Error equality")
    func errorEquality() {
        let error1 = TachikomaError.modelNotFound("test")
        let error2 = TachikomaError.modelNotFound("test")
        let error3 = TachikomaError.modelNotFound("different")
        
        #expect(error1.localizedDescription == error2.localizedDescription)
        #expect(error1.localizedDescription != error3.localizedDescription)
    }
}

// MARK: - Model Settings Tests

@Suite("Model Settings Tests")
struct ModelSettingsTests {
    @Test("Default model settings")
    func defaultModelSettings() {
        let settings = ModelSettings(modelName: "test-model")
        
        #expect(settings.modelName == "test-model")
        #expect(settings.temperature == nil)
        #expect(settings.maxTokens == nil)
        #expect(settings.topP == nil)
        #expect(settings.frequencyPenalty == nil)
        #expect(settings.presencePenalty == nil)
        #expect(settings.stopSequences == nil)
        #expect(settings.seed == nil)
        #expect(settings.toolChoice == nil)
        #expect(settings.parallelToolCalls == nil)
        #expect(settings.additionalParameters == nil)
    }

    @Test("Custom model settings")
    func customModelSettings() {
        var additionalParams = ModelParameters()
        additionalParams.set("apiType", value: "chat")
        additionalParams.set("reasoningEffort", value: "medium")
        additionalParams.set("reasoning", value: ["summary": "detailed"])
        additionalParams.set("logprobs", value: true)
        additionalParams.set("topLogprobs", value: 5)
        
        let settings = ModelSettings(
            modelName: "test-model",
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 1000,
            frequencyPenalty: 0.1,
            presencePenalty: 0.2,
            stopSequences: ["STOP"],
            toolChoice: .auto,
            parallelToolCalls: true,
            seed: 42,
            additionalParameters: additionalParams
        )
        
        #expect(settings.modelName == "test-model")
        #expect(settings.temperature == 0.7)
        #expect(settings.maxTokens == 1000)
        #expect(settings.topP == 0.9)
        #expect(settings.frequencyPenalty == 0.1)
        #expect(settings.presencePenalty == 0.2)
        #expect(settings.stopSequences == ["STOP"])
        #expect(settings.seed == 42)
        #expect(settings.toolChoice == .auto)
        #expect(settings.parallelToolCalls == true)
        #expect(settings.additionalParameters?.get("apiType") as? String == "chat")
        #expect(settings.additionalParameters?.get("reasoningEffort") as? String == "medium")
    }
}