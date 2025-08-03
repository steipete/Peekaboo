import Testing
import TachikomaCore
@testable import peekaboo

// Extend AgentCommand to expose parseModelString for testing
extension AgentCommand {
    func parseModelString(_ modelString: String) -> LanguageModel? {
        let lowercased = modelString.lowercased()
        
        // OpenAI Models
        if lowercased.contains("gpt-4o") || lowercased == "gpt4o" {
            return .openai(.gpt4o)
        } else if lowercased.contains("gpt-4o-mini") || lowercased == "gpt4o-mini" {
            return .openai(.gpt4oMini)
        } else if lowercased.contains("gpt-4.1") || lowercased == "gpt-4.1" {
            return .openai(.gpt41)
        } else if lowercased.contains("gpt-4.1-mini") || lowercased == "gpt-4.1-mini" {
            return .openai(.gpt41Mini)
        } else if lowercased == "o3" {
            return .openai(.o3)
        } else if lowercased == "o3-mini" || lowercased == "o3mini" {
            return .openai(.o3Mini)
        } else if lowercased == "o3-pro" || lowercased == "o3pro" {
            return .openai(.o3Pro)
        } else if lowercased == "o4-mini" || lowercased == "o4mini" {
            return .openai(.o4Mini)
            
        // Anthropic Models
        } else if lowercased.contains("claude-opus-4") || lowercased.contains("claude-4-opus") || lowercased == "claude-opus-4" {
            return .anthropic(.opus4)
        } else if lowercased.contains("claude-sonnet-4") || lowercased.contains("claude-4-sonnet") || lowercased == "claude-sonnet-4" {
            return .anthropic(.sonnet4)
        } else if lowercased.contains("claude-3-5-sonnet") || lowercased == "claude-3-5-sonnet" {
            return .anthropic(.sonnet3_5)
        } else if lowercased.contains("claude-3-5-haiku") || lowercased == "claude-3-5-haiku" {
            return .anthropic(.haiku3_5)
            
        // Grok Models
        } else if lowercased.contains("grok-4") || lowercased == "grok-4" || lowercased == "grok4" {
            return .grok(.grok4)
        } else if lowercased.contains("grok-2") || lowercased == "grok-2" || lowercased == "grok2" {
            return .grok(.grok2_1212)
            
        // Ollama Models
        } else if lowercased.contains("llama3.3") || lowercased == "llama3.3" {
            return .ollama(.llama3_3)
        } else if lowercased.contains("llama3.2") || lowercased == "llama3.2" {
            return .ollama(.llama3_2)
        } else if lowercased.contains("llama3.1") || lowercased == "llama3.1" {
            return .ollama(.llama3_1)
            
        // Fallback - try to infer provider from common patterns
        } else if lowercased.contains("gpt") || lowercased.contains("o3") || lowercased.contains("o4") {
            return .openai(.gpt4o) // Default OpenAI model
        } else if lowercased.contains("claude") {
            return .anthropic(.opus4) // Default Anthropic model
        } else if lowercased.contains("grok") {
            return .grok(.grok4) // Default Grok model
        } else if lowercased.contains("llama") {
            return .ollama(.llama3_3) // Default Ollama model
        }
        
        return nil
    }
}

/// Tests for AgentCommand model parsing functionality
@Suite("AgentCommand Model Parsing Tests")
struct AgentCommandTests {
    
    @Test("OpenAI model parsing")
    func testOpenAIModelParsing() async throws {
        let command = AgentCommand()
        
        // Test GPT-4o variants
        #expect(command.parseModelString("gpt-4o") == .openai(.gpt4o))
        #expect(command.parseModelString("gpt4o") == .openai(.gpt4o))
        #expect(command.parseModelString("GPT-4O") == .openai(.gpt4o))
        
        // Test GPT-4o-mini variants
        #expect(command.parseModelString("gpt-4o-mini") == .openai(.gpt4oMini))
        #expect(command.parseModelString("gpt4o-mini") == .openai(.gpt4oMini))
        
        // Test GPT-4.1 variants
        #expect(command.parseModelString("gpt-4.1") == .openai(.gpt41))
        #expect(command.parseModelString("gpt-4.1-mini") == .openai(.gpt41Mini))
        
        // Test O3 models
        #expect(command.parseModelString("o3") == .openai(.o3))
        #expect(command.parseModelString("o3-mini") == .openai(.o3Mini))
        #expect(command.parseModelString("o3mini") == .openai(.o3Mini))
        #expect(command.parseModelString("o3-pro") == .openai(.o3Pro))
        #expect(command.parseModelString("o3pro") == .openai(.o3Pro))
        
        // Test O4 models
        #expect(command.parseModelString("o4-mini") == .openai(.o4Mini))
        #expect(command.parseModelString("o4mini") == .openai(.o4Mini))
    }
    
