import Darwin
import Foundation

#if canImport(Configuration)
import Configuration

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *)
private struct IdentityKeyDecoder: ConfigKeyDecoder {
    func decode(_ string: String, context: [String: ConfigContextValue]) -> ConfigKey {
        ConfigKey([string], context: context)
    }
}
#endif
import PeekabooFoundation
import Tachikoma
import TachikomaMCP

/// Manages configuration loading and precedence resolution.
///
/// `ConfigurationManager` implements a hierarchical configuration system with the following
/// precedence (highest to lowest):
/// 1. Command-line arguments
/// 2. Environment variables
/// 3. Configuration file (`~/.peekaboo/config.json`)
/// 4. Credentials file (`~/.peekaboo/credentials`)
/// 5. Built-in defaults
///
/// The manager supports JSONC format (JSON with Comments) and environment variable
/// expansion using `${VAR_NAME}` syntax. Sensitive credentials are stored separately
/// in a credentials file with restricted permissions.
public final class ConfigurationManager: @unchecked Sendable {
    public static let shared = ConfigurationManager()

    /// Base directory for all Peekaboo configuration
    public static var baseDir: String {
        NSString(string: "~/.peekaboo").expandingTildeInPath
    }

    /// Legacy configuration directory (for migration)
    public static var legacyConfigDir: String {
        NSString(string: "~/.config/peekaboo").expandingTildeInPath
    }

    /// Default configuration file path
    public static var configPath: String {
        "\(baseDir)/config.json"
    }

    /// Legacy configuration file path (for migration)
    public static var legacyConfigPath: String {
        "\(legacyConfigDir)/config.json"
    }

    /// Credentials file path
    public static var credentialsPath: String {
        "\(baseDir)/credentials"
    }

    /// Loaded configuration
    private var configuration: Configuration?

    /// Cached credentials
    private var credentials: [String: String] = [:]

