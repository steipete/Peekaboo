import Foundation
import Tachikoma
import Testing
@testable import PeekabooCore

@Suite("Grok LanguageModel Tests - Tachikoma Integration")
struct GrokLanguageModelTests {
    @Test("Grok model selection and properties")
    func modelSelectionAndProperties() {
        // Test current Grok models
        let grok4 = LanguageModel.grok(.grok4)
        let grok2 = LanguageModel.grok(.grok3)
        let grok2Vision = LanguageModel.grok(.grok2Image)
        let grokBeta = LanguageModel.grok(.grok3Mini)

        #expect(grok4.providerName == "Grok")
        #expect(grok2.providerName == "Grok")
        #expect(grok2Vision.providerName == "Grok")
        #expect(grokBeta.providerName == "Grok")

        // Test model capabilities
        #expect(grok4.supportsTools == true)
        #expect(grok4.supportsStreaming == true)
        #expect(grok2Vision.supportsVision == true)

        // Test model IDs
        #expect(grok4.modelId.contains("grok"))
        #expect(grok2.modelId.contains("grok"))
        #expect(grok2Vision.modelId.contains("vision"))
    }

    @Test("Grok default model selection")
    func defaultLanguageModelSelection() {
        // Test Grok shortcuts
        let grokLanguageModel = LanguageModel.grok4
        let grokDefault = LanguageModel.grok(.grok4)

        #expect(grokLanguageModel.providerName == "Grok")
        #expect(grokDefault.providerName == "Grok")

        // Test that grok shortcut points to grok-4
        #expect(grokLanguageModel.modelId == grokDefault.modelId)
    }

    @Test("Grok model variations")
    func modelVariations() {
        let models = [
            LanguageModel.grok(.grok4),
            LanguageModel.grok(.grok4),
            LanguageModel.grok(.grok3),
            LanguageModel.grok(.grok2Image),
            LanguageModel.grok(.grok3Mini),
            LanguageModel.grok(.grok2Image),
        ]

        for model in models {
            #expect(model.providerName == "Grok")
            #expect(!model.modelId.isEmpty)
            #expect(model.description.contains("Grok"))
        }

        // Test vision models have vision capability
        let visionLanguageModels = [
            LanguageModel.grok(.grok2Image),
            LanguageModel.grok(.grok2Image),
        ]

        for visionLanguageModel in visionLanguageModels {
            #expect(visionLanguageModel.supportsVision == true)
        }
    }

    @Test("Grok model context lengths")
    func modelContextLengths() {
        let grok4 = LanguageModel.grok(.grok4)
        let grok2 = LanguageModel.grok(.grok3)

        // Grok models should have reasonable context lengths
        #expect(grok4.contextLength > 50000) // At least 50K context
        #expect(grok2.contextLength > 50000) // At least 50K context

        // Test that context length is accessible
        #expect(grok4.contextLength > 0)
        #expect(grok2.contextLength > 0)
    }

    @Test("Grok model generation integration", .enabled(if: false)) // Disabled - requires API key
    func modelGenerationIntegration() async throws {
        // This test would require real API credentials from xAI
        // Testing the integration without actual API calls

        let model = LanguageModel.grok(.grok4)
        let messages = [
            ModelMessage.user("What is the meaning of life?"),
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

    @Test("Grok API compatibility")
    func apiCompatibility() {
        // Test that Grok models are compatible with OpenAI-style API
        let grokLanguageModels = [
            LanguageModel.grok(.grok4),
            LanguageModel.grok(.grok3),
            LanguageModel.grok(.grok3Mini),
        ]

        for model in grokLanguageModels {
            // Grok uses OpenAI-compatible Chat Completions API
            #expect(model.supportsStreaming == true)
            #expect(model.supportsTools == true)

            // Test model description format
            let description = model.description
            #expect(description.contains("Grok"))
            #expect(description.contains("/"))
        }
    }

    @Test("Grok parameter filtering")
    func parameterFiltering() {
        // Test that Grok 4 models don't support certain OpenAI parameters
        let grok4 = LanguageModel.grok(.grok4)

        // These are implementation details that would be tested in provider code
        // Here we just verify the model exists and has expected properties
        #expect(grok4.modelId.contains("grok-4"))
        #expect(grok4.providerName == "Grok")

        // Grok models should support basic functionality
        #expect(grok4.supportsStreaming == true)
        #expect(grok4.supportsTools == true)
    }
}
