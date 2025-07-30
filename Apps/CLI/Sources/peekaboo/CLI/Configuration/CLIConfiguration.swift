import Foundation
import PeekabooCore

// Re-use the Configuration type from PeekabooCore
typealias Configuration = PeekabooCore.Configuration

/// CLI-specific configuration manager that extends PeekabooCore's ConfigurationManager
/// with additional CLI-specific functionality.
final class ConfigurationManager: @unchecked Sendable {
    static let shared = ConfigurationManager()

    // Use PeekabooCore's ConfigurationManager for core functionality
    private let coreManager = PeekabooCore.ConfigurationManager.shared

    private init() {}

    // MARK: - Delegate to Core Manager

    /// Base directory for all Peekaboo configuration
    static var baseDir: String {
        PeekabooCore.ConfigurationManager.baseDir
    }

    /// Legacy configuration directory (for migration)
    static var legacyConfigDir: String {
        PeekabooCore.ConfigurationManager.legacyConfigDir
    }

    /// Default configuration file path
    static var configPath: String {
        PeekabooCore.ConfigurationManager.configPath
    }

    /// Legacy configuration file path (for migration)
    static var legacyConfigPath: String {
        PeekabooCore.ConfigurationManager.legacyConfigPath
    }

    /// Credentials file path
    static var credentialsPath: String {
        PeekabooCore.ConfigurationManager.credentialsPath
    }

    /// Migrate from legacy configuration if needed
    func migrateIfNeeded() throws {
        try self.coreManager.migrateIfNeeded()
    }

    /// Load configuration from file
    func loadConfiguration() -> Configuration? {
        self.coreManager.loadConfiguration()
    }

    /// Strip comments from JSONC content
    func stripJSONComments(from json: String) -> String {
        self.coreManager.stripJSONComments(from: json)
    }

    /// Expand environment variables in the format ${VAR_NAME}
    func expandEnvironmentVariables(in text: String) -> String {
        self.coreManager.expandEnvironmentVariables(in: text)
    }

    /// Get AI providers with proper precedence
    func getAIProviders(cliValue: String? = nil) -> String {
        self.coreManager.getAIProviders(cliValue: cliValue)
    }

    /// Get OpenAI API key with proper precedence
    func getOpenAIAPIKey() -> String? {
        self.coreManager.getOpenAIAPIKey()
    }

    /// Get Ollama base URL with proper precedence
    func getOllamaBaseURL() -> String {
        self.coreManager.getOllamaBaseURL()
    }

    /// Get default save path with proper precedence
    func getDefaultSavePath(cliValue: String? = nil) -> String {
        self.coreManager.getDefaultSavePath(cliValue: cliValue)
    }

    /// Get log level with proper precedence
    func getLogLevel() -> String {
        self.coreManager.getLogLevel()
    }

    /// Get log path with proper precedence
    func getLogPath() -> String {
        self.coreManager.getLogPath()
    }

    /// Create default configuration file
    func createDefaultConfiguration() throws {
        try self.coreManager.createDefaultConfiguration()
    }

    /// Set or update a credential
    func setCredential(key: String, value: String) throws {
        try self.coreManager.setCredential(key: key, value: value)
    }

    /// Get configuration value with precedence
    func getValue<T>(
        cliValue: T?,
        envVar: String?,
        configValue: T?,
        defaultValue: T
    ) -> T {
        self.coreManager.getValue(
            cliValue: cliValue,
            envVar: envVar,
            configValue: configValue,
            defaultValue: defaultValue
        )
    }
}
