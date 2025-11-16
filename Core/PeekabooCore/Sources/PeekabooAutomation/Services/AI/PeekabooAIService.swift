import Foundation
import Tachikoma

/// AI service for handling model interactions and AI-powered features
@MainActor
public final class PeekabooAIService {
    private let defaultModel: LanguageModel = .openai(.gpt51)

    public init() {
        // Rely on TachikomaConfiguration to load from env/credentials (profile set at startup)
    }

    public struct AnalysisResult: Sendable {
        public let provider: String
        public let model: String
        public let text: String
    }

    /// Analyze an image with a question using AI
    public func analyzeImage(imageData: Data, question: String, model: LanguageModel? = nil) async throws -> String {
        // Analyze an image with a question using AI
        let selectedModel = model ?? self.defaultModel

        // Create a message with the image using Tachikoma's API
        let base64String = imageData.base64EncodedString()
        let imageContent = ModelMessage.ContentPart.ImageContent(data: base64String, mimeType: "image/png")
        let messages = [
            ModelMessage.user(text: question, images: [imageContent]),
        ]

        // Generate response using Tachikoma's generateText function
        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages)

        return response.text
    }

    /// Analyze an image with a question returning structured metadata
    public func analyzeImageDetailed(
        imageData: Data,
        question: String,
        model: LanguageModel? = nil) async throws -> AnalysisResult
    {
        // Analyze an image with a question returning structured metadata
        let selectedModel = model ?? self.defaultModel

        // Create a message with the image using Tachikoma's API
        let base64String = imageData.base64EncodedString()
        let imageContent = ModelMessage.ContentPart.ImageContent(data: base64String, mimeType: "image/png")
        let messages = [ModelMessage.user(text: question, images: [imageContent])]

        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages)

        // Map provider/model from LanguageModel enum
        let (provider, modelName): (String, String) = switch selectedModel {
        case let .openai(m): ("openai", m.modelId)
        case let .anthropic(m): ("anthropic", m.modelId)
        case let .google(m): ("google", m.rawValue)
        case let .mistral(m): ("mistral", m.rawValue)
        case let .groq(m): ("groq", m.rawValue)
        case let .grok(m): ("grok", m.modelId)
        case let .ollama(m): ("ollama", m.modelId)
        case let .lmstudio(m): ("lmstudio", m.modelId)
        case let .azureOpenAI(deployment, _, _, _): ("azure-openai", deployment)
        case let .openRouter(modelId): ("openrouter", modelId)
        case let .together(modelId): ("together", modelId)
        case let .replicate(modelId): ("replicate", modelId)
        case let .openaiCompatible(modelId, _): ("openai-compatible", modelId)
        case let .anthropicCompatible(modelId, _): ("anthropic-compatible", modelId)
        case let .custom(provider): ("custom", provider.modelId)
        }

        return AnalysisResult(provider: provider, model: modelName, text: response.text)
    }

    /// Analyze an image file with a question
    public func analyzeImageFile(
        at path: String,
        question: String,
        model: LanguageModel? = nil) async throws -> String
    {
        // Load image data
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)

        return try await self.analyzeImage(imageData: imageData, question: question, model: model)
    }

    /// Analyze an image file returning structured metadata
    public func analyzeImageFileDetailed(
        at path: String,
        question: String,
        model: LanguageModel? = nil) async throws -> AnalysisResult
    {
        // Analyze an image file returning structured metadata
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)
        return try await self.analyzeImageDetailed(imageData: imageData, question: question, model: model)
    }

    /// Generate text from a prompt
    public func generateText(prompt: String, model: LanguageModel? = nil) async throws -> String {
        // Generate text from a prompt
        let selectedModel = model ?? self.defaultModel

        let messages = [
            ModelMessage.user(prompt),
        ]

        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages)

        return response.text
    }

    /// List available models
    public func availableModels() -> [LanguageModel] {
        // List available models
        [
            .openai(.gpt51),
            .anthropic(.sonnet45),
        ]
    }
}