    #if canImport(Configuration)
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *)
    private static var environmentReader: ConfigReader {
        enum Holder {
            static let reader = ConfigReader(
                keyDecoder: IdentityKeyDecoder(),
                provider: EnvironmentVariablesProvider(
                    secretsSpecifier: .dynamic { key, _ in
                        let lowercased = key.lowercased()
                        return lowercased.contains("key") ||
                            lowercased.contains("token") ||
                            lowercased.contains("secret")
                    }))
        }
        return Holder.reader
    }
    #endif

    private init() {
        // Load configuration on init, but don't crash if it fails
        _ = self.loadConfiguration()
    }

    /// Migrate from legacy configuration if needed
    public func migrateIfNeeded() throws {
        // Migrate from legacy configuration if needed
        let fileManager = FileManager.default

        // Check if legacy config exists but new config doesn't
        if fileManager.fileExists(atPath: Self.legacyConfigPath),
           !fileManager.fileExists(atPath: Self.configPath)
        {
            // Create new base directory
            try fileManager.createDirectory(
                atPath: Self.baseDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])

            // Copy config file
            try fileManager.copyItem(
                atPath: Self.legacyConfigPath,
                toPath: Self.configPath)

            // Load the config to extract any API keys
            if let config = loadConfigurationFromPath(Self.configPath) {
                var credentialsToSave: [String: String] = [:]

                // Extract OpenAI API key if it's hardcoded (not an env var reference)
                if let apiKey = config.aiProviders?.openaiApiKey,
                   !apiKey.hasPrefix("${"),
                   !apiKey.isEmpty
                {
                    credentialsToSave["OPENAI_API_KEY"] = apiKey
                }

                // Save credentials if any were found
                if !credentialsToSave.isEmpty {
                    try self.saveCredentials(credentialsToSave)

                    // Remove hardcoded API key from config and update it
                    var updatedConfig = config
                    if updatedConfig.aiProviders?.openaiApiKey != nil {
                        updatedConfig.aiProviders?.openaiApiKey = nil
                    }

                    // Save updated config without hardcoded credentials
                    let data = try JSONCoding.encoder.encode(updatedConfig)
                    try data.write(to: URL(fileURLWithPath: Self.configPath), options: .atomic)
                }
            }

            let migrationMessage =
                "\(AgentDisplayTokens.Status.success) Migrated configuration from \(Self.legacyConfigPath) " +
                "to \(Self.configPath)"
            print(migrationMessage)
        }
    }

    /// Load configuration from file
    public func loadConfiguration() -> Configuration? {
        // Try migration first
        try? self.migrateIfNeeded()

        // Load credentials
        self.loadCredentials()

        // Load configuration
        self.configuration = self.loadConfigurationFromPath(Self.configPath)
        return self.configuration
    }

    /// Get the current configuration.
    ///
    /// Returns the loaded configuration or loads it if not already loaded.
    public func getConfiguration() -> Configuration? {
        // Get the current configuration.
        if self.configuration == nil {
            _ = self.loadConfiguration()
        }
        return self.configuration
    }

    /// Load configuration from a specific path
    private func loadConfigurationFromPath(_ configPath: String) -> Configuration? {
        // Load configuration from a specific path
        guard FileManager.default.fileExists(atPath: configPath) else {
            return nil
        }

        var expandedJSON = ""

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let jsonString = String(data: data, encoding: .utf8) ?? ""

            // Strip comments from JSONC
            let cleanedJSON = self.stripJSONComments(from: jsonString)

            // Expand environment variables
            expandedJSON = self.expandEnvironmentVariables(in: cleanedJSON)

            // Parse JSON
            if let expandedData = expandedJSON.data(using: .utf8) {
                let config = try JSONCoding.decoder.decode(Configuration.self, from: expandedData)
                self.configuration = config
                return config
            }
        } catch let error as DecodingError {
            // Provide more detailed error information for JSON decoding errors
            switch error {
            case let .keyNotFound(key, context):
                let path = self.codingPathDescription(context)
                self.printWarning("JSON key not found '\(key.stringValue)' at path: \(path)")
            case let .typeMismatch(type, context):
                let path = self.codingPathDescription(context)
                self.printWarning("Type mismatch for type '\(type)' at path: \(path)")
            case let .valueNotFound(type, context):
                let path = self.codingPathDescription(context)
                self.printWarning("Value not found for type '\(type)' at path: \(path)")
            case let .dataCorrupted(context):
                let path = self.codingPathDescription(context)
                self.printWarning("Data corrupted at path: \(path)")
                if let underlyingError = context.underlyingError {
                    print("Underlying error: \(underlyingError)")
                }
            @unknown default:
                self.printWarning("Unknown decoding error: \(error)")
            }

            // For debugging, print the cleaned JSON
            if expandedJSON.count < 5000 { // Only print if reasonably sized
                self.printWarning("Cleaned JSON that failed to parse:")
                print(expandedJSON)
            }
        } catch {
            self.printWarning("Failed to load configuration from \(configPath): \(error)")
        }

        return nil
    }

    private func printWarning(_ message: String) {
        print("Warning: \(message)")
    }

    private func codingPathDescription(_ context: DecodingError.Context) -> String {
        context.codingPath.map(\.stringValue).joined(separator: ".")
    }

    /// Load credentials from file
    private func loadCredentials() {
        // Load credentials from file
        guard FileManager.default.fileExists(atPath: Self.credentialsPath) else {
            return
        }

        do {
            let contents = try String(contentsOfFile: Self.credentialsPath)
            let lines = contents.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }

                if let equalIndex = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[trimmed.index(after: equalIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty, !value.isEmpty {
                        self.credentials[key] = value
                    }
                }
            }
        } catch {
            // Silently ignore credential loading errors
        }
    }

    /// Save credentials to file with proper permissions
    public func saveCredentials(_ newCredentials: [String: String]) throws {
        newCredentials.forEach { self.credentials[$0.key] = $0.value }

        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        let header = [
            "# Peekaboo credentials file",
            "# This file contains sensitive API keys and should not be shared",
            "",
        ]
        let body = self.credentials.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }
        let content = (header + body).joined(separator: "\n")

        try content.write(
            to: URL(fileURLWithPath: Self.credentialsPath),
            atomically: true,
            encoding: .utf8)

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.credentialsPath)
    }

    /// Strip comments from JSONC content
    public func stripJSONComments(from json: String) -> String {
        var stripper = JSONCommentStripper(json: json)
        return stripper.strip()
    }

    /// Expand environment variables in the format ${VAR_NAME}
    public func expandEnvironmentVariables(in text: String) -> String {
        // Expand environment variables in the format ${VAR_NAME}
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)

            var result = text

            // Find all matches in reverse order to preserve indices
            let matches = regex.matches(in: text, options: [], range: range).reversed()

            for match in matches {
                let varNameRange = match.range(at: 1)
                if let swiftRange = Range(varNameRange, in: text) {
                    let varName = String(text[swiftRange])
                    if let value = self.environmentValue(for: varName),
                       let fullMatch = Range(match.range, in: text)
                    {
                        result.replaceSubrange(fullMatch, with: value)
                    }
                }
            }

            return result
        } catch {
            return text
        }
    }

    /// Get a configuration value with proper precedence: CLI args > env vars > config file > defaults
    public func getValue<T>(
        cliValue: T?,
        envVar: String?,
        configValue: T?,
        defaultValue: T) -> T
    {
        // CLI argument takes highest precedence
        if let cliValue {
            return cliValue
        }

        // Environment variable takes second precedence
        if let envVar,
           let envValue = self.environmentValue(for: envVar),
           let converted: T = self.convertEnvValue(envValue, as: T.self)
        {
            return converted
        }

        // Config file value takes third precedence
        if let configValue {
            return configValue
        }

        // Default value as fallback
        return defaultValue
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

    /// Get AI providers with proper precedence
    public func getAIProviders(cliValue: String? = nil) -> String {
        // Get AI providers with proper precedence
        self.getValue(
            cliValue: cliValue,
            envVar: "PEEKABOO_AI_PROVIDERS",
            configValue: self.configuration?.aiProviders?.providers,
            defaultValue: "openai/gpt-5.1,anthropic/claude-sonnet-4.5")
    }

    /// Get OpenAI API key with proper precedence
    public func getOpenAIAPIKey() -> String? {
        // 1. Environment variable (highest priority)
        if let envValue = self.environmentValue(for: "OPENAI_API_KEY") {
            return envValue
        }

        // 2. Credentials file
        if let credValue = credentials["OPENAI_API_KEY"] {
            return credValue
        }

        // 3. Config file (for backwards compatibility, but discouraged)
        if let configValue = configuration?.aiProviders?.openaiApiKey {
            return configValue
        }

        return nil
    }

    /// Get Anthropic API key with proper precedence
    public func getAnthropicAPIKey() -> String? {
        // 1. Environment variable (highest priority)
        if let envValue = self.environmentValue(for: "ANTHROPIC_API_KEY") {
            return envValue
        }

        // 2. Credentials file
        if let credValue = credentials["ANTHROPIC_API_KEY"] {
            return credValue
        }

        // 3. Config file (for backwards compatibility, but discouraged)
        if let configValue = configuration?.aiProviders?.anthropicApiKey {
            return configValue
        }

        return nil
    }

    /// Get Ollama base URL with proper precedence
    public func getOllamaBaseURL() -> String {
        // Get Ollama base URL with proper precedence
        self.getValue(
            cliValue: nil as String?,
            envVar: "PEEKABOO_OLLAMA_BASE_URL",
            configValue: self.configuration?.aiProviders?.ollamaBaseUrl,
            defaultValue: "http://localhost:11434")
    }

    /// Get default save path with proper precedence
    public func getDefaultSavePath(cliValue: String? = nil) -> String {
        // Get default save path with proper precedence
        let path = self.getValue(
            cliValue: cliValue,
            envVar: "PEEKABOO_DEFAULT_SAVE_PATH",
            configValue: self.configuration?.defaults?.savePath,
            defaultValue: "~/Desktop")
        return NSString(string: path).expandingTildeInPath
    }

    /// Get log level with proper precedence
    public func getLogLevel() -> String {
        // Get log level with proper precedence
        self.getValue(
            cliValue: nil as String?,
            envVar: "PEEKABOO_LOG_LEVEL",
            configValue: self.configuration?.logging?.level,
            defaultValue: "info")
    }

    /// Get log path with proper precedence
    public func getLogPath() -> String {
        // Get log path with proper precedence
        let path = self.getValue(
            cliValue: nil as String?,
            envVar: "PEEKABOO_LOG_PATH",
            configValue: self.configuration?.logging?.path,
            defaultValue: "~/.peekaboo/logs/peekaboo.log")
        return NSString(string: path).expandingTildeInPath
    }

    /// Create default configuration file
    public func createDefaultConfiguration() throws {
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        try ConfigurationDefaults.configurationTemplate.write(
            to: URL(fileURLWithPath: Self.configPath),
            atomically: true,
            encoding: .utf8)

        // Create a sample credentials file if it doesn't exist
        if !FileManager.default.fileExists(atPath: Self.credentialsPath) {
            try ConfigurationDefaults.sampleCredentials.write(
                to: URL(fileURLWithPath: Self.credentialsPath),
                atomically: true,
                encoding: .utf8)

            // Set proper permissions
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: Self.credentialsPath)
        }
    }

    /// Set or update a credential
    public func setCredential(key: String, value: String) throws {
        // Load existing credentials first
        self.loadCredentials()

        // Update
        try self.saveCredentials([key: value])
    }

    /// Get selected AI provider
    public func getSelectedProvider() -> String {
        // Extract provider from providers string (e.g., "anthropic/model" -> "anthropic")
        let providers = self.getAIProviders()
        return self.parseFirstProvider(providers) ?? "anthropic"
    }

    private func parseFirstProvider(_ providers: String) -> String? {
        let components = providers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstProvider = components.first else { return nil }
        let parts = firstProvider.split(separator: "/")
        return parts.first.map(String.init)
    }

    /// Get agent model
    public func getAgentModel() -> String? {
        // Get agent model
        self.configuration?.agent?.defaultModel
    }

    /// Get agent temperature
    public func getAgentTemperature() -> Double {
        // Get agent temperature
        self.getValue(
            cliValue: nil as Double?,
            envVar: nil,
            configValue: self.configuration?.agent?.temperature,
            defaultValue: 0.7)
    }

    /// Get agent max tokens
    public func getAgentMaxTokens() -> Int {
        // Get agent max tokens
        self.getValue(
            cliValue: nil as Int?,
            envVar: nil,
            configValue: self.configuration?.agent?.maxTokens,
            defaultValue: 16384)
    }

    /// Update configuration file with new values
    public func updateConfiguration(_ updates: (inout Configuration) -> Void) throws {
        // Load current configuration or create new one
        var config = self.configuration ?? Configuration()

        // Apply updates
        updates(&config)

        // Save updated configuration
        let data = try JSONCoding.encoder.encode(config)

        // Create directory if needed
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        // Write file
        try data.write(to: URL(fileURLWithPath: Self.configPath), options: .atomic)

        // Reload configuration
        self.configuration = config
    }

    /// Test method to verify module interface
    public func testMethod() -> String {
        // Test method to verify module interface
        "test"
    }

    // MARK: - MCP Client Configuration

    /// Get MCP client servers dictionary
    public func getMCPClientServers() -> [String: Configuration.MCPClientConfig] {
        // Get MCP client servers dictionary
        self.getConfiguration()?.mcpClients ?? [:]
    }

    /// Initialize MCP client with Peekaboo defaults and user overrides via TachikomaMCP
    public func initializeMCPClient() async {
        // TEMPORARILY DISABLED: MCP servers for debugging Grok issues (too many tools)
        // Register Peekaboo's default Chrome DevTools MCP as a host default
        // let defaultChromeDevTools = TachikomaMCP.MCPServerConfig(
        //     transport: "stdio",
        //     command: "npx",
        //     args: ["-y", "chrome-devtools-mcp@latest"],
        //     env: [:],
        //     enabled: true,
        //     timeout: 15.0,
        //     autoReconnect: true,
        //     description: "Chrome DevTools automation"
        // )
        // await TachikomaMCPClientManager.shared.registerDefaultServers(["chrome-devtools": defaultChromeDevTools])

        // Let TachikomaMCP handle parsing ~/.peekaboo/config.json and merging overrides
        // await TachikomaMCPClientManager.shared.initializeFromProfile()
    }

    /// Persist current MCP client configurations back to ~/.peekaboo/config.json
    @MainActor
    public func persistMCPClientConfigs() throws {
        try TachikomaMCPClientManager.shared.persist()
    }
}

