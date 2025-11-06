import Tachikoma
import Testing
@testable import PeekabooCLI

@Suite("AgentCommand Model Parsing Tests", .tags(.safe))
struct AgentCommandTests {
    @Test
    func `OpenAI model parsing`() async throws {
        let command = try AgentCommand.parse([])

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

        // Reasoning models
        #expect(command.parseModelString("o3") == .openai(.gpt5Mini))
        #expect(command.parseModelString("o3-mini") == .openai(.gpt5Mini))
        #expect(command.parseModelString("o3-pro") == .openai(.gpt5Mini))
        #expect(command.parseModelString("o4-mini") == .openai(.o4Mini))
    }

    @Test
    func `Anthropic model parsing`() async throws {
        let command = try AgentCommand.parse([])

        // Claude 4 series
        #expect(command.parseModelString("claude-opus-4") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-opus-4-1-20250805") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-opus-4-1-20250805-thinking") == .anthropic(.opus4Thinking))
        #expect(command.parseModelString("claude-sonnet-4") == .anthropic(.sonnet4))
        #expect(command.parseModelString("claude-sonnet-4-20250514-thinking") == .anthropic(.sonnet4Thinking))
        #expect(command.parseModelString("claude-sonnet-4.5") == .anthropic(.sonnet45))

        // Claude 3.7 / 3.5 series
        #expect(command.parseModelString("claude-3-7-sonnet") == .anthropic(.custom("claude-3-7-sonnet")))
        #expect(command.parseModelString("claude-3-5-sonnet") == .anthropic(.custom("claude-3-5-sonnet")))
        #expect(command.parseModelString("claude-3-5-haiku") == .anthropic(.custom("claude-3-5-haiku")))
        #expect(command.parseModelString("claude-haiku-4.5") == .anthropic(.haiku45))

        // Legacy Claude 3 series
        #expect(command.parseModelString("claude-3-opus") == .anthropic(.custom("claude-3-opus")))
        #expect(command.parseModelString("claude-3-sonnet") == .anthropic(.custom("claude-3-sonnet")))
        #expect(command.parseModelString("claude-3-haiku") == .anthropic(.custom("claude-3-haiku")))

        // Case insensitivity
        #expect(command.parseModelString("CLAUDE-OPUS-4") == .anthropic(.opus4))
    }

    @Test
    func `Grok model parsing`() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("grok-4") == .grok(.grok4))
        #expect(command.parseModelString("grok4") == .grok(.grok4))
        #expect(command.parseModelString("grok-3") == .grok(.grok3))
        #expect(command.parseModelString("grok-3-mini") == .grok(.grok3Mini))
        #expect(command.parseModelString("grok-2-image-1212") == .grok(.grok2Image))
        #expect(command.parseModelString("grok-2") == .grok(.grok2Image))
    }

    @Test
    func `Ollama model parsing`() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("llama3.3") == .ollama(.llama33))
        #expect(command.parseModelString("llama3.2") == .ollama(.llama32))
        #expect(command.parseModelString("llama3.1") == .ollama(.llama31))
        #expect(command.parseModelString("LLAMA3.3") == .ollama(.llama33))
    }

    @Test
    func `Fallback model parsing`() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("gpt") == .openai(.gpt5Mini))
        #expect(command.parseModelString("claude") == .anthropic(.sonnet45))
        #expect(command.parseModelString("grok") == .grok(.grok4))
        #expect(command.parseModelString("llama") == .ollama(.llama33))

        #expect(command.parseModelString("unknown-model") == nil)
        #expect(command.parseModelString("") == nil)
        #expect(command.parseModelString("   ") == nil)
    }

    @Test
    func `Model string normalization`() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("  gpt-4o  ") == .openai(.gpt4o))
        #expect(command.parseModelString("\tgpt-4o\n") == .openai(.gpt4o))
        #expect(command.parseModelString("GpT-4O") == .openai(.gpt4o))
        #expect(command.parseModelString("Claude-Sonnet-4.5") == .anthropic(.sonnet45))
    }
}

/// Tests for model selection integration
@Suite("Model Selection Integration Tests", .tags(.safe))
struct ModelSelectionIntegrationTests {
    @Test
    func `Model parameter handling in AgentCommand`() async throws {
        var command = try AgentCommand.parse([])
        command.model = "gpt-4o"

        let parsedModel = command.model.flatMap { command.parseModelString($0) }
        #expect(parsedModel == .openai(.gpt4o))

        command.model = nil
        let nilModel = command.model.flatMap { command.parseModelString($0) }
        #expect(nilModel == nil)
    }

    @Test
    func `Model description consistency`() async throws {
        let command = try AgentCommand.parse([])

        let testCases: [(String, LanguageModel)] = [
            ("gpt-5", .openai(.gpt5)),
            ("gpt-4o", .openai(.gpt4o)),
            ("claude-sonnet-4.5", .anthropic(.sonnet45)),
            ("grok-4", .grok(.grok4)),
        ]

        for (input, expected) in testCases {
            let parsed = command.parseModelString(input)
            #expect(parsed == expected)
            #expect(!expected.description.isEmpty)
        }
    }
}
