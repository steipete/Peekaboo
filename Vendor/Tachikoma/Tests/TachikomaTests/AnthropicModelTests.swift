import Foundation
import Testing
@testable import Tachikoma

@Suite("Anthropic Model Tests")
struct AnthropicModelTests {
    @Test("Model initialization")
    func modelInitialization() async throws {
        let model = AnthropicModel(
            apiKey: "sk-ant-test-key-123456789",
            modelName: "claude-opus-4-20250514")

        #expect(model.maskedApiKey == "sk-ant...789")
    }

    @Test("API key masking")
    func apiKeyMasking() async throws {
        // Test short key
        let shortModel = AnthropicModel(apiKey: "short")
        #expect(shortModel.maskedApiKey == "***")

        // Test normal key
        let normalModel = AnthropicModel(apiKey: "sk-ant-api-key-1234567890abcdefghijklmnopqrstuvwxyz")
        #expect(normalModel.maskedApiKey == "sk-ant...xyz")
    }

    @Test("System message extraction")
    func systemMessageExtraction() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        let request = ModelRequest(
            messages: [
                Message.system(content: "You are a helpful assistant."),
                Message.user(content: .text("Hello!")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        // System messages should be properly handled
        #expect(request.messages.first?.type == .system)
    }

    @Test("Tool conversion")
    func toolConversion() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        let toolDef = ToolDefinition(
            function: FunctionDefinition(
                name: "get_weather",
                description: "Get the current weather",
                parameters: ToolParameters(
                    properties: ["location": ParameterSchema(type: .string, description: "The location")],
                    required: ["location"])))

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("What's the weather?")),
            ],
            tools: [toolDef],
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        #expect(request.tools?.count == 1)
        #expect(request.tools?.first?.function.name == "get_weather")

