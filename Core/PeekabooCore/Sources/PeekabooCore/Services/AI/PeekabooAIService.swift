import Foundation
import Tachikoma

/// AI service for handling model interactions and AI-powered features
@MainActor
public final class PeekabooAIService {
    private let defaultModel: LanguageModel = .openai(.gpt5)
    
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
        let selectedModel = model ?? defaultModel
        
        // Create a message with the image using Tachikoma's API
        let base64String = imageData.base64EncodedString()
        let imageContent = ModelMessage.ContentPart.ImageContent(data: base64String, mimeType: "image/png")
        let messages = [
            ModelMessage.user(text: question, images: [imageContent])
        ]
        
        // Generate response using Tachikoma's generateText function
        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages
        )
        
        return response.text
    }

    /// Analyze an image with a question returning structured metadata
    public func analyzeImageDetailed(imageData: Data, question: String, model: LanguageModel? = nil) async throws -> AnalysisResult {
        let selectedModel = model ?? defaultModel

        // Create a message with the image using Tachikoma's API
        let base64String = imageData.base64EncodedString()
        let imageContent = ModelMessage.ContentPart.ImageContent(data: base64String, mimeType: "image/png")
        let messages = [ ModelMessage.user(text: question, images: [imageContent]) ]

        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages
        )

        // Map provider/model from LanguageModel enum
        let (provider, modelName): (String, String) = {
            switch selectedModel {
            case .openai(let m): return ("openai", m.modelId)
            case .anthropic(let m): return ("anthropic", m.modelId)
            case .google(let m): return ("google", m.rawValue)
            case .mistral(let m): return ("mistral", m.rawValue)
            case .groq(let m): return ("groq", m.rawValue)
            case .grok(let m): return ("grok", m.modelId)
            case .ollama(let m): return ("ollama", m.modelId)
            case .lmstudio(let m): return ("lmstudio", m.modelId)
            case .openRouter(let modelId): return ("openrouter", modelId)
            case .together(let modelId): return ("together", modelId)
            case .replicate(let modelId): return ("replicate", modelId)
            case .openaiCompatible(let modelId, _): return ("openai-compatible", modelId)
            case .anthropicCompatible(let modelId, _): return ("anthropic-compatible", modelId)
            case .custom(let provider): return ("custom", provider.modelId)
            }
        }()

        return AnalysisResult(provider: provider, model: modelName, text: response.text)
    }
    
    /// Analyze an image file with a question
    public func analyzeImageFile(at path: String, question: String, model: LanguageModel? = nil) async throws -> String {
        // Load image data
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)
        
        return try await analyzeImage(imageData: imageData, question: question, model: model)
    }

    /// Analyze an image file returning structured metadata
    public func analyzeImageFileDetailed(at path: String, question: String, model: LanguageModel? = nil) async throws -> AnalysisResult {
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)
        return try await analyzeImageDetailed(imageData: imageData, question: question, model: model)
    }
    
    /// Generate text from a prompt
    public func generateText(prompt: String, model: LanguageModel? = nil) async throws -> String {
        let selectedModel = model ?? defaultModel
        
        let messages = [
            ModelMessage.user(prompt)
        ]
        
        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages
        )
        
        return response.text
    }
    
    /// List available models
    public func availableModels() -> [LanguageModel] {
        return [
            .openai(.gpt5),
            .openai(.gpt5Mini),
            .openai(.gpt5Nano),
            .openai(.gpt4o),
            .openai(.gpt4oMini),
            .anthropic(.sonnet35),
            .anthropic(.haiku35),
            .google(.gemini15Pro),
            .google(.gemini15Flash)
        ]
    }
}
