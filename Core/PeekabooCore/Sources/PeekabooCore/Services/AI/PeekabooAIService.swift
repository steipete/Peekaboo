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
        
        // Create a message with the image
        let messages = [
            ModelMessage.user([
                .text(question),
                .image(imageData, detail: .auto)
            ])
        ]
        
        // Generate response using Tachikoma
        let response = try await generateText(
            model: selectedModel,
            messages: messages,
            temperature: 0.7,
            maxTokens: 1000
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
        
        let response = try await generateText(
            model: selectedModel,
            messages: messages,
            temperature: 0.7,
            maxTokens: 1000
        )
        
        return response.text
    }
    
    /// List available models
    public func availableModels() -> [LanguageModel] {
        return [
            .gpt4o,
            .gpt4oMini,
            .claude35Sonnet,
            .claude35Haiku,
            .gemini15Pro,
            .gemini15Flash
        ]
    }
}