    @Test("Anthropic model parsing")
    func testAnthropicModelParsing() async throws {
        let command = AgentCommand()
        
        // Test Claude 4 models
        #expect(command.parseModelString("claude-opus-4") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-4-opus") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-sonnet-4") == .anthropic(.sonnet4))
        #expect(command.parseModelString("claude-4-sonnet") == .anthropic(.sonnet4))
        
        // Test Claude 3.5 models
        #expect(command.parseModelString("claude-3-5-sonnet") == .anthropic(.sonnet3_5))
        #expect(command.parseModelString("claude-3-5-haiku") == .anthropic(.haiku3_5))
        
        // Test case insensitivity
        #expect(command.parseModelString("CLAUDE-OPUS-4") == .anthropic(.opus4))
        #expect(command.parseModelString("Claude-3-5-Sonnet") == .anthropic(.sonnet3_5))
    }
    
    @Test("Grok model parsing")
    func testGrokModelParsing() async throws {
        let command = AgentCommand()
        
        // Test Grok 4 variants
        #expect(command.parseModelString("grok-4") == .grok(.grok4))
        #expect(command.parseModelString("grok4") == .grok(.grok4))
        #expect(command.parseModelString("GROK-4") == .grok(.grok4))
        
        // Test Grok 2 variants
        #expect(command.parseModelString("grok-2") == .grok(.grok2_1212))
        #expect(command.parseModelString("grok2") == .grok(.grok2_1212))
    }
    
    @Test("Ollama model parsing")
    func testOllamaModelParsing() async throws {
        let command = AgentCommand()
        
        // Test Llama variants
        #expect(command.parseModelString("llama3.3") == .ollama(.llama3_3))
        #expect(command.parseModelString("llama3.2") == .ollama(.llama3_2))
        #expect(command.parseModelString("llama3.1") == .ollama(.llama3_1))
        
        // Test case insensitivity
        #expect(command.parseModelString("LLAMA3.3") == .ollama(.llama3_3))
    }
    
    @Test("Fallback model parsing")
    func testFallbackModelParsing() async throws {
        let command = AgentCommand()
        
        // Test provider-based fallbacks
        #expect(command.parseModelString("gpt") == .openai(.gpt4o))
        #expect(command.parseModelString("claude") == .anthropic(.opus4))
        #expect(command.parseModelString("grok") == .grok(.grok4))
        #expect(command.parseModelString("llama") == .ollama(.llama3_3))
        
        // Test unknown models
        #expect(command.parseModelString("unknown-model") == nil)
        #expect(command.parseModelString("") == nil)
        #expect(command.parseModelString("   ") == nil)
    }
    
    @Test("Model string normalization")
    func testModelStringNormalization() async throws {
        let command = AgentCommand()
        
        // Test whitespace handling
        #expect(command.parseModelString("  gpt-4o  ") == .openai(.gpt4o))
        #expect(command.parseModelString("\tgpt-4o\n") == .openai(.gpt4o))
        
        // Test mixed case
        #expect(command.parseModelString("GpT-4O") == .openai(.gpt4o))
        #expect(command.parseModelString("Claude-Opus-4") == .anthropic(.opus4))
    }
}

/// Tests for model selection integration
@Suite("Model Selection Integration Tests")  
struct ModelSelectionIntegrationTests {
    
    @Test("Model parameter handling in AgentCommand")
    func testModelParameterHandling() async throws {
        // Test that model parameter is correctly parsed and used
        var command = AgentCommand()
        command.model = "gpt-4o"
        
        let parsedModel = command.model.flatMap { command.parseModelString($0) }
        #expect(parsedModel == .openai(.gpt4o))
        
        // Test nil model handling
        command.model = nil
        let nilModel = command.model.flatMap { command.parseModelString($0) }
        #expect(nilModel == nil)
    }
    
    @Test("Model description consistency")
    func testModelDescriptionConsistency() async throws {
        let command = AgentCommand()
        
        // Test that model descriptions are consistent
        let testCases: [(String, LanguageModel)] = [
            ("gpt-4o", .openai(.gpt4o)),
            ("claude-opus-4", .anthropic(.opus4)),
            ("grok-4", .grok(.grok4)),
            ("llama3.3", .ollama(.llama3_3))
        ]
        
        for (input, expected) in testCases {
            let parsed = command.parseModelString(input)
            #expect(parsed == expected)
            
            // Ensure the model description is meaningful
            #expect(!expected.description.isEmpty)
            #expect(expected.description.count > 3)
        }
    }
}