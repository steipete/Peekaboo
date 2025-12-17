import PeekabooFoundation
import Tachikoma
import Testing
@testable import PeekabooCLI

@Suite("AgentCommand Model Parsing Tests", .tags(.safe))
struct AgentCommandTests {
    @Test("Supported OpenAI aliases map to GPT-5.1")
    func openAIModelParsing() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("gpt-5.1") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-5.1-mini") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-5.1-nano") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-5") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-5-mini") == .openai(.gpt51))
        #expect(command.parseModelString("gpt") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-5-nano") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-4o") == .openai(.gpt51))
        #expect(command.parseModelString("gpt-4o-mini") == .openai(.gpt51))
    }

    @Test("Supported Anthropic aliases map to Claude Opus 4.x")
    func anthropicModelParsing() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("claude-sonnet-4.5") == .anthropic(.opus4))
        #expect(command.parseModelString("Claude-Sonnet-4.5") == .anthropic(.opus4))
        #expect(command.parseModelString("claude") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-opus-4") == .anthropic(.opus4))
        #expect(command.parseModelString("claude-3-sonnet") == nil)
    }

    @Test("Unsupported providers are rejected")
    func unsupportedModelsReturnNil() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("grok-4") == nil)
        #expect(command.parseModelString("llama3.3") == nil)
        #expect(command.parseModelString("ollama/llava") == nil)
    }

    @Test("Model string normalization trims whitespace")
    func modelStringNormalization() async throws {
        let command = try AgentCommand.parse([])

        #expect(command.parseModelString("  gpt-5  ") == .openai(.gpt51))
        #expect(command.parseModelString("\tgpt-5\n") == .openai(.gpt51))
        #expect(command.parseModelString(" claude-sonnet-4.5 ") == .anthropic(.opus4))
    }
}

/// Tests for model selection integration
@Suite("Model Selection Integration Tests", .tags(.safe))
struct ModelSelectionIntegrationTests {
    @Test("Model parameter handling in AgentCommand")
    func modelParameterHandling() async throws {
        var command = try AgentCommand.parse([])
        command.model = "gpt-5"

        let parsedModel = command.model.flatMap { command.parseModelString($0) }
        #expect(parsedModel == .openai(.gpt51))

        command.model = "claude-sonnet-4.5"
        let parsedClaude = command.model.flatMap { command.parseModelString($0) }
        #expect(parsedClaude == .anthropic(.opus4))

        command.model = "gpt-4o"
        let remapped = command.model.flatMap { command.parseModelString($0) }
        #expect(remapped == .openai(.gpt51))
    }

    @Test("Model description consistency")
    func modelDescriptionConsistency() async throws {
        let command = try AgentCommand.parse([])

        let testCases: [(String, LanguageModel)] = [
            ("gpt-5.1", .openai(.gpt51)),
            ("claude-sonnet-4.5", .anthropic(.opus4)),
        ]

        for (input, expected) in testCases {
            let parsed = command.parseModelString(input)
            #expect(parsed == expected)
            #expect(!expected.description.isEmpty)
        }
    }

    @Test("Validated model selection handles optional input")
    func validatedModelSelectionOptional() async throws {
        var command = try AgentCommand.parse([])
        #expect(try command.validatedModelSelection() == nil)

        command.model = "gpt-5.1"
        let parsed = try command.validatedModelSelection()
        #expect(parsed == .openai(.gpt51))
    }

    @Test("Invalid model option surfaces user-friendly error")
    func invalidModelSelectionThrows() async throws {
        var command = try AgentCommand.parse([])
        command.model = "llama-3.2"

        let error = #expect(throws: PeekabooError.self) {
            try command.validatedModelSelection()
        }

        if case let .invalidInput(message) = error {
            #expect(message.contains("Unsupported model"))
        } else {
            Issue.record("Expected invalidInput error")
        }
    }
}