        // Test that the model can process the request (will fail at network level)
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Image content handling")
    func imageContentHandling() async throws {
        let model = AnthropicModel(apiKey: "test-key", modelName: "claude-opus-4-20250514")

        let imageData = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

        let request = ModelRequest(
            messages: [
                Message.user(content: .multimodal([
                    MessageContentPart(type: "text", text: "What's in this image?"),
                    MessageContentPart(type: "image", imageUrl: ImageContent(base64: imageData)),
                ])),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        if case let .user(_, content) = request.messages.first,
           case let .multimodal(parts) = content
        {
            #expect(parts.count == 2)
        } else {
            Issue.record("Expected multimodal content")
        }

        // Test that URL images are supported
        let urlRequest = ModelRequest(
            messages: [
                Message.user(content: .image(ImageContent(url: "https://example.com/image.jpg"))),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        if case let .user(_, content) = urlRequest.messages.first,
           case .image = content
        {
            // Expected image content
        } else {
            Issue.record("Expected image content")
        }

        // Test processing (will fail at network level)
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Message type conversion")
    func messageTypeConversion() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        // Test various message types
        let messages: [Message] = [
            Message.system(content: "You are Claude."),
            Message.user(content: .text("Hello Claude!")),
            Message.assistant(content: [.outputText("Hello! How can I help you?")]),
            Message.user(content: .text("What's 2+2?")),
            Message.assistant(content: [.outputText("2 + 2 = 4")]),
        ]

        let request = ModelRequest(
            messages: messages,
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        // Verify message structure
        #expect(request.messages.count == 5)
        #expect(request.messages[0].type == .system)
        #expect(request.messages[1].type == .user)
        #expect(request.messages[2].type == .assistant)

        // Test processing (will fail at network level)
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Streaming response handling")
    func streamingResponseHandling() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Write a short poem")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        // Test streaming (will fail at network level)
        do {
            let stream = try await model.getStreamedResponse(request: request)
            var eventCount = 0

            for try await event in stream {
                eventCount += 1
                _ = event
            }

            Issue.record("Expected network error but got \(eventCount) events")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Tool call handling")
    func toolCallHandling() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        // Create a tool call message
        let toolCall = ToolCallItem(
            id: "call_123",
            type: .function,
            function: FunctionCall(
                name: "get_weather",
                arguments: "{\"location\": \"Paris\"}"
            )
        )

        let messages: [Message] = [
            Message.user(content: .text("What's the weather in Paris?")),
            Message.assistant(content: [.toolCall(toolCall)]),
            Message.tool(toolCallId: "call_123", content: "It's sunny, 22°C"),
        ]

        let request = ModelRequest(
            messages: messages,
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        // Test tool call processing (will fail at network level)
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Model variants")
    func modelVariants() async throws {
        let modelNames = [
            "claude-opus-4-20250514",
            "claude-sonnet-4-20250514",
            "claude-opus-4-20250514-thinking",
            "claude-sonnet-4-20250514-thinking",
            "claude-3-7-sonnet",
            "claude-3-5-sonnet",
            "claude-3-5-haiku",
        ]

        for modelName in modelNames {
            let model = AnthropicModel(apiKey: "test-key", modelName: modelName)
            #expect(model.maskedApiKey == "***")

            // Test that each model variant can be created and handles requests
            let request = ModelRequest(
                messages: [Message.user(content: .text("Test"))],
                settings: ModelSettings(modelName: "claude-opus-4-20250514"))

            do {
                _ = try await model.getResponse(request: request)
                Issue.record("Expected network error for \(modelName)")
            } catch {
                #expect(error is TachikomaError)
            }
        }
    }

    @Test("Error handling")
    func errorHandling() async throws {
        let model = AnthropicModel(apiKey: "invalid-key")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Test")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error but got success")
        } catch let error as TachikomaError {
            // Verify we get appropriate error types
            switch error {
            case .apiError, .authenticationFailed, .networkError:
                // Expected error types for invalid API key
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
    }

    @Test("Audio content handling")
    func audioContentHandling() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        let audioContent = AudioContent(
            transcript: "Hello, this is a test transcript.",
            duration: 5.0
        )

        let request = ModelRequest(
            messages: [
                Message.user(content: .audio(audioContent)),
            ],
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        // Test audio content processing
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("File content rejection")
    func fileContentRejection() async throws {
        let model = AnthropicModel(apiKey: "test-key")

        let fileContent = FileContent(
            id: nil,
            url: nil,
            name: "test.txt"
        )

        let request = ModelRequest(
            messages: [
                Message.user(content: .file(fileContent)),
            ],
            settings: ModelSettings(modelName: "claude-opus-4-20250514"))

        // File content should be rejected
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error for file content")
        } catch let error as TachikomaError {
            switch error {
            case .invalidRequest:
                // Expected - file content not supported
                break
            default:
                Issue.record("Expected invalidRequest error, got: \(error)")
            }
        }
    }
}

// MARK: - Provider Configuration Tests

@Suite("Anthropic Provider Configuration Tests")
struct AnthropicProviderConfigurationTests {
    @Test("Provider configuration")
    func providerConfiguration() async throws {
        let tachikoma = Tachikoma.shared

        // Test custom Anthropic configuration
        let config = ProviderConfiguration.Anthropic(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.anthropic.com/v1")!
        )

        await tachikoma.configureAnthropic(config)
    }

    @Test("Model registration")
    func modelRegistration() async throws {
        let tachikoma = Tachikoma.shared

        // Register Claude models
        let modelNames = [
            "claude-opus-4",
            "claude-sonnet-4",
            "claude-3-5-sonnet",
            "claude-3-5-haiku",
        ]

        for modelName in modelNames {
            await tachikoma.registerModel(name: modelName, factory: {
                AnthropicModel(apiKey: "test-key", modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel(modelName)
                #expect(model is AnthropicModel)
            } catch {
                Issue.record("Failed to get model \(modelName): \(error)")
            }
        }
    }
}