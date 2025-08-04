import Foundation
import Testing
import Tachikoma
@testable import PeekabooCore

@Suite("Anthropic Model Tests - Tachikoma Integration")
struct AnthropicModelTests {
    @Test("Anthropic model selection and properties")
    func modelSelectionAndProperties() {
        // Test current Anthropic models
        let opus4 = Model.anthropic(.opus4)
        let sonnet4 = Model.anthropic(.sonnet4)
        let haiku35 = Model.anthropic(.haiku35)
        
        #expect(opus4.providerName == "Anthropic")
        #expect(sonnet4.providerName == "Anthropic")
        #expect(haiku35.providerName == "Anthropic")
        
        // Test model capabilities
        #expect(opus4.supportsVision == true)
        #expect(opus4.supportsTools == true)
        #expect(opus4.supportsStreaming == true)
        #expect(opus4.contextLength > 100_000) // All Claude models have large context
        
        // Test model IDs
        #expect(opus4.modelId.contains("opus"))
        #expect(sonnet4.modelId.contains("sonnet"))
        #expect(haiku35.modelId.contains("haiku"))
    }
    
    @Test("Anthropic default model selection")
    func defaultModelSelection() {
        // Test that Claude Opus 4 is the default
        let defaultModel = Model.default
        let claudeModel = Model.claude
        
        #expect(defaultModel.providerName == "Anthropic")
        #expect(claudeModel.providerName == "Anthropic")
        
        // Test model shortcuts
        let anthropicModels = [
            Model.anthropic(.opus4),
            Model.anthropic(.sonnet4),
            Model.anthropic(.haiku35)
        ]
        
        for model in anthropicModels {
            #expect(model.providerName == "Anthropic")
            #expect(!model.modelId.isEmpty)
        }
    }
    
    @Test("Anthropic model generation integration", .enabled(if: false)) // Disabled - requires API key
    func modelGenerationIntegration() async throws {
        // This test would require real API credentials
        // Testing the integration without actual API calls
        
        let model = Model.anthropic(.opus4)
        let messages = [
            ModelMessage.user("What is 2+2?")
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
            #expect(Bool(true)) // Should not reach here without API key
        } catch {
            // Expected to fail without API key - this is testing the structure
            #expect(error is TachikomaError)
        }
    }
    
    @Test("Anthropic vision model capabilities")
    func visionModelCapabilities() {
        let visionCapableModels = [
            Model.anthropic(.opus4),
            Model.anthropic(.sonnet4),
            Model.anthropic(.haiku35)
        ]
        
        for model in visionCapableModels {
            #expect(model.supportsVision == true)
        }
    }
    
    @Test("Anthropic model comparison")
    func modelComparison() {
        let opus4 = Model.anthropic(.opus4)
        let sonnet4 = Model.anthropic(.sonnet4)
        let haiku35 = Model.anthropic(.haiku35)
        
        // Test model descriptions
        #expect(opus4.description.contains("Anthropic"))
        #expect(sonnet4.description.contains("Anthropic"))
        #expect(haiku35.description.contains("Anthropic"))
        
        // Test that they're different models
        #expect(opus4.modelId != sonnet4.modelId)
        #expect(sonnet4.modelId != haiku35.modelId)
        #expect(opus4.modelId != haiku35.modelId)
        
        // Test model hierarchy (Opus > Sonnet > Haiku typically)
        #expect(opus4.contextLength >= sonnet4.contextLength)
        #expect(sonnet4.contextLength >= haiku35.contextLength)
    }
    
    @Test("Anthropic thinking models")
    func thinkingModels() {
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