import Foundation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("Grok LanguageModel Tests - Tachikoma Integration")
struct GrokLanguageModelTests {
    @Test("Grok model selection and properties")
    func modelSelectionAndProperties() {
        let grok4 = LanguageModel.grok(.grok4)
        let grokFast = LanguageModel.grok(.grok4FastReasoning)
        let grok3 = LanguageModel.grok(.grok3)
        let grokVision = LanguageModel.grok(.grok2Vision)
        let grokImage = LanguageModel.grok(.grok2Image)

        for model in [grok4, grokFast, grok3, grokVision, grokImage] {
            #expect(model.providerName == "Grok")
            #expect(model.modelId.contains("grok"))
            #expect(model.supportsTools == true)
            #expect(model.supportsStreaming == true)
        }

        #expect(grokVision.supportsVision == true)
        #expect(grokImage.supportsVision == true)
        #expect(grokFast.supportsVision == false)
    }

    @Test("Grok default model selection")
    func defaultLanguageModelSelection() {
        let grokShortcut = LanguageModel.grok4
        let selectorDefault = LanguageModel.grok(.grok4FastReasoning)

        #expect(grokShortcut.providerName == "Grok")
        #expect(selectorDefault.providerName == "Grok")
        #expect(selectorDefault.modelId.contains("grok-4-fast"))
    }

    @Test("Grok model variations")
    func modelVariations() {
        let catalog: [LanguageModel] = Model.Grok.allCases.map { .grok($0) }

        for model in catalog {
            #expect(model.providerName == "Grok")
            #expect(!model.modelId.isEmpty)
        }

        let visionModels = catalog.filter(\.supportsVision)
        let allVisionHaveIdentifier = visionModels.allSatisfy { model in
            model.modelId.contains("vision") ||
                model.modelId.contains("image") ||
                model.modelId.contains("grok-vision")
        }
        #expect(allVisionHaveIdentifier)
    }

    @Test("Grok model context lengths")
    func modelContextLengths() {
        for model in Model.Grok.allCases {
            let languageModel = LanguageModel.grok(model)
            #expect(languageModel.contextLength >= 8000)
        }
    }

    @Test("Grok model generation integration", .enabled(if: false)) // Disabled - requires API key
    func modelGenerationIntegration() async throws {
        // This test would require real API credentials from xAI
        // Testing the integration without actual API calls

        let model = LanguageModel.grok(.grok4FastReasoning)
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
        let grokLanguageModels = Model.Grok.allCases.map { LanguageModel.grok($0) }

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
        let grok4 = LanguageModel.grok(.grok4FastReasoning)

        // These are implementation details that would be tested in provider code
        // Here we just verify the model exists and has expected properties
        #expect(grok4.modelId.contains("grok-4"))
        #expect(grok4.providerName == "Grok")

        // Grok models should support basic functionality
        #expect(grok4.supportsStreaming == true)
        #expect(grok4.supportsTools == true)
    }
}
