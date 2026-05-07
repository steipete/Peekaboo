import Foundation
import Tachikoma

extension ConfigurationManager {
    /// Get a configuration value with proper precedence: CLI args > env vars > config file > defaults
    public func getValue<T>(
        cliValue: T?,
        envVar: String?,
        configValue: T?,
        defaultValue: T) -> T
    {
        if let cliValue {
            return cliValue
        }

        if let envVar,
           let envValue = self.environmentValue(for: envVar),
           let converted: T = self.convertEnvValue(envValue, as: T.self)
        {
            return converted
        }

        if let configValue {
            return configValue
        }

        return defaultValue
    }

    /// Get AI providers with proper precedence
    public func getAIProviders(cliValue: String? = nil) -> String {
        self.getValue(
            cliValue: cliValue,
            envVar: "PEEKABOO_AI_PROVIDERS",
            configValue: self.configuration?.aiProviders?.providers,
            defaultValue: "openai/gpt-5.1,anthropic/claude-sonnet-4.5")
    }

    /// Get OpenAI API key with proper precedence
    public func getOpenAIAPIKey() -> String? {
        if let envValue = self.environmentValue(for: "OPENAI_API_KEY") {
            return envValue
        }

        if let token = self.validOAuthAccessToken(prefix: "OPENAI") {
            return token
        }

        if let credValue = credentials["OPENAI_API_KEY"] {
            return credValue
        }

        if let configValue = configuration?.aiProviders?.openaiApiKey {
            return configValue
        }

        return nil
    }

    /// Get Anthropic API key with proper precedence
    public func getAnthropicAPIKey() -> String? {
        if let envValue = self.environmentValue(for: "ANTHROPIC_API_KEY") {
            return envValue
        }

        if let token = self.validOAuthAccessToken(prefix: "ANTHROPIC") {
            return token
        }

        if let credValue = credentials["ANTHROPIC_API_KEY"] {
            return credValue
        }

        if let configValue = configuration?.aiProviders?.anthropicApiKey {
            return configValue
        }

        return nil
    }

    /// Get Gemini API key with proper precedence
    public func getGeminiAPIKey() -> String? {
        for key in ["GEMINI_API_KEY", "GOOGLE_API_KEY"] {
            if let envValue = self.environmentValue(for: key) {
                return envValue
            }
        }

        for key in ["GEMINI_API_KEY", "GOOGLE_API_KEY"] {
            if let credValue = credentials[key] {
                return credValue
            }
        }

        return nil
    }

    /// Get Ollama base URL with proper precedence
    public func getOllamaBaseURL() -> String {
        self.getValue(
            cliValue: nil as String?,
            envVar: "PEEKABOO_OLLAMA_BASE_URL",
            configValue: self.configuration?.aiProviders?.ollamaBaseUrl,
            defaultValue: "http://localhost:11434")
    }

    /// Get default save path with proper precedence
    public func getDefaultSavePath(cliValue: String? = nil) -> String {
        let path = self.getValue(
            cliValue: cliValue,
            envVar: "PEEKABOO_DEFAULT_SAVE_PATH",
            configValue: self.configuration?.defaults?.savePath,
            defaultValue: "~/Desktop")
        return NSString(string: path).expandingTildeInPath
    }

    /// Get log level with proper precedence
    public func getLogLevel() -> String {
        self.getValue(
            cliValue: nil as String?,
            envVar: "PEEKABOO_LOG_LEVEL",
            configValue: self.configuration?.logging?.level,
            defaultValue: "info")
    }

    /// Get log path with proper precedence
    public func getLogPath() -> String {
        let path = self.getValue(
            cliValue: nil as String?,
            envVar: "PEEKABOO_LOG_PATH",
            configValue: self.configuration?.logging?.path,
            defaultValue: "~/.peekaboo/logs/peekaboo.log")
        return NSString(string: path).expandingTildeInPath
    }

    /// Get selected AI provider
    public func getSelectedProvider() -> String {
        guard let providers = self.configuration?.aiProviders?.providers,
              let provider = self.parseFirstProvider(providers)
        else {
            return "anthropic"
        }

        switch provider.lowercased() {
        case "gemini", "google":
            return "google"
        default:
            return Provider.from(identifier: provider).identifier
        }
    }

    /// Get agent model
    public func getAgentModel() -> String? {
        self.configuration?.agent?.defaultModel
    }

    /// Get agent temperature
    public func getAgentTemperature() -> Double {
        self.getValue(
            cliValue: nil as Double?,
            envVar: nil,
            configValue: self.configuration?.agent?.temperature,
            defaultValue: 0.7)
    }

    /// Get agent max tokens
    public func getAgentMaxTokens() -> Int {
        self.getValue(
            cliValue: nil as Int?,
            envVar: nil,
            configValue: self.configuration?.agent?.maxTokens,
            defaultValue: 16384)
    }

    /// Test method to verify module interface
    public func testMethod() -> String {
        "test"
    }

    private func convertEnvValue<T>(_ value: String, as type: T.Type) -> T? {
        switch type {
        case is String.Type:
            return value as? T
        case is Bool.Type:
            let boolValue = value.lowercased() == "true" || value == "1"
            return boolValue as? T
        case is Int.Type:
            return Int(value) as? T
        case is Double.Type:
            return Double(value) as? T
        default:
            return nil
        }
    }

    private func parseFirstProvider(_ providers: String) -> String? {
        let components = providers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstProvider = components.first else { return nil }
        let parts = firstProvider.split(separator: "/")
        return parts.first.map(String.init)
    }
}
