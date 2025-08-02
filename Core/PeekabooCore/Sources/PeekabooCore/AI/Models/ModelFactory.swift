import Foundation

// MARK: - Model Factory

/// Factory for creating AI model instances based on provider configuration
@MainActor
public final class ModelFactory {
    public static let shared = ModelFactory()
    
    private init() {}
    
    /// Create a model instance from a model name and provider type
    /// - Parameters:
    ///   - modelName: The name of the model (e.g., "gpt-4", "claude-opus-4")
    ///   - providerType: Optional provider type override
    /// - Returns: A model instance conforming to ModelInterface
    public func createModel(modelName: String, providerType: String? = nil) -> any ModelInterface {
        // Parse the provider from model name if not explicitly provided
        let provider: String
        if let providerType = providerType {
            provider = providerType.lowercased()
        } else if modelName.hasPrefix("gpt") || modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
            provider = "openai"
        } else if modelName.hasPrefix("claude") {
            provider = "anthropic"
        } else if modelName.hasPrefix("grok") {
            provider = "xai"
        } else {
            // Default to a generic provider
            provider = "generic"
        }
        
        // For now, return a simple implementation that delegates to the CLI infrastructure
        return AIModel(name: modelName, provider: provider)
    }
}

// MARK: - AI Model Implementation

/// Basic AI model implementation that integrates with the existing CLI infrastructure
private struct AIModel: ModelInterface {
    let name: String
    let provider: String
    
    var modelName: String { name }
    
    var supportsVision: Bool {
        // Determine vision support based on model name
        switch provider {
        case "openai":
            return name.contains("gpt-4o") || name.contains("gpt-4-vision") || name.contains("gpt-4.1")
        case "anthropic":
            return true // All modern Claude models support vision
        case "ollama":
            return name.contains("llava") || name.contains("bakllava") || name.contains("vision")
        default:
            return false
        }
    }
    
    func sendMessage(_ message: String, with context: [Message]) async throws -> String {
        // This is a bridge implementation - the actual AI communication happens in the CLI layer
        // For now, we'll throw an error indicating this needs to be implemented at the CLI level
        throw PeekabooError.notImplemented("AI model communication is implemented at the CLI layer")
    }
    
    func sendRequest(_ request: ModelRequest) async throws -> String {
        // This is a bridge implementation - the actual AI communication happens in the CLI layer
        throw PeekabooError.notImplemented("AI model communication is implemented at the CLI layer")
    }
}

// MARK: - Model Parameters

/// Parameters that can be passed to models
public struct ModelParameters {
    private var parameters: [String: Any] = [:]
    
    public init() {}
    
    /// Add a parameter
    public func with(_ key: String, value: Any) -> ModelParameters {
        var updated = self
        updated.parameters[key] = value
        return updated
    }
    
    /// Get a string parameter
    public func string(_ key: String) -> String? {
        parameters[key] as? String
    }
    
    /// Get an integer parameter
    public func int(_ key: String) -> Int? {
        parameters[key] as? Int
    }
    
    /// Get a boolean parameter
    public func bool(_ key: String) -> Bool? {
        parameters[key] as? Bool
    }
    
    /// Check if parameters are empty
    public var isEmpty: Bool {
        parameters.isEmpty
    }
}