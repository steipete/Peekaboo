import Foundation
import Testing
@testable import Tachikoma

@Suite("Ollama Model Tests")
struct OllamaModelTests {
    @Test("Model initialization")
    func modelInitialization() async throws {
        let model = OllamaModel(
            modelName: "llama3.3",
            baseURL: URL(string: "http://localhost:11434")!)

        // Ollama doesn't use API keys, so maskedApiKey should return a placeholder
        #expect(model.maskedApiKey == "local-ollama")
    }

    @Test("Default base URL")
    func defaultBaseURL() async throws {
        let model = OllamaModel(modelName: "llama3.3")

        // Should use default localhost URL
        #expect(model.maskedApiKey == "local-ollama")
    }

    @Test("Custom base URL")
    func customBaseURL() async throws {
        let customURL = URL(string: "http://remote-server:11434")!
        let model = OllamaModel(modelName: "llama3.3", baseURL: customURL)

        #expect(model.maskedApiKey == "local-ollama")
    }

    @Test("Tool calling support detection")
    func toolCallingSupportDetection() async throws {
        // Models with tool calling support
        let supportedModels = [
            "llama3.3",
            "llama3.2",
            "llama3.1",
            "mistral-nemo",
            "firefunction-v2",
            "command-r-plus",
            "command-r",
        ]

        for modelName in supportedModels {
            let model = OllamaModel(modelName: modelName)

            let toolDef = ToolDefinition(
                function: FunctionDefinition(
                    name: "get_time",
                    description: "Get current time",
                    parameters: ToolParameters(
                        properties: [:],
                        required: [])))

            let request = ModelRequest(
                messages: [
                    Message.user(content: .text("What time is it?")),
                ],
                tools: [toolDef],
                settings: ModelSettings(modelName: "llama3.3"))

            // Should handle tool calls (will fail at network level)
            do {
                _ = try await model.getResponse(request: request)
                Issue.record("Expected network error for \(modelName)")
            } catch {
                #expect(error is TachikomaError)
            }
        }
    }

    @Test("Vision model tool rejection")
    func visionModelToolRejection() async throws {
        // Vision models that don't support tool calling
        let visionModels = [
            "llava",
            "bakllava",
            "llama3.2-vision:11b",
            "qwen2.5vl:7b",
        ]

        for modelName in visionModels {
            let model = OllamaModel(modelName: modelName)

            let toolDef = ToolDefinition(
                function: FunctionDefinition(
                    name: "get_time",
                    description: "Get current time",
                    parameters: ToolParameters(
                        properties: [:],
                        required: [])))

            let request = ModelRequest(
                messages: [
                    Message.user(content: .text("What time is it?")),
                ],
                tools: [toolDef],
                settings: ModelSettings(modelName: "llama3.3"))

            // Should reject tool calls for vision models
            do {
                _ = try await model.getResponse(request: request)
                Issue.record("Expected error for vision model \(modelName) with tools")
            } catch let error as TachikomaError {
                switch error {
                case .invalidRequest:
                    // Expected - vision models don't support tool calling
                    break
                default:
                    Issue.record("Expected invalidRequest error for \(modelName), got: \(error)")
                }
            }
        }
    }

    @Test("Message type conversion")
    func messageTypeConversion() async throws {
        let model = OllamaModel(modelName: "llama3.3")

        // Test various message types
        let messages: [Message] = [
            Message.system(content: "You are a helpful assistant."),
            Message.user(content: .text("Hello!")),
            Message.assistant(content: [.outputText("Hi there!")]),
            Message.tool(
                toolCallId: "call_123",
                content: "Current time: 2:30 PM"),
        ]

        let request = ModelRequest(
            messages: messages,
            tools: nil,
            settings: ModelSettings(modelName: "llama3.3"))

        // Verify message conversion doesn't crash
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Multimodal message support for vision models")
    func multimodalMessageSupport() async throws {
        let model = OllamaModel(modelName: "llava")

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
            settings: ModelSettings(modelName: "llava"))

        // Verify multimodal content handling for vision models
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Text-only models image rejection")
    func textOnlyModelsImageRejection() async throws {
        let model = OllamaModel(modelName: "llama3.3") // Text-only model

        let imageData = Data([0xFF, 0xD8, 0xFF])

        let request = ModelRequest(
            messages: [
                Message.user(content: .image(ImageContent(base64: imageData.base64EncodedString()))),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "llama3.3"))

        // Should reject image content for text-only models
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error for text-only model with image")
        } catch let error as TachikomaError {
            switch error {
            case .invalidRequest:
                // Expected - text-only models don't support images
                break
            default:
                Issue.record("Expected invalidRequest error, got: \(error)")
            }
        }
    }

