import Foundation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

struct GrokLanguageModelTests {
    @Test
    func `Grok model selection and properties`() {
        let grok43 = LanguageModel.grok(.grok43)
        let grokMultiAgent = LanguageModel.grok(.grok420MultiAgent)
        let grokReasoning = LanguageModel.grok(.grok420Reasoning)
        let grokNonReasoning = LanguageModel.grok(.grok420NonReasoning)

        for model in [grok43, grokMultiAgent, grokReasoning, grokNonReasoning] {
            #expect(model.providerName == "Grok")
            #expect(model.modelId.contains("grok"))
            #expect(model.supportsTools == true)
            #expect(model.supportsStreaming == true)
            #expect(model.supportsVision == false)
        }
    }

    @Test
    func `Grok default model selection`() {
        let grokShortcut = LanguageModel.grok4
        let selectorDefault = LanguageModel.grok(.grok43)

        #expect(grokShortcut.providerName == "Grok")
        #expect(selectorDefault.providerName == "Grok")
        #expect(selectorDefault.modelId == "grok-4.3")
    }

    @Test
    func `Grok model variations`() {
        let catalog: [LanguageModel] = Model.Grok.allCases.map { .grok($0) }

        for model in catalog {
            #expect(model.providerName == "Grok")
            #expect(!model.modelId.isEmpty)
        }

        #expect(catalog.allSatisfy { $0.supportsVision == false })
    }

    @Test
    func `Grok model context lengths`() {
        for model in Model.Grok.allCases {
            let languageModel = LanguageModel.grok(model)
            #expect(languageModel.contextLength >= 8000)
        }
    }

    @Test(.enabled(if: false)) // Disabled - requires API key
    func `Grok model generation integration`() async throws {
        // This test would require real API credentials from xAI
        // Testing the integration without actual API calls

        let model = LanguageModel.grok(.grok43)
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

    @Test
    func `Grok API compatibility`() {
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

    @Test
    func `Grok parameter filtering`() {
        // Test that Grok 4 models don't support certain OpenAI parameters
        let grok4 = LanguageModel.grok(.grok43)

        // These are implementation details that would be tested in provider code
        // Here we just verify the model exists and has expected properties
        #expect(grok4.modelId.contains("grok-4"))
        #expect(grok4.providerName == "Grok")

        // Grok models should support basic functionality
        #expect(grok4.supportsStreaming == true)
        #expect(grok4.supportsTools == true)
    }
}
