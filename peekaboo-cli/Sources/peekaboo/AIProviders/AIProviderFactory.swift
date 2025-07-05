import Foundation

/// Factory for creating and managing AI provider instances.
///
/// Handles creation of AI providers based on configuration, automatic provider
/// selection, and fallback logic when providers are unavailable.
enum AIProviderFactory {
    static func createProvider(from config: AIProviderConfig) -> AIProvider? {
        switch config.provider.lowercased() {
        case "openai":
            OpenAIProvider(model: config.model)
        case "ollama":
            OllamaProvider(model: config.model)
        default:
            nil
        }
    }

    static func createProviders(from environmentVariable: String?) -> [AIProvider] {
        let configs = parseAIProviders(from: environmentVariable)
        return configs.compactMap { createProvider(from: $0) }
    }

    static func getDefaultModel(for provider: String) -> String {
        switch provider.lowercased() {
        case "openai":
            "gpt-4o"
        case "ollama":
            "llava:latest"
        default:
            "unknown"
        }
    }

    static func findAvailableProvider(from providers: [AIProvider]) async -> AIProvider? {
        for provider in providers {
            if await provider.isAvailable {
                return provider
            }
        }
        return nil
    }

    static func determineProvider(
        requestedType: String?,
        requestedModel: String?,
        configuredProviders: [AIProvider]
    ) async throws -> AIProvider {
        let providerType = requestedType ?? "auto"

        if providerType != "auto" {
            // Find specific provider
            guard let provider = configuredProviders.first(where: {
                $0.name.lowercased() == providerType.lowercased()
            }) else {
                throw AIProviderError.notConfigured(
                    "Provider '\(providerType)' is not enabled in PEEKABOO_AI_PROVIDERS configuration"
                )
            }

            // Check if provider is available
            let status = await provider.checkAvailability()
            if !status.available {
                throw AIProviderError.notConfigured(
                    "Provider '\(providerType)' is configured but not currently available: \(status.error ?? "Unknown error")"
                )
            }

            // If a specific model was requested, we'd need to create a new instance
            // For now, we'll use the configured model
            return provider
        }

        // Auto mode - find first available provider
        guard let availableProvider = await findAvailableProvider(from: configuredProviders) else {
            throw AIProviderError.notConfigured(
                "No configured AI providers are currently operational"
            )
        }

        return availableProvider
    }
}