// MARK: - Custom Provider Management

extension ConfigurationManager {
    public func addCustomProvider(_ provider: Configuration.CustomProvider, id: String) throws {
        var config = self.loadConfiguration() ?? Configuration()
        if config.customProviders == nil {
            config.customProviders = [:]
        }
        config.customProviders?[id] = provider
        try self.saveConfiguration(config)
        self.configuration = config
    }

    public func removeCustomProvider(id: String) throws {
        var config = self.loadConfiguration() ?? Configuration()
        config.customProviders?.removeValue(forKey: id)
        if config.customProviders?.isEmpty == true {
            config.customProviders = nil
        }
        try self.saveConfiguration(config)
        self.configuration = config
    }

    public func getCustomProvider(id: String) -> Configuration.CustomProvider? {
        self.loadConfiguration()?.customProviders?[id]
    }

    public func listCustomProviders() -> [String: Configuration.CustomProvider] {
        self.loadConfiguration()?.customProviders ?? [:]
    }

    public func testCustomProvider(id: String) async -> (success: Bool, error: String?) {
        guard let provider = getCustomProvider(id: id) else {
            return (false, "Provider '\(id)' not found")
        }

        guard let apiKey = resolveCredential(provider.options.apiKey) else {
            return (false, "API key not found or invalid: \(provider.options.apiKey)")
        }

        do {
            switch provider.type {
            case .openai:
                return try await self.testOpenAICompatibleProvider(provider: provider, apiKey: apiKey)
            case .anthropic:
                return try await self.testAnthropicCompatibleProvider(provider: provider, apiKey: apiKey)
            }
        } catch {
            return (false, "Connection test failed: \(error.localizedDescription)")
        }
    }

