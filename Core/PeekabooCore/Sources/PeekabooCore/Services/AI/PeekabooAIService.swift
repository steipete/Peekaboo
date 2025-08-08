import Foundation
import Tachikoma

/// AI service for handling model interactions and AI-powered features
@MainActor
public final class PeekabooAIService {
    private let defaultModel: LanguageModel = .openai(.gpt5)
    
    public init() {
        // Ensure TachikomaConfiguration is hydrated from Peekaboo configuration
        let config = ConfigurationManager.shared
        if let openAIKey = config.getOpenAIAPIKey(), !openAIKey.isEmpty {
            TachikomaConfiguration.current.setAPIKey(openAIKey, for: .openai)
        }
        if let anthropicKey = config.getAnthropicAPIKey(), !anthropicKey.isEmpty {
            TachikomaConfiguration.current.setAPIKey(anthropicKey, for: .anthropic)
        }
        TachikomaConfiguration.current.setBaseURL(config.getOllamaBaseURL(), for: .ollama)
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
    
    /// Analyze an image file with a question
    public func analyzeImageFile(at path: String, question: String, model: LanguageModel? = nil) async throws -> String {
        // Load image data
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)
        
        return try await analyzeImage(imageData: imageData, question: question, model: model)
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
