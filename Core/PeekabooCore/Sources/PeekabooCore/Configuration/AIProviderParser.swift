import Foundation

/// Utility for parsing AI provider configuration strings
public enum AIProviderParser {
    
    /// Represents a parsed AI provider configuration
    public struct ProviderConfig: Equatable, Sendable {
        /// The provider name (e.g., "openai", "anthropic", "ollama")
        public let provider: String
        
        /// The model name (e.g., "gpt-4", "claude-3", "llava:latest")
        public let model: String
        
        /// The full string representation (e.g., "openai/gpt-4")
        public var fullString: String {
            "\(provider)/\(model)"
        }
    }
    
    /// Parse a provider string in the format "provider/model"
    /// - Parameter providerString: String like "openai/gpt-4" or "ollama/llava:latest"
    /// - Returns: Parsed configuration or nil if invalid format
    public static func parse(_ providerString: String) -> ProviderConfig? {
        let trimmed = providerString.trimmingCharacters(in: .whitespaces)
        guard let slashIndex = trimmed.firstIndex(of: "/") else {
            return nil
        }
        
        let provider = String(trimmed[..<slashIndex])
        let model = String(trimmed[trimmed.index(after: slashIndex)...])
        
        // Validate both parts are non-empty
        guard !provider.isEmpty && !model.isEmpty else {
            return nil
        }
        
        return ProviderConfig(provider: provider, model: model)
    }
    
    /// Parse a comma-separated list of providers
    /// - Parameter providersString: String like "openai/gpt-4,anthropic/claude-3,ollama/llava:latest"
    /// - Returns: Array of parsed configurations
    public static func parseList(_ providersString: String) -> [ProviderConfig] {
        providersString
            .split(separator: ",")
            .compactMap { parse(String($0)) }
    }
    
    /// Get the first provider from a comma-separated list
    /// - Parameter providersString: String like "openai/gpt-4,anthropic/claude-3"
    /// - Returns: First parsed configuration or nil if none valid
    public static func parseFirst(_ providersString: String) -> ProviderConfig? {
        parseList(providersString).first
    }
    
    /// Result of determining the default model with conflict information
    public struct ModelDetermination {
        /// The model to use
        public let model: String
        
        /// Whether there was a conflict between env var and config
        public let hasConflict: Bool
        
        /// The model from environment variable (if any)
        public let environmentModel: String?
        
        /// The model from configuration (if any)
        public let configModel: String?
    }
    
    /// Determine the default model based on available providers and API keys
    /// - Parameters:
    ///   - providersString: The PEEKABOO_AI_PROVIDERS string
    ///   - hasOpenAI: Whether OpenAI API key is available
    ///   - hasAnthropic: Whether Anthropic API key is available
    ///   - hasOllama: Whether Ollama is available (always true as it doesn't require API key)
    ///   - configuredDefault: Optional default from configuration
    ///   - isEnvironmentProvided: Whether the providers string came from environment variable
    /// - Returns: Model determination result with conflict information
    public static func determineDefaultModelWithConflict(
        from providersString: String,
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasOllama: Bool = true,
        configuredDefault: String? = nil,
        isEnvironmentProvided: Bool = false
    ) -> ModelDetermination {
        // Parse providers and find first available one
        let providers = parseList(providersString)
        print("[AIProviderParser] Parsing providers: \(providersString)")
        print("[AIProviderParser] Parsed providers: \(providers)")
        var environmentModel: String?
        
        for config in providers {
            print("[AIProviderParser] Checking provider: \(config.provider) with model: \(config.model)")
            switch config.provider.lowercased() {
            case "openai" where hasOpenAI:
                environmentModel = config.model
                print("[AIProviderParser] Found OpenAI model: \(config.model)")
                break
            case "anthropic" where hasAnthropic:
                environmentModel = config.model
                print("[AIProviderParser] Found Anthropic model: \(config.model)")
                break
            case "ollama" where hasOllama:
                environmentModel = config.model
                print("[AIProviderParser] Found Ollama model: \(config.model)")
                break
            default:
                print("[AIProviderParser] Provider not available or not recognized: \(config.provider)")
                continue
            }
            if environmentModel != nil { break }
        }
        
        // Determine if there's a conflict
        let hasConflict = isEnvironmentProvided && 
                         environmentModel != nil && 
                         configuredDefault != nil && 
                         environmentModel != configuredDefault
        
        // Environment variable takes precedence over config
        let finalModel: String
        print("[AIProviderParser] isEnvironmentProvided: \(isEnvironmentProvided), environmentModel: \(environmentModel ?? "nil"), configuredDefault: \(configuredDefault ?? "nil")")
        if let envModel = environmentModel, isEnvironmentProvided {
            finalModel = envModel
            print("[AIProviderParser] Using environment model: \(finalModel)")
        } else if let configuredDefault = configuredDefault {
            finalModel = configuredDefault
            print("[AIProviderParser] Using configured default: \(finalModel)")
        } else {
            // Fall back to defaults based on available API keys
            if hasAnthropic {
                finalModel = "claude-opus-4-20250514"
                print("[AIProviderParser] Using Anthropic default: \(finalModel)")
            } else if hasOpenAI {
                finalModel = "o3"
                print("[AIProviderParser] Using OpenAI default: \(finalModel)")
            } else {
                finalModel = "llava:latest"
                print("[AIProviderParser] Using Ollama default: \(finalModel)")
            }
        }
        
        return ModelDetermination(
            model: finalModel,
            hasConflict: hasConflict,
            environmentModel: environmentModel,
            configModel: configuredDefault
        )
    }
    
    /// Determine the default model based on available providers and API keys (simple version)
    /// - Parameters:
    ///   - providersString: The PEEKABOO_AI_PROVIDERS string
    ///   - hasOpenAI: Whether OpenAI API key is available
    ///   - hasAnthropic: Whether Anthropic API key is available
    ///   - hasOllama: Whether Ollama is available (always true as it doesn't require API key)
    ///   - configuredDefault: Optional default from configuration
    /// - Returns: The model name to use
    public static func determineDefaultModel(
        from providersString: String,
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasOllama: Bool = true,
        configuredDefault: String? = nil
    ) -> String {
        let determination = determineDefaultModelWithConflict(
            from: providersString,
            hasOpenAI: hasOpenAI,
            hasAnthropic: hasAnthropic,
            hasOllama: hasOllama,
            configuredDefault: configuredDefault,
            isEnvironmentProvided: false
        )
        return determination.model
    }
    
    /// Extract provider name from a full provider/model string
    /// - Parameter fullString: String like "openai/gpt-4"
    /// - Returns: Just the provider part (e.g., "openai")
    public static func extractProvider(from fullString: String) -> String? {
        parse(fullString)?.provider
    }
    
    /// Extract model name from a full provider/model string
    /// - Parameter fullString: String like "openai/gpt-4"
    /// - Returns: Just the model part (e.g., "gpt-4")
    public static func extractModel(from fullString: String) -> String? {
        parse(fullString)?.model
    }
}