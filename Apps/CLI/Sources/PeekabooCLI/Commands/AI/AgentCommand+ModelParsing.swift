import Foundation
import PeekabooCore
import PeekabooFoundation
import Tachikoma

@available(macOS 14.0, *)
extension AgentCommand {
    func parseModelString(_ modelString: String) -> LanguageModel? {
        let trimmed = modelString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let parsed = LanguageModel.parse(from: trimmed) else {
            return nil
        }

        switch parsed {
        case let .openai(model):
            if Self.supportedOpenAIInputs.contains(model) {
                return .openai(.gpt51)
            }
        case let .anthropic(model):
            if Self.supportedAnthropicInputs.contains(model) {
                return .anthropic(.opus45)
            }
        case let .google(model):
            if Self.supportedGoogleInputs.contains(model) {
                return .google(.gemini3Flash)
            }
        default:
            break
        }

        return nil
    }

    func validatedModelSelection() throws -> LanguageModel? {
        guard let modelString = self.model else { return nil }
        guard let parsed = self.parseModelString(modelString) else {
            throw PeekabooError.invalidInput(
                "Unsupported model '\(modelString)'. Allowed values: \(Self.allowedModelList)"
            )
        }
        return parsed
    }

    private static let supportedOpenAIInputs: Set<LanguageModel.OpenAI> = [
        .gpt51,
        .gpt5,
        .gpt5Pro,
        .gpt5Mini,
        .gpt5Nano,
        .gpt5Thinking,
        .gpt5ThinkingMini,
        .gpt5ThinkingNano,
        .gpt5ChatLatest,
        .gpt4o,
        .gpt4oMini,
        .gpt4oRealtime,
        .o4Mini,
    ]

    private static let supportedAnthropicInputs: Set<LanguageModel.Anthropic> = [
        .sonnet45,
        .sonnet4,
        .sonnet4Thinking,
        .opus45,
        .opus4,
        .opus4Thinking,
    ]

    private static let supportedGoogleInputs: Set<LanguageModel.Google> = [
        .gemini3Flash,
    ]

    private static var allowedModelList: String {
        let openAIModels = Self.supportedOpenAIInputs.map(\.modelId)
        let anthropicModels = Self.supportedAnthropicInputs.map(\.modelId)
        let googleModels = Self.supportedGoogleInputs.map(\.userFacingModelId)
        return (openAIModels + anthropicModels + googleModels).sorted().joined(separator: ", ")
    }

    @MainActor
    func hasCredentials(for model: LanguageModel) -> Bool {
        let configuration = self.services.configuration
        switch model {
        case .openai:
            return configuration.getOpenAIAPIKey()?.isEmpty == false
        case .anthropic:
            return configuration.getAnthropicAPIKey()?.isEmpty == false
        case .google:
            return configuration.getGeminiAPIKey()?.isEmpty == false
        default:
            return false
        }
    }

    func providerDisplayName(for model: LanguageModel) -> String {
        switch model {
        case .openai:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .google:
            "Google"
        default:
            "the selected provider"
        }
    }

    func providerEnvironmentVariable(for model: LanguageModel) -> String {
        switch model {
        case .openai:
            "OPENAI_API_KEY"
        case .anthropic:
            "ANTHROPIC_API_KEY"
        case .google:
            "GEMINI_API_KEY"
        default:
            "provider API key"
        }
    }
}
