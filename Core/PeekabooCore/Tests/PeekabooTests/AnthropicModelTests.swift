import Foundation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

struct AnthropicModelTests {
    @Test
    func `Anthropic model selection and properties`() {
        // Test current Anthropic models
        let opus45 = Model.anthropic(.opus45)
        let sonnet4 = Model.anthropic(.sonnet4)
        let haiku45 = Model.anthropic(.haiku45)

        #expect(opus45.providerName == "Anthropic")
        #expect(sonnet4.providerName == "Anthropic")
        #expect(haiku45.providerName == "Anthropic")

        // Test model capabilities
        #expect(opus45.supportsVision == true)
        #expect(opus45.supportsTools == true)
        #expect(opus45.supportsStreaming == true)
        #expect(opus45.contextLength > 100_000) // All Claude models have large context

        // Test model IDs
        #expect(opus45.modelId.contains("opus"))
        #expect(sonnet4.modelId.contains("sonnet"))
        #expect(haiku45.modelId.contains("haiku"))
    }

    @Test
    func `Anthropic default model selection`() {
        // Test that Claude Opus is the default
        let defaultModel = Model.default
        let claudeModel = Model.claude

        #expect(defaultModel.providerName == "Anthropic")
        #expect(claudeModel.providerName == "Anthropic")

        // Test model shortcuts
        let anthropicModels = [
            Model.anthropic(.opus45),
            Model.anthropic(.sonnet4),
            Model.anthropic(.haiku45),
        ]

        for model in anthropicModels {
            #expect(model.providerName == "Anthropic")
            #expect(!model.modelId.isEmpty)
        }
    }

    @Test(.enabled(if: false)) // Disabled - requires API key
    func `Anthropic model generation integration`() async throws {
        // This test would require real API credentials
        // Testing the integration without actual API calls

        let model = Model.anthropic(.opus45)
        let messages = [
            ModelMessage.user("What is 2+2?"),
        ]

        // Test that the API call structure is correct (would fail without API key)
        do {
            _ = try await generateText(
                model: model,
                messages: messages,
                tools: nil,
                settings: .default,
                maxSteps: 1)
            #expect(Bool(true)) // Should not reach here without API key
        } catch {
            // Expected to fail without API key - this is testing the structure
            #expect(error is TachikomaError)
        }
    }

    @Test
    func `Anthropic vision model capabilities`() {
        let visionCapableModels = [
            Model.anthropic(.opus45),
            Model.anthropic(.sonnet4),
            Model.anthropic(.haiku45),
        ]

        for model in visionCapableModels {
            #expect(model.supportsVision == true)
        }
    }

    @Test
    func `Anthropic model comparison`() {
        let opus45 = Model.anthropic(.opus45)
        let sonnet4 = Model.anthropic(.sonnet4)
        let haiku45 = Model.anthropic(.haiku45)

        // Test model descriptions
        #expect(opus45.description.contains("Anthropic"))
        #expect(sonnet4.description.contains("Anthropic"))
        #expect(haiku45.description.contains("Anthropic"))

        // Test that they're different models
        #expect(opus45.modelId != sonnet4.modelId)
        #expect(sonnet4.modelId != haiku45.modelId)
        #expect(opus45.modelId != haiku45.modelId)

        // Test model hierarchy (Opus > Sonnet > Haiku typically)
        #expect(opus45.contextLength >= sonnet4.contextLength)
        #expect(sonnet4.contextLength >= haiku45.contextLength)
    }

    @Test
    func `Anthropic thinking models`() {
        // Test thinking variants
        let opus4Thinking = Model.anthropic(.opus4Thinking)
        let sonnet4Thinking = Model.anthropic(.sonnet4Thinking)

        #expect(opus4Thinking.providerName == "Anthropic")
        #expect(sonnet4Thinking.providerName == "Anthropic")

        #expect(opus4Thinking.modelId.contains("thinking"))
        #expect(sonnet4Thinking.modelId.contains("thinking"))

        // Thinking models should have extended reasoning capabilities
        #expect(opus4Thinking.supportsTools == true)
        #expect(sonnet4Thinking.supportsTools == true)
    }
}
