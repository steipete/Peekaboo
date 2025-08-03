import Foundation

/// Utility for parsing AI provider configuration strings
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ProviderParser {
    /// Represents a parsed AI provider configuration
    public struct ProviderConfig: Equatable, Sendable {
        /// The provider name (e.g., "openai", "anthropic", "ollama")
        public let provider: String

        /// The model name (e.g., "gpt-4", "claude-3", "llava:latest")
        public let model: String

        /// The full string representation (e.g., "openai/gpt-4")
        public var fullString: String {
            "\(self.provider)/\(self.model)"
        }

        public init(provider: String, model: String) {
            self.provider = provider
            self.model = model
        }
    }

    /// Parse a provider string in the format "provider/model"
    /// - Parameter providerString: String like "openai/gpt-4" or "ollama/llava:latest"
    /// - Returns: Parsed configuration or nil if invalid format
    public static func parse(_ providerString: String) -> ProviderConfig? {
        let trimmed = providerString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slashIndex = trimmed.firstIndex(of: "/") else {
            return nil
        }

        let provider = String(trimmed[..<slashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let model = String(trimmed[trimmed.index(after: slashIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate both parts are non-empty
        guard !provider.isEmpty, !model.isEmpty else {
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
            .compactMap { self.parse(String($0)) }
    }

    /// Get the first provider from a comma-separated list
    /// - Parameter providersString: String like "openai/gpt-4,anthropic/claude-3"
    /// - Returns: First parsed configuration or nil if none valid
    public static func parseFirst(_ providersString: String) -> ProviderConfig? {
        self.parseList(providersString).first
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

        public init(
            model: String,
            hasConflict: Bool,
            environmentModel: String? = nil,
            configModel: String? = nil)
        {
            self.model = model
            self.hasConflict = hasConflict
            self.environmentModel = environmentModel
            self.configModel = configModel
        }
    }

    /// Determine the default model based on available providers and API keys
    /// - Parameters:
    ///   - providersString: The AI_PROVIDERS string (e.g., from TACHIKOMA_AI_PROVIDERS env var)
    ///   - hasOpenAI: Whether OpenAI API key is available
    ///   - hasAnthropic: Whether Anthropic API key is available
    ///   - hasGrok: Whether Grok API key is available
    ///   - hasOllama: Whether Ollama is available (always true as it doesn't require API key)
    ///   - configuredDefault: Optional default from configuration
    ///   - isEnvironmentProvided: Whether the providers string came from environment variable
    /// - Returns: Model determination result with conflict information
    public static func determineDefaultModelWithConflict(
        from providersString: String,
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasGrok: Bool = false,
        hasOllama: Bool = true,
        configuredDefault: String? = nil,
        isEnvironmentProvided: Bool = false) -> ModelDetermination
    {
        // Parse providers and find first available one
        let providers = self.parseList(providersString)
        var environmentModel: String?

        for config in providers {
            switch config.provider.lowercased() {
            case "openai" where hasOpenAI:
                environmentModel = config.model
            case "anthropic" where hasAnthropic:
                environmentModel = config.model
            case "grok", "xai" where hasGrok:
                environmentModel = config.model
            case "ollama" where hasOllama:
                environmentModel = config.model
            default:
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
        let finalModel: String = if let envModel = environmentModel, isEnvironmentProvided {
            envModel
        } else if let configuredDefault {
            configuredDefault
        } else if let envModel = environmentModel {
            // Use the first available provider from the list even when not from environment
            envModel
        } else {
            // Fall back to defaults based on available API keys
            if hasAnthropic {
                "claude-opus-4-20250514"
            } else if hasOpenAI {
                "o3"
            } else if hasGrok {
                "grok-4"
            } else {
                "llava:latest"
            }
        }

        return ModelDetermination(
            model: finalModel,
            hasConflict: hasConflict,
            environmentModel: environmentModel,
            configModel: configuredDefault)
    }

    /// Determine the default model based on available providers and API keys (simple version)
    /// - Parameters:
    ///   - providersString: The AI_PROVIDERS string
    ///   - hasOpenAI: Whether OpenAI API key is available
    ///   - hasAnthropic: Whether Anthropic API key is available
    ///   - hasGrok: Whether Grok API key is available
    ///   - hasOllama: Whether Ollama is available (always true as it doesn't require API key)
    ///   - configuredDefault: Optional default from configuration
    /// - Returns: The model name to use
    public static func determineDefaultModel(
        from providersString: String,
        hasOpenAI: Bool,
        hasAnthropic: Bool,
        hasGrok: Bool = false,
        hasOllama: Bool = true,
        configuredDefault: String? = nil) -> String
    {
        let determination = self.determineDefaultModelWithConflict(
            from: providersString,
            hasOpenAI: hasOpenAI,
            hasAnthropic: hasAnthropic,
            hasGrok: hasGrok,
            hasOllama: hasOllama,
            configuredDefault: configuredDefault,
            isEnvironmentProvided: false)
        return determination.model
    }

    /// Extract provider name from a full provider/model string
    /// - Parameter fullString: String like "openai/gpt-4"
    /// - Returns: Just the provider part (e.g., "openai")
    public static func extractProvider(from fullString: String) -> String? {
        self.parse(fullString)?.provider
    }

    /// Extract model name from a full provider/model string
    /// - Parameter fullString: String like "openai/gpt-4"
    /// - Returns: Just the model part (e.g., "gpt-4")
    public static func extractModel(from fullString: String) -> String? {
        self.parse(fullString)?.model
    }
}
