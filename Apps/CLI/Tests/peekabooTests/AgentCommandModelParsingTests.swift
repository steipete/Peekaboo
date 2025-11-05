import Tachikoma
import Testing
@testable import peekaboo

@Suite("AgentCommand Model Parsing Tests")
struct AgentCommandTests {
    @Test("OpenAI model parsing")
    func openAIModelParsing() async throws {
        let command = AgentCommand()

        // GPT-5 family
        #expect(command.parseModelString("gpt-5") == .openai(.gpt5))
        #expect(command.parseModelString("gpt-5-mini") == .openai(.gpt5Mini))
        #expect(command.parseModelString("gpt-5-nano") == .openai(.gpt5Nano))
        #expect(command.parseModelString("gpt-5-pro") == .openai(.gpt5Pro))
        #expect(command.parseModelString("gpt-5-thinking") == .openai(.gpt5Thinking))
        #expect(command.parseModelString("gpt-5-thinking-mini") == .openai(.gpt5ThinkingMini))
        #expect(command.parseModelString("gpt-5-thinking-nano") == .openai(.gpt5ThinkingNano))
        #expect(command.parseModelString("gpt-5-chat-latest") == .openai(.gpt5ChatLatest))

        // GPT-4o family
        #expect(command.parseModelString("gpt-4o") == .openai(.gpt4o))
        #expect(command.parseModelString("gpt4o") == .openai(.gpt4o))
        #expect(command.parseModelString("gpt-4o-mini") == .openai(.gpt4oMini))
        #expect(command.parseModelString("gpt-4o-realtime") == .openai(.gpt4oRealtime))

        // GPT-4.1 family
        #expect(command.parseModelString("gpt-4.1") == .openai(.gpt41))
        #expect(command.parseModelString("gpt-4.1-mini") == .openai(.gpt41Mini))

        // Reasoning models
        #expect(command.parseModelString("o3") == .openai(.o3))
        #expect(command.parseModelString("o3-mini") == .openai(.o3Mini))
        #expect(command.parseModelString("o3-pro") == .openai(.o3Pro))
        #expect(command.parseModelString("o4-mini") == .openai(.o4Mini))
    }

    @Test("Anthropic model parsing")
    func anthropicModelParsing() async throws {
        let command = AgentCommand()

        // Claude 4 series
        #expect(command.parseModelString("claude-opus-4") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-opus-4-1-20250805") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-opus-4-1-20250805-thinking") == .anthropic(.opus4Thinking))
        #expect(command.parseModelString("claude-sonnet-4") == .anthropic(.sonnet4))
        #expect(command.parseModelString("claude-sonnet-4-20250514-thinking") == .anthropic(.sonnet4Thinking))
        #expect(command.parseModelString("claude-sonnet-4.5") == .anthropic(.sonnet45))

        // Claude 3.7 / 3.5 series
        #expect(command.parseModelString("claude-3-7-sonnet") == .anthropic(.sonnet37))
        #expect(command.parseModelString("claude-3-5-sonnet") == .anthropic(.sonnet35))
        #expect(command.parseModelString("claude-3-5-haiku") == .anthropic(.haiku35))
        #expect(command.parseModelString("claude-haiku-4.5") == .anthropic(.haiku45))

        // Legacy Claude 3 series
        #expect(command.parseModelString("claude-3-opus") == .anthropic(.opus3))
        #expect(command.parseModelString("claude-3-sonnet") == .anthropic(.sonnet3))
        #expect(command.parseModelString("claude-3-haiku") == .anthropic(.haiku3))

        // Case insensitivity
        #expect(command.parseModelString("CLAUDE-OPUS-4") == .anthropic(.opus4))
    }

    @Test("Grok model parsing")
    func grokModelParsing() async throws {
        let command = AgentCommand()

        #expect(command.parseModelString("grok-4") == .grok(.grok4))
        #expect(command.parseModelString("grok4") == .grok(.grok4))
        #expect(command.parseModelString("grok-3") == .grok(.grok3))
        #expect(command.parseModelString("grok-3-mini") == .grok(.grok3Mini))
        #expect(command.parseModelString("grok-2-image-1212") == .grok(.grok2Image))
        #expect(command.parseModelString("grok-2") == .grok(.grok2Image))
    }

    @Test("Ollama model parsing")
    func ollamaModelParsing() async throws {
        let command = AgentCommand()

        #expect(command.parseModelString("llama3.3") == .ollama(.llama33))
        #expect(command.parseModelString("llama3.2") == .ollama(.llama32))
        #expect(command.parseModelString("llama3.1") == .ollama(.llama31))
        #expect(command.parseModelString("LLAMA3.3") == .ollama(.llama33))
    }

    @Test("Fallback model parsing")
    func fallbackModelParsing() async throws {
        let command = AgentCommand()

        #expect(command.parseModelString("gpt") == .openai(.gpt5Mini))
        #expect(command.parseModelString("claude") == .anthropic(.opus4))
        #expect(command.parseModelString("grok") == .grok(.grok4))
        #expect(command.parseModelString("llama") == .ollama(.llama33))

        #expect(command.parseModelString("unknown-model") == nil)
        #expect(command.parseModelString("") == nil)
        #expect(command.parseModelString("   ") == nil)
    }

    @Test("Model string normalization")
    func modelStringNormalization() async throws {
        let command = AgentCommand()

        #expect(command.parseModelString("  gpt-4o  ") == .openai(.gpt4o))
        #expect(command.parseModelString("\tgpt-4o\n") == .openai(.gpt4o))
        #expect(command.parseModelString("GpT-4O") == .openai(.gpt4o))
        #expect(command.parseModelString("Claude-Opus-4") == .anthropic(.opus4))
    }
}

/// Tests for model selection integration
@Suite("Model Selection Integration Tests")
struct ModelSelectionIntegrationTests {
    @Test("Model parameter handling in AgentCommand")
    func modelParameterHandling() async throws {
        var command = AgentCommand()
        command.model = "gpt-4o"

        let parsedModel = command.model.flatMap { command.parseModelString($0) }
        #expect(parsedModel == .openai(.gpt4o))

        command.model = nil
        let nilModel = command.model.flatMap { command.parseModelString($0) }
        #expect(nilModel == nil)
    }

    @Test("Model description consistency")
    func modelDescriptionConsistency() async throws {
        let command = AgentCommand()

        let testCases: [(String, LanguageModel)] = [
            ("gpt-5", .openai(.gpt5)),
            ("gpt-4o", .openai(.gpt4o)),
            ("claude-opus-4", .anthropic(.opus4)),
            ("grok-4", .grok(.grok4)),
        ]

        for (input, expected) in testCases {
            let parsed = command.parseModelString(input)
            #expect(parsed == expected)
            #expect(!expected.description.isEmpty)
        }
    }
}
