import Foundation

public struct AIProviderFactory {
    
    // MARK: - Factory Methods
    
    public static func createProvider(from config: AIProviderConfig) -> AIProvider? {
        guard config.isValid else { return nil }
        
        switch config.provider.lowercased() {
        case "openai":
            return OpenAIProvider(model: config.model)
        case "ollama":
            return OllamaProvider(model: config.model)
        default:
            return nil
        }
    }
    
    public static func createProviders(from string: String?) -> [AIProvider] {
        let configs = parseAIProviders(string)
        return configs.compactMap { createProvider(from: $0) }
    }
    
    // MARK: - Default Models
    
    public static func getDefaultModel(for provider: String) -> String {
        switch provider.lowercased() {
        case "openai":
            return "gpt-4.1"
        case "ollama":
            return "llava:latest"
        default:
            return provider.lowercased()
        }
    }
    
    // MARK: - Provider Selection
    
    public static func findAvailableProvider(from providers: [AIProvider]) async -> AIProvider? {
        for provider in providers {
            if await provider.isAvailable {
                return provider
            }
        }
        return nil
    }
    
    public static func determineProvider(
        requestedType: String?,
        requestedModel: String?,
        configuredProviders: [AIProvider]
    ) async throws -> AIProvider {
        // If specific provider requested
        if let requestedType = requestedType, requestedType != "auto" {
            guard let provider = configuredProviders.first(where: { $0.name.lowercased() == requestedType.lowercased() }) else {
                throw AIProviderError.notConfigured("Provider '\(requestedType)' is not enabled")
            }
            
            if await !provider.isAvailable {
                throw AIProviderError.notConfigured("Provider '\(requestedType)' is not currently available")
            }
            
            return provider
        }
        
        // Auto-select first available provider
        guard let availableProvider = await findAvailableProvider(from: configuredProviders) else {
            if configuredProviders.isEmpty {
                throw AIProviderError.notConfigured("No AI providers configured")
            } else {
                throw AIProviderError.notConfigured("No configured AI providers are currently operational")
            }
        }
        
        return availableProvider
    }
}