    public func discoverModelsForCustomProvider(id: String) async -> (models: [String], error: String?) {
        guard let provider = getCustomProvider(id: id) else {
            return ([], "Provider '\(id)' not found")
        }

        guard let apiKey = resolveCredential(provider.options.apiKey) else {
            return ([], "API key not found: \(provider.options.apiKey)")
        }

        do {
            switch provider.type {
            case .openai:
                return try await self.discoverOpenAICompatibleModels(provider: provider, apiKey: apiKey)
            case .anthropic:
                let configuredModels = provider.models?.keys.map { String($0) } ?? []
                return (configuredModels, nil)
            }
        } catch {
            return ([], "Model discovery failed: \(error.localizedDescription)")
        }
    }
}

extension ConfigurationManager {
    private func saveConfiguration(_ config: Configuration) throws {
        let encoder = JSONCoding.encoder
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try data.write(to: URL(fileURLWithPath: Self.configPath), options: .atomic)
    }

    private func resolveCredential(_ reference: String) -> String? {
        guard reference.hasPrefix("{env:"), reference.hasSuffix("}") else {
            return reference
        }

        let varName = String(reference.dropFirst(5).dropLast(1))
        if let envValue = self.environmentValue(for: varName) {
            return envValue
        }
        if let credValue = credentials[varName] {
            return credValue
        }
        return nil
    }

