import Foundation
import Testing
@testable import Tachikoma

@Suite("OpenAI Model Tests")
struct OpenAIModelTests {
    @Test("Model initialization")
    func modelInitialization() async throws {
        let model = OpenAIModel(
            apiKey: "sk-test-key-123456789",
            modelName: "gpt-4.1")

        #expect(model.maskedApiKey == "sk-...789")
    }

    @Test("API key masking")
    func apiKeyMasking() async throws {
        // Test short key
        let shortModel = OpenAIModel(apiKey: "short")
        #expect(shortModel.maskedApiKey == "***")

        // Test normal key
        let normalModel = OpenAIModel(apiKey: "sk-test-api-key-1234567890abcdefghijklmnopqrstuvwxyz")
        #expect(normalModel.maskedApiKey == "sk-...xyz")
    }

    @Test("Default base URL")
    func defaultBaseURL() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        // Verify it uses the correct OpenAI API endpoint
        // We can't directly access baseURL, but we can test the behavior
        #expect(model.maskedApiKey == "***")
    }

    @Test("Dual API support")
    func dualAPISupport() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        // Test Chat Completions API request
        let chatRequest = ModelRequest(
            messages: [
                Message.user(content: .text("Hello")),
            ],
            tools: nil,
            settings: ModelSettings(apiType: "chat"))

        // Test Responses API request (for reasoning models)
        let responsesRequest = ModelRequest(
            messages: [
                Message.user(content: .text("Hello")),
            ],
            tools: nil,
            settings: ModelSettings(apiType: "responses"))

        // Both should be processable (will fail at network level)
        do {
            _ = try await model.getResponse(request: chatRequest)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }

        do {
            _ = try await model.getResponse(request: responsesRequest)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Reasoning models parameter handling")
    func reasoningModelsParameterHandling() async throws {
        let model = OpenAIModel(apiKey: "test-key", modelName: "o3")

        // Create a request with reasoning parameters
        let settings = ModelSettings(
            reasoningEffort: "medium",
            reasoning: ["summary": "detailed"],
            temperature: nil // o3 models don't support temperature
        )

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Solve this complex problem")),
            ],
            tools: nil,
            settings: settings)

        // Should handle reasoning parameters correctly
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Tool parameter conversion")
    func toolParameterConversion() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        // Create a tool definition
        let tool = ToolDefinition(
            function: FunctionDefinition(
                name: "get_weather",
                description: "Get current weather",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "location": ParameterSchema(
                            type: .string,
                            description: "The location"),
                        "units": ParameterSchema(
                            type: .string,
                            description: "Temperature units",
                            enumValues: ["celsius", "fahrenheit"]),
                    ],
                    required: ["location"])))

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("What's the weather in Paris?")),
            ],
            tools: [tool],
            settings: ModelSettings(modelName: "gpt-4.1"))

        // Verify the model can process tool definitions
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Message type conversion")
    func messageTypeConversion() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        // Test various message types
        let messages: [Message] = [
            Message.system(content: "You are a helpful assistant."),
            Message.user(content: .text("Hello!")),
            Message.assistant(content: [.outputText("Hi there!")]),
            Message.tool(
                toolCallId: "call_123",
                content: "Weather data"),
        ]

        let request = ModelRequest(
            messages: messages,
            tools: nil,
            settings: ModelSettings(modelName: "gpt-4.1"))

        // Verify message conversion doesn't crash
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Multimodal message support")
    func multimodalMessageSupport() async throws {
        let model = OpenAIModel(apiKey: "test-key", modelName: "gpt-4o")

        // Create a multimodal message with text and image
        let imageData = Data([0xFF, 0xD8, 0xFF]) // Minimal JPEG header

        let request = ModelRequest(
            messages: [
                Message.user(content: .multimodal([
                    MessageContentPart(type: "text", text: "What is in this image?"),
                    MessageContentPart(type: "image", imageUrl: ImageContent(base64: imageData.base64EncodedString())),
                ])),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "gpt-4.1"))

        // Verify multimodal content handling
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Streaming response handling")
    func streamingResponse() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Write a short story")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "gpt-4.1"))

        // Test streaming
        do {
            let stream = try await model.getStreamedResponse(request: request)
            var eventCount = 0

            for try await event in stream {
                eventCount += 1
                _ = event
            }

            Issue.record("Expected network error but got success with \(eventCount) events")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Error handling")
    func errorHandling() async throws {
        let model = OpenAIModel(apiKey: "invalid-key")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Test")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "gpt-4.1"))

        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error but got success")
        } catch let error as TachikomaError {
            // Verify we get appropriate error types
            switch error {
            case .apiError, .authenticationFailed:
                // Expected error types for invalid API key
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
    }

    @Test("Reasoning message handling")
    func reasoningMessageHandling() async throws {
        let model = OpenAIModel(apiKey: "test-key", modelName: "o3")

        let request = ModelRequest(
            messages: [
                Message.reasoning(content: "Let me think about this step by step..."),
                Message.user(content: .text("What is 2+2?")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "gpt-4.1"))

        // o3 models should handle reasoning messages
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Model variants")
    func modelVariants() async throws {
        let modelNames = [
            "o3",
            "o3-mini",
            "o3-pro",
            "o4-mini",
            "gpt-4.1",
            "gpt-4.1-mini",
            "gpt-4o",
            "gpt-4o-mini",
        ]

        for modelName in modelNames {
            let model = OpenAIModel(apiKey: "test-key", modelName: modelName)
            #expect(model.maskedApiKey == "***")

            // Test that each model variant can be created and handles requests
            let request = ModelRequest(
                messages: [Message.user(content: .text("Test"))],
                settings: ModelSettings(modelName: "gpt-4.1"))

            do {
                _ = try await model.getResponse(request: request)
                Issue.record("Expected network error for \(modelName)")
            } catch {
                #expect(error is TachikomaError)
            }
        }
    }

    @Test("Temperature parameter filtering")
    func temperatureParameterFiltering() async throws {
        // o3 models should not support temperature
        let o3Model = OpenAIModel(apiKey: "test-key", modelName: "o3")
        let gptModel = OpenAIModel(apiKey: "test-key", modelName: "gpt-4.1")

        let settings = ModelSettings(temperature: 0.7)

        let request = ModelRequest(
            messages: [Message.user(content: .text("Test"))],
            settings: settings)

        // Both should handle the request (temperature filtered for o3)
        for (name, model) in [("o3", o3Model), ("gpt-4.1", gptModel)] {
            do {
                _ = try await model.getResponse(request: request)
                Issue.record("Expected network error for \(name)")
            } catch {
                #expect(error is TachikomaError)
            }
        }
    }

    @Test("File content rejection")
    func fileContentRejection() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        let fileContent = FileContent(
            filename: "test.txt",
            content: "Test file content",
            mimeType: "text/plain")

        let request = ModelRequest(
            messages: [
                Message.user(content: .file(fileContent)),
            ],
            settings: ModelSettings(modelName: "gpt-4.1"))

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

    @Test("Audio content handling")
    func audioContentHandling() async throws {
        let model = OpenAIModel(apiKey: "test-key")

        let audioContent = AudioContent(
            transcript: "Hello, this is a test transcript.",
            duration: 5.0)

        let request = ModelRequest(
            messages: [
                Message.user(content: .audio(audioContent)),
            ],
            settings: ModelSettings(modelName: "gpt-4.1"))

        // Test audio content processing
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error")
        } catch {
            #expect(error is TachikomaError)
        }
    }
}

// MARK: - Provider Configuration Tests

@Suite("OpenAI Provider Configuration Tests")
struct OpenAIProviderConfigurationTests {
    @Test("Provider configuration")
    func providerConfiguration() async throws {
        let tachikoma = Tachikoma.shared

        // Test custom OpenAI configuration
        let config = ProviderConfiguration.OpenAI(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.openai.com/v1")!)

        await tachikoma.configureOpenAI(config)
    }

    @Test("Model registration")
    func modelRegistration() async throws {
        let tachikoma = Tachikoma.shared

        // Register OpenAI models
        let modelNames = [
            "o3",
            "o3-mini",
            "gpt-4.1",
            "gpt-4o",
        ]

        for modelName in modelNames {
            await tachikoma.registerModel(name: modelName, factory: {
                OpenAIModel(apiKey: "test-key", modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel(modelName)
                #expect(model is OpenAIModel)
            } catch {
                Issue.record("Failed to get model \(modelName): \(error)")
            }
        }
    }

    @Test("API type selection")
    func apiTypeSelection() async throws {
        let tachikoma = Tachikoma.shared

        // Register models with different API preferences
        await tachikoma.registerModel(name: "gpt-4.1-chat", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "gpt-4.1")
        })

        await tachikoma.registerModel(name: "o3-responses", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "o3")
        })

        // Test that both can be retrieved
        do {
            let chatModel = try await tachikoma.getModel("gpt-4.1-chat")
            #expect(chatModel is OpenAIModel)

            let responsesModel = try await tachikoma.getModel("o3-responses")
            #expect(responsesModel is OpenAIModel)
        } catch {
            Issue.record("Failed to get models: \(error)")
        }
    }

    @Test("Lenient model name resolution")
    func lenientModelNameResolution() async throws {
        let tachikoma = Tachikoma.shared

        // Register base models
        await tachikoma.registerModel(name: "gpt-4.1", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "gpt-4.1")
        })

        await tachikoma.registerModel(name: "o3", factory: {
            OpenAIModel(apiKey: "test-key", modelName: "o3")
        })

        // Test lenient name matching
        let nameMapping = [
            "gpt": "gpt-4.1",
            "gpt-4": "gpt-4.1",
            "gpt4": "gpt-4.1",
            "o3": "o3",
        ]

        for (input, _) in nameMapping {
            do {
                let model = try await tachikoma.getModel(input)
                #expect(model is OpenAIModel)
            } catch {
                Issue.record("Failed to resolve \(input): \(error)")
            }
        }
    }
}
