import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite("AIProviderParser Tests")
struct AIProviderParserTests {
    @Test("Parse single provider")
    func parseSingleProvider() {
        #expect(AIProviderParser.parse("openai/gpt-4") == AIProviderParser.ProviderConfig(
            provider: "openai",
            model: "gpt-4"))
        #expect(AIProviderParser.parse("anthropic/claude-3") == AIProviderParser.ProviderConfig(
            provider: "anthropic",
            model: "claude-3"))
        #expect(AIProviderParser.parse("ollama/llava:latest") == AIProviderParser.ProviderConfig(
            provider: "ollama",
            model: "llava:latest"))
    }

    @Test("Parse with whitespace")
    func parseWithWhitespace() {
        #expect(AIProviderParser.parse("  openai/gpt-4  ") == AIProviderParser.ProviderConfig(
            provider: "openai",
            model: "gpt-4"))
        #expect(AIProviderParser.parse("\tanthropic/claude-3\n") == AIProviderParser.ProviderConfig(
            provider: "anthropic",
            model: "claude-3"))
    }

    @Test("Parse invalid formats")
    func parseInvalidFormats() {
        #expect(AIProviderParser.parse("openai") == nil)
        #expect(AIProviderParser.parse("/gpt-4") == nil)
        #expect(AIProviderParser.parse("openai/") == nil)
        #expect(AIProviderParser.parse("") == nil)
        #expect(AIProviderParser.parse("no-slash-here") == nil)
    }

    @Test("Parse provider list")
    func parseProviderList() {
        let providers = AIProviderParser.parseList("openai/gpt-4,anthropic/claude-3,ollama/llava:latest")
        #expect(providers.count == 3)
        #expect(providers[0] == AIProviderParser.ProviderConfig(provider: "openai", model: "gpt-4"))
        #expect(providers[1] == AIProviderParser.ProviderConfig(provider: "anthropic", model: "claude-3"))
        #expect(providers[2] == AIProviderParser.ProviderConfig(provider: "ollama", model: "llava:latest"))
    }

    @Test("Parse list with invalid entries")
    func parseListWithInvalidEntries() {
        let providers = AIProviderParser.parseList("openai/gpt-4,invalid,anthropic/claude-3,/bad,ollama/")
        #expect(providers.count == 2)
        #expect(providers[0] == AIProviderParser.ProviderConfig(provider: "openai", model: "gpt-4"))
        #expect(providers[1] == AIProviderParser.ProviderConfig(provider: "anthropic", model: "claude-3"))
    }

    @Test("Parse first provider")
    func parseFirstProvider() {
        #expect(AIProviderParser.parseFirst("openai/gpt-4,anthropic/claude-3")?.provider == "openai")
        #expect(AIProviderParser.parseFirst("invalid,anthropic/claude-3")?.provider == "anthropic")
        #expect(AIProviderParser.parseFirst("invalid,bad,") == nil)
    }

    @Test("Determine default model with all providers")
    func determineDefaultModelAllProviders() {
        // When all providers are available, should use first one
        let model = AIProviderParser.determineDefaultModel(
            from: "ollama/llava:latest,openai/gpt-4,anthropic/claude-3",
            hasOpenAI: true,
            hasAnthropic: true,
            hasOllama: false)
        #expect(model == "gpt-5")
    }

    @Test("Determine default model with limited providers")
    func determineDefaultModelLimitedProviders() {
        // When only some providers are available
        let model1 = AIProviderParser.determineDefaultModel(
            from: "openai/gpt-4,ollama/llava:latest,anthropic/claude-3",
            hasOpenAI: false,
            hasAnthropic: true,
            hasOllama: false)
        #expect(model1 == "claude-sonnet-4.5")

        let model2 = AIProviderParser.determineDefaultModel(
            from: "openai/gpt-4,anthropic/claude-sonnet-4.5,ollama/llava:latest",
            hasOpenAI: false,
            hasAnthropic: true,
            hasOllama: false)
        #expect(model2 == "claude-sonnet-4.5")
    }

    @Test("Determine default model with configured default")
    func determineDefaultModelWithConfigured() {
        let model = AIProviderParser.determineDefaultModel(
            from: "openai/gpt-4,anthropic/claude-3",
            hasOpenAI: true,
            hasAnthropic: true,
            configuredDefault: "my-custom-model")
        #expect(model == "my-custom-model")
    }

    @Test("Determine default model fallback")
    func determineDefaultModelFallback() {
        // When no providers match, fall back to defaults
        let model1 = AIProviderParser.determineDefaultModel(
            from: "invalid/model",
            hasOpenAI: false,
            hasAnthropic: true)
        #expect(model1 == "claude-sonnet-4.5")

        let model2 = AIProviderParser.determineDefaultModel(
            from: "",
            hasOpenAI: true,
            hasAnthropic: false)
        #expect(model2 == "gpt-5")

        let model3 = AIProviderParser.determineDefaultModel(
            from: "",
            hasOpenAI: false,
            hasAnthropic: false)
        #expect(model3 == "gpt-5")
    }

    @Test("Extract provider and model")
    func extractProviderAndModel() {
        #expect(AIProviderParser.extractProvider(from: "openai/gpt-4") == "openai")
        #expect(AIProviderParser.extractModel(from: "openai/gpt-4") == "gpt-4")
        #expect(AIProviderParser.extractProvider(from: "invalid") == nil)
        #expect(AIProviderParser.extractModel(from: "invalid") == nil)
    }
}