    private func testOpenAICompatibleProvider(
        provider: Configuration.CustomProvider,
        apiKey: String) async throws -> (success: Bool, error: String?)
    {
        let url = URL(string: "\(provider.options.baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        provider.options.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return (false, "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            return (false, errorMessage)
        }

        return (true, nil)
    }

    private func testAnthropicCompatibleProvider(
        provider: Configuration.CustomProvider,
        apiKey: String) async throws -> (success: Bool, error: String?)
    {
        let url = URL(string: "\(provider.options.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        provider.options.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let testPayload: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [["role": "user", "content": "Hi"]],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return (false, "Invalid response")
        }

        if httpResponse.statusCode < 500 {
            return (true, nil)
        }

        let errorMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
        return (false, errorMessage)
    }

    private func discoverOpenAICompatibleModels(
        provider: Configuration.CustomProvider,
        apiKey: String) async throws -> (models: [String], error: String?)
    {
        let url = URL(string: "\(provider.options.baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        provider.options.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return ([], "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            return ([], errorMessage)
        }

        struct ModelsResponse: Codable {
            let data: [ModelInfo]

            struct ModelInfo: Codable { let id: String }
        }

        do {
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            return (response.data.map(\.id), nil)
        } catch {
            return ([], "Failed to parse models response: \(error.localizedDescription)")
        }
    }