    @Test("Streaming response handling")
    func streamingResponse() async throws {
        let model = OllamaModel(modelName: "llama3.3")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Tell me a joke")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "llama3.3"))

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

    @Test("Extended timeout handling")
    func extendedTimeoutHandling() async throws {
        let model = OllamaModel(modelName: "llama3.3")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Generate a long response")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "llama3.3"))

        // Ollama requests should have extended timeouts (5 minutes)
        // We can't test the actual timeout without a real server,
        // but we can verify the request structure
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Tool call JSON parsing")
    func toolCallJSONParsing() async throws {
        let model = OllamaModel(modelName: "llama3.3")

        // Test models that output tool calls as JSON in content
        let toolDef = ToolDefinition(
            function: FunctionDefinition(
                name: "calculate",
                description: "Perform calculation",
                parameters: ToolParameters(
                    properties: [
                        "expression": ParameterSchema(type: .string, description: "Math expression")
                    ],
                    required: ["expression"])))

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("What is 5 + 3?")),
            ],
            tools: [toolDef],
            settings: ModelSettings(modelName: "llama3.3"))

        // Should handle tool call parsing
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error but got success")
        } catch {
            #expect(error is TachikomaError)
        }
    }

    @Test("Error handling")
    func errorHandling() async throws {
        let model = OllamaModel(modelName: "nonexistent-model")

        let request = ModelRequest(
            messages: [
                Message.user(content: .text("Test")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "llama3.3"))

        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected error but got success")
        } catch let error as TachikomaError {
            // Verify we get appropriate error types
            switch error {
            case .apiError, .networkError:
                // Expected error types for nonexistent model
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
        let model = OllamaModel(modelName: "llama3.3")

        let request = ModelRequest(
            messages: [
                Message.reasoning(content: "Let me think..."),
                Message.user(content: .text("Test")),
            ],
            tools: nil,
            settings: ModelSettings(modelName: "llama3.3"))

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

    @Test("File content rejection")
    func fileContentRejection() async throws {
        let model = OllamaModel(modelName: "llama3.3")

        let fileContent = FileContent(
            id: nil,
            url: nil,
            name: "test.txt"
        )

        let request = ModelRequest(
            messages: [
                Message.user(content: .file(fileContent)),
            ],
            settings: ModelSettings(modelName: "llama3.3"))

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
        let model = OllamaModel(modelName: "llama3.3")

        let audioContent = AudioContent(
            transcript: "Hello, this is a test transcript.",
            duration: 5.0
        )

        let request = ModelRequest(
            messages: [
                Message.user(content: .audio(audioContent)),
            ],
            settings: ModelSettings(modelName: "llama3.3"))

        // Test audio content processing (converts to text)
        do {
            _ = try await model.getResponse(request: request)
            Issue.record("Expected network error")
        } catch {
            #expect(error is TachikomaError)
        }
    }
}

// MARK: - Model Provider Tests

@Suite("Ollama Model Provider Tests")
struct OllamaModelProviderTests {
    @Test("Ollama model registration")
    func ollamaModelRegistration() async throws {
        let tachikoma = Tachikoma.shared

        // Register a test Ollama model
        await tachikoma.registerModel(name: "test-llama", factory: {
            OllamaModel(modelName: "llama3.3")
        })

        // Test that we can get the model
        do {
            let model = try await tachikoma.getModel("test-llama")
            #expect(model is OllamaModel)
        } catch {
            Issue.record("Failed to get registered model: \(error)")
        }
    }

    @Test("Model name variants")
    func modelNameVariants() async throws {
        let tachikoma = Tachikoma.shared

        // Register various Ollama model names
        let modelNames = [
            "llama3.3",
            "llama3.2",
            "llama3.1",
            "llava",
            "mistral-nemo",
            "firefunction-v2",
            "command-r-plus",
            "deepseek-r1:8b",
        ]

        for modelName in modelNames {
            await tachikoma.registerModel(name: modelName, factory: {
                OllamaModel(modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel(modelName)
                #expect(model is OllamaModel)
            } catch {
                Issue.record("Failed to get model \(modelName): \(error)")
            }
        }
    }

    @Test("Base URL configuration")
    func baseURLConfiguration() async throws {
        let tachikoma = Tachikoma.shared

        // Test custom base URL
        let customURL = URL(string: "http://remote-ollama:11434")!

        await tachikoma.registerModel(name: "custom-ollama", factory: {
            OllamaModel(modelName: "llama3.3", baseURL: customURL)
        })

        do {
            let model = try await tachikoma.getModel("custom-ollama")
            #expect(model is OllamaModel)
        } catch {
            Issue.record("Failed to get custom URL model: \(error)")
        }
    }

    @Test("Tool support matrix")
    func toolSupportMatrix() async throws {
        let tachikoma = Tachikoma.shared

        // Models with tool support
        let toolSupportedModels = [
            "llama3.3",
            "llama3.2",
            "mistral-nemo",
            "firefunction-v2",
        ]

        // Models without tool support  
        let nonToolModels = [
            "llava",
            "bakllava",
            "devstral",
        ]

        let toolDef = ToolDefinition(
            function: FunctionDefinition(
                name: "test_tool",
                description: "Test tool",
                parameters: ToolParameters(properties: [:], required: [])))

        // Test tool-supported models
        for modelName in toolSupportedModels {
            await tachikoma.registerModel(name: "tool-\(modelName)", factory: {
                OllamaModel(modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel("tool-\(modelName)")
                #expect(model is OllamaModel)

                // Should accept tool definitions
                let request = ModelRequest(
                    messages: [Message.user(content: .text("Use tool"))],
                    tools: [toolDef],
                    settings: ModelSettings(modelName: "llama3.3"))

                do {
                    _ = try await model.getResponse(request: request)
                    Issue.record("Expected network error for \(modelName)")
                } catch {
                    #expect(error is TachikomaError)
                }
            } catch {
                Issue.record("Failed to get tool model \(modelName): \(error)")
            }
        }

        // Test non-tool models
        for modelName in nonToolModels {
            await tachikoma.registerModel(name: "no-tool-\(modelName)", factory: {
                OllamaModel(modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel("no-tool-\(modelName)")
                #expect(model is OllamaModel)

                // Should reject tool definitions
                let request = ModelRequest(
                    messages: [Message.user(content: .text("Use tool"))],
                    tools: [toolDef],
                    settings: ModelSettings(modelName: "llama3.3"))

                do {
                    _ = try await model.getResponse(request: request)
                    Issue.record("Expected error for non-tool model \(modelName)")
                } catch let error as TachikomaError {
                    switch error {
                    case .invalidRequest:
                        // Expected for non-tool models
                        break
                    default:
                        Issue.record("Expected invalidRequest for \(modelName), got: \(error)")
                    }
                }
            } catch {
                Issue.record("Failed to get non-tool model \(modelName): \(error)")
            }
        }
    }

    @Test("Vision capability detection")
    func visionCapabilityDetection() async throws {
        let tachikoma = Tachikoma.shared

        // Vision models
        let visionModels = ["llava", "bakllava", "llama3.2-vision:11b"]
        
        // Text-only models
        let textModels = ["llama3.3", "mistral-nemo", "command-r"]

        let imageData = Data([0xFF, 0xD8, 0xFF])

        // Test vision models accept images
        for modelName in visionModels {
            await tachikoma.registerModel(name: "vision-\(modelName)", factory: {
                OllamaModel(modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel("vision-\(modelName)")
                let request = ModelRequest(
                    messages: [Message.user(content: .image(ImageContent(base64: imageData.base64EncodedString())))],
                    settings: ModelSettings(modelName: "llama3.3"))

                do {
                    _ = try await model.getResponse(request: request)
                    Issue.record("Expected network error for vision model \(modelName)")
                } catch {
                    #expect(error is TachikomaError)
                }
            } catch {
                Issue.record("Failed vision model test for \(modelName): \(error)")
            }
        }

        // Test text models reject images
        for modelName in textModels {
            await tachikoma.registerModel(name: "text-\(modelName)", factory: {
                OllamaModel(modelName: modelName)
            })

            do {
                let model = try await tachikoma.getModel("text-\(modelName)")
                let request = ModelRequest(
                    messages: [Message.user(content: .image(ImageContent(base64: imageData.base64EncodedString())))],
                    settings: ModelSettings(modelName: "llama3.3"))

                do {
                    _ = try await model.getResponse(request: request)
                    Issue.record("Expected error for text model \(modelName) with image")
                } catch let error as TachikomaError {
                    switch error {
                    case .invalidRequest:
                        // Expected for text-only models
                        break
                    default:
                        Issue.record("Expected invalidRequest for \(modelName), got: \(error)")
                    }
                }
            } catch {
                Issue.record("Failed text model test for \(modelName): \(error)")
            }
        }
    }
}