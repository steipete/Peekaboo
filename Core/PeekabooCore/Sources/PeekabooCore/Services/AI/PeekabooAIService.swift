import Foundation
import Tachikoma

/// AI service for handling model interactions and AI-powered features
@MainActor
public final class PeekabooAIService {
    private let defaultModel: LanguageModel = .gpt4o
    
    public init() {
        // AI service is ready to use with Tachikoma
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
            .openai(.gpt4o),
            .openai(.gpt4oMini),
            .anthropic(.sonnet35),
            .anthropic(.haiku35),
            .google(.gemini15Pro),
            .google(.gemini15Flash)
        ]
    }
}