    private func environmentValue(for key: String) -> String? {
        guard let rawValue = getenv(key) else {
            return nil
        }
        return String(cString: rawValue)
    }
}

// MARK: - Helper Types

private struct JSONCommentStripper {
    private let characters: [Character]
    private var index: Int = 0
    private var result = ""
    private var inString = false
    private var escapeNext = false
    private var singleLineComment = false
    private var multiLineComment = false

    init(json: String) {
        self.characters = Array(json)
    }

    mutating func strip() -> String {
        while self.index < self.characters.count {
            let char = self.characters[self.index]
            let next = self.peek()

            if self.handleEscape(char) { continue }
            if self.handleQuote(char) { continue }
            if self.inString {
                self.append(char)
                self.advance()
                continue
            }
            if self.handleCommentStart(char, next) { continue }
            if self.handleCommentEnd(char, next) { continue }
            self.appendIfNeeded(char)
            self.advance()
        }

        return self.result
    }

    private mutating func handleEscape(_ char: Character) -> Bool {
        if self.escapeNext {
            self.append(char)
            self.escapeNext = false
            self.advance()
            return true
        }

        if char == "\\", self.inString {
            self.escapeNext = true
            self.append(char)
            self.advance()
            return true
        }

        return false
    }

    private mutating func handleQuote(_ char: Character) -> Bool {
        guard char == "\"", !self.singleLineComment, !self.multiLineComment else { return false }
        self.inString.toggle()
        self.append(char)
        self.advance()
        return true
    }

    private mutating func handleCommentStart(_ char: Character, _ next: Character?) -> Bool {
        if char == "/", next == "/", !self.multiLineComment {
            self.singleLineComment = true
            self.advance(by: 2)
            return true
        }

        if char == "/", next == "*", !self.singleLineComment {
            self.multiLineComment = true
            self.advance(by: 2)
            return true
        }

        return false
    }

    private mutating func handleCommentEnd(_ char: Character, _ next: Character?) -> Bool {
        if char == "\n", self.singleLineComment {
            self.singleLineComment = false
            self.append(char)
            self.advance()
            return true
        }

        if char == "*", next == "/", self.multiLineComment {
            self.multiLineComment = false
            self.advance(by: 2)
            return true
        }

        return false
    }

    private mutating func appendIfNeeded(_ char: Character) {
        guard !self.singleLineComment, !self.multiLineComment else { return }
        self.append(char)
    }

    private mutating func append(_ char: Character) {
        self.result.append(char)
    }

    private mutating func advance(by value: Int = 1) {
        self.index += value
    }

    private func peek() -> Character? {
        (self.index + 1) < self.characters.count ? self.characters[self.index + 1] : nil
    }
}

private enum ConfigurationDefaults {
    static let configurationTemplate = """
    {
      "aiProviders": {
        "providers": "openai/gpt-5.1,anthropic/claude-sonnet-4.5"
      },
      "mcpClients": {},
      "defaults": {
        "savePath": "~/Desktop/Screenshots",
        "imageFormat": "png",
        "captureMode": "window",
        "captureFocus": "auto"
      },
      "logging": {
        "level": "info",
        "path": "~/.peekaboo/logs/peekaboo.log"
      }
    }
    """

    static let sampleCredentials = """
    # Peekaboo credentials file
    # This file contains sensitive API keys and should not be shared
    #
    # Example:
    # OPENAI_API_KEY=sk-...
    # ANTHROPIC_API_KEY=sk-ant-...
    """
}
