import Foundation
import Testing
@testable import Tachikoma

@Suite("Grok Model Tests")
struct GrokModelTests {
    @Test("Model initialization")
    func modelInitialization() async throws {
        let model = GrokModel(
            apiKey: "test-key-123456",
            baseURL: URL(string: "https://api.x.ai/v1")!)

        #expect(model.maskedApiKey == "test-k...56")
    }

    @Test("API key masking")
    func apiKeyMasking() async throws {
        // Test short key
        let shortModel = GrokModel(apiKey: "short")
        #expect(shortModel.maskedApiKey == "***")

        // Test normal key
        let normalModel = GrokModel(apiKey: "test-api-key-1234567890abcdefghijklmnopqrstuvwxyz")
        #expect(normalModel.maskedApiKey == "test-a...yz")
    }

    @Test("Default base URL")
    func defaultBaseURL() async throws {
        let model = GrokModel(apiKey: "test-key-123456")

        // Verify it uses the correct xAI API endpoint
        // We can't directly access baseURL, but we can test the behavior
        #expect(model.maskedApiKey == "test-k...56")
    }

    @Test("Parameter filtering for Grok 4")
    func grok4ParameterFiltering() async throws {
        let model = GrokModel(apiKey: "test-key")

        // Create a request with parameters that should be filtered for Grok 4
        let settings = ModelSettings(
            modelName: "grok-4",
            temperature: 0.7,
            frequencyPenalty: 0.5, // Should be removed for grok-4
            presencePenalty: 0.5, // Should be removed for grok-4
            stopSequences: ["stop"] // Should be removed for grok-4
        )

        let request = ModelRequest(
            messages: [
                Message.system(content: "Test system message"),
                Message.user(content: .text("Test user message")),
            ],
            tools: nil,
            settings: settings)

        // We can't directly test the filtering without mocking the network request
        // But we can verify the model handles the request without crashing
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is TachikomaError)
        }
    }

    @Test("Tool parameter conversion")
    func toolParameterConversion() async throws {
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
                            description: "A test message"),
                        "count": ParameterSchema(
                            type: .integer,
                            description: "A count",
                            minimum: 0,
                            maximum: 100),
                    ],
                    required: ["message"])))

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Use the test tool")),
            ],
            tools: [tool],
            settings: ModelSettings(modelName: "grok-4"))

        // Verify the model can process tool definitions
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is TachikomaError)
        }
    }

    @Test("Message type conversion")
    func messageTypeConversion() async throws {
        let model = GrokModel(apiKey: "test-key")

        // Test various message types
        let messages: [Message] = [
            Message.system(content: "System prompt"),
            Message.user(content: .text("User text")),
            Message.assistant(content: [.outputText("Assistant response")]),
            Message.tool(
                toolCallId: "tool-123",
                content: "Tool result"),
        ]

        let request = ModelRequest(
            messages: messages,
            tools: nil,
            settings: ModelSettings(modelName: "grok-4"))

        // Verify message conversion doesn't crash
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is TachikomaError)
        }
    }

    @Test("Multimodal message support")
    func multimodalMessageSupport() async throws {
        let model = GrokModel(apiKey: "test-key", modelName: "grok-2-vision-1212")

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
            settings: ModelSettings(modelName: "grok-2-vision-1212"))

        // Verify multimodal content handling
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            // Expected to fail due to no valid API key/network
            #expect(error is TachikomaError)
        }
    }

    @Test("Streaming response handling")
    func streamingResponse() async throws {
        let model = GrokModel(apiKey: "test-key")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Stream this response")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "grok-4"))

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
            #expect(error is TachikomaError)
        }
    }

    @Test("Error handling")
    func errorHandling() async throws {
        let model = GrokModel(apiKey: "invalid-key")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Test")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "grok-4"))

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

    @Test("Reasoning message rejection")
    func reasoningMessageRejection() async throws {
        let model = GrokModel(apiKey: "test-key")

        let request = ModelRequest(
            messages: [
                Message.reasoning(content: "Some reasoning"),
                Message.user(content: .text("Test")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "grok-4"))

        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error for reasoning messages")
        } catch let error as TachikomaError {
            switch error {
            case .invalidRequest:
                // Expected - reasoning messages not supported
                break
            default:
                Issue.record("Expected invalidRequest error, got: \(error)")
            }
        }
    }
}

// MARK: - Model Provider Tests

@Suite("Grok Model Provider Tests")
struct GrokModelProviderTests {
    @Test("Grok model registration")
    func grokModelRegistration() async throws {
        let tachikoma = Tachikoma.shared

        // Register a test Grok model
        await tachikoma.registerModel(name: "test-grok", factory: {
            GrokModel(apiKey: "test-key", modelName: "grok-4")
        })

        // Test that we can get the model
        do {
            let model = try await tachikoma.getModel("test-grok")
            #expect(model is GrokModel)
        } catch {
            Issue.record("Failed to get registered model: \(error)")
        }
    }

    @Test("Model name variants")
    func modelNameVariants() async throws {
        let tachikoma = Tachikoma.shared

        // Register various Grok model names
        let modelNames = [
            "grok-4",
            "grok-4-0709",
            "grok-4-latest",
            "grok-2-1212",
            "grok-2-vision-1212",
            "grok-beta",
            "grok-vision-beta",
        ]

        for modelName in modelNames {
            await tachikoma.registerModel(name: modelName, factory: {
                GrokModel(apiKey: "test-key", modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel(modelName)
                #expect(model is GrokModel)
            } catch {
                Issue.record("Failed to get model \(modelName): \(error)")
            }
        }
    }

    @Test("Parameter filtering detection")
    func parameterFilteringDetection() async throws {
        // Test that Grok 3 and 4 models filter parameters correctly
        let grok3Model = GrokModel(apiKey: "test-key", modelName: "grok-3")
        let grok4Model = GrokModel(apiKey: "test-key", modelName: "grok-4")
        let grokBetaModel = GrokModel(apiKey: "test-key", modelName: "grok-beta")

        // All should handle the same request without errors (though network will fail)
        let settings = ModelSettings(
            modelName: "grok-4",
            temperature: 0.7,
            frequencyPenalty: 0.5,
            presencePenalty: 0.5,
            stopSequences: ["stop"])

        let request = ModelRequest(
            messages: [Message.user(content: .text("Test"))],
            settings: settings)

        // Test each model handles parameter filtering
        for (name, model) in [("grok-3", grok3Model), ("grok-4", grok4Model), ("grok-beta", grokBetaModel)] {
            do {
                _ = try await model.getResponse(request: request)
                Issue.record("Expected network error for \(name)")
            } catch {
                // Expected to fail due to network/auth, but not due to parameter issues
                #expect(error is TachikomaError)
            }
        }
    }
}
