import Foundation
import TachikomaCore

/// Utility for parsing AI provider configurations from string format
/// Migrated from legacy system to work with current Tachikoma architecture
public enum AIProviderParser {
    /// Represents a parsed provider configuration
    public struct ProviderConfig: Equatable {
        public let provider: String
        public let model: String
        
        public init(provider: String, model: String) {
            self.provider = provider
            self.model = model
        }
    }
    
    /// Parse a single provider string in format "provider/model"
    public static func parse(_ input: String) -> ProviderConfig? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let components = trimmed.split(separator: "/", maxSplits: 1)
        guard components.count == 2 else { return nil }
        
        let provider = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let model = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !provider.isEmpty && !model.isEmpty else { return nil }
        
        return ProviderConfig(provider: provider, model: model)
    }
    
    /// Parse a comma-separated list of provider strings
    public static func parseList(_ input: String) -> [ProviderConfig] {
        let providers = input.split(separator: ",")
        return providers.compactMap { parse(String($0)) }
    }
    
    /// Parse and return the first valid provider from a list
    public static func parseFirst(_ input: String) -> ProviderConfig? {
        let list = parseList(input)
        return list.first
    }
    
    /// Extract just the provider name from a provider/model string
    public static func extractProvider(from input: String) -> String? {
        return parse(input)?.provider
    }
    
    /// Extract just the model name from a provider/model string
    public static func extractModel(from input: String) -> String? {
        return parse(input)?.model
    }
    
    /// Determine the default model based on available providers and configuration
    public static func determineDefaultModel(
        from providerList: String,
        hasOpenAI: Bool = false,
        hasAnthropic: Bool = false,
        hasOllama: Bool = false,
        configuredDefault: String? = nil
    ) -> String {
        // If there's a configured default, use it
        if let configuredDefault = configuredDefault, !configuredDefault.isEmpty {
            return configuredDefault
        }
        
        // Parse the provider list and find the first available one
        let configs = parseList(providerList)
        for config in configs {
            switch config.provider.lowercased() {
            case "openai":
                if hasOpenAI { return config.model }
            case "anthropic":
                if hasAnthropic { return config.model }
            case "ollama":
                if hasOllama { return config.model }
            default:
                break
            }
        }
        
        // Fall back to hardcoded defaults based on what's available
        if hasAnthropic {
            return "claude-opus-4-20250514"
        } else if hasOpenAI {
            return "o3"
        } else {
            return "llava:latest" // Ollama fallback
        }
    }
}