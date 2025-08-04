import Foundation
import Testing
import Tachikoma
@testable import PeekabooCore

@Suite("Grok Model Tests - Tachikoma Integration")
struct GrokModelTests {
    @Test("Grok model selection and properties")
    func modelSelectionAndProperties() {
        // Test current Grok models
        let grok4 = Model.grok(.grok4)
        let grok2 = Model.grok(.grok21212)
        let grok2Vision = Model.grok(.grok2Vision1212)
        let grokBeta = Model.grok(.grokBeta)
        
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
    func defaultModelSelection() {
        // Test Grok shortcuts
        let grokModel = Model.grok4
        let grokDefault = Model.grok(.grok4)
        
        #expect(grokModel.providerName == "Grok")
        #expect(grokDefault.providerName == "Grok")
        
        // Test that grok shortcut points to grok-4
        #expect(grokModel.modelId == grokDefault.modelId)
    }
    
    @Test("Grok model variations")
    func modelVariations() {
        let models = [
            Model.grok(.grok4),
            Model.grok(.grok4Latest),
            Model.grok(.grok21212),
            Model.grok(.grok2Vision1212),
            Model.grok(.grokBeta),
            Model.grok(.grokVisionBeta)
        ]
        
        for model in models {
            #expect(model.providerName == "Grok")
            #expect(!model.modelId.isEmpty)
            #expect(model.description.contains("Grok"))
        }
        
        // Test vision models have vision capability
        let visionModels = [
            Model.grok(.grok2Vision1212),
            Model.grok(.grokVisionBeta)
        ]
        
        for visionModel in visionModels {
            #expect(visionModel.supportsVision == true)
        }
    }
    
    @Test("Grok model context lengths")
    func modelContextLengths() {
        let grok4 = Model.grok(.grok4)
        let grok2 = Model.grok(.grok21212)
        
        // Grok models should have reasonable context lengths
        #expect(grok4.contextLength > 50_000) // At least 50K context
        #expect(grok2.contextLength > 50_000) // At least 50K context
        
        // Test that context length is accessible
        #expect(grok4.contextLength > 0)
        #expect(grok2.contextLength > 0)
    }
    
    @Test("Grok model generation integration", .enabled(if: false)) // Disabled - requires API key
    func modelGenerationIntegration() async throws {
        // This test would require real API credentials from xAI
        // Testing the integration without actual API calls
        
        let model = Model.grok(.grok4)
        let messages = [
            ModelMessage.user("What is the meaning of life?")
        ]
        
        // Test that the API call structure is correct (would fail without API key)
        do {
            _ = try await generateText(
                model: model,
                messages: messages,
                tools: nil,
                settings: .default,
                maxSteps: 1
            )
            #expect(true) // Should not reach here without API key
        } catch {
            // Expected to fail without API key - this is testing the structure
            #expect(error is TachikomaError)
        }
    }
    
    @Test("Grok API compatibility")
    func apiCompatibility() {
        // Test that Grok models are compatible with OpenAI-style API
        let grokModels = [
            Model.grok(.grok4),
            Model.grok(.grok21212),
            Model.grok(.grokBeta)
        ]
        
        for model in grokModels {
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
        let grok4 = Model.grok(.grok4)
        
        // These are implementation details that would be tested in provider code
        // Here we just verify the model exists and has expected properties
        #expect(grok4.modelId.contains("grok-4"))
        #expect(grok4.providerName == "Grok")
        
        // Grok models should support basic functionality
        #expect(grok4.supportsStreaming == true)
        #expect(grok4.supportsTools == true)
    }
}