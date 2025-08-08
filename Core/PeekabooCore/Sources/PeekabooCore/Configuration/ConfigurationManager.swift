import Foundation
import Tachikoma

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

    private init() {
        // Load configuration on init, but don't crash if it fails
        _ = self.loadConfiguration()
    }

    /// Migrate from legacy configuration if needed
    public func migrateIfNeeded() throws {
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

            print("✅ Migrated configuration from \(Self.legacyConfigPath) to \(Self.configPath)")
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
        if self.configuration == nil {
            _ = self.loadConfiguration()
        }
        return self.configuration
    }

    /// Load configuration from a specific path
    private func loadConfigurationFromPath(_ configPath: String) -> Configuration? {
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
                print(
                    "Warning: JSON key not found '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
            case let .typeMismatch(type, context):
                print(
                    "Warning: Type mismatch for type '\(type)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
            case let .valueNotFound(type, context):
                print(
                    "Warning: Value not found for type '\(type)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
            case let .dataCorrupted(context):
                print(
                    "Warning: Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                if let underlyingError = context.underlyingError {
                    print("Underlying error: \(underlyingError)")
                }
            @unknown default:
                print("Warning: Unknown decoding error: \(error)")
            }

            // For debugging, print the cleaned JSON
            if expandedJSON.count < 5000 { // Only print if reasonably sized
                print("Cleaned JSON that failed to parse:")
                print(expandedJSON)
            }
        } catch {
            print("Warning: Failed to load configuration from \(configPath): \(error)")
        }

        return nil
    }

    /// Load credentials from file
    private func loadCredentials() {
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
        // Merge with existing credentials
        for (key, value) in newCredentials {
            self.credentials[key] = value
        }

        // Create directory if needed
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        // Build credentials file content
        var lines: [String] = []
        lines.append("# Peekaboo credentials file")
        lines.append("# This file contains sensitive API keys and should not be shared")
        lines.append("")

        for (key, value) in self.credentials.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key)=\(value)")
        }

        let content = lines.joined(separator: "\n")

        // Write file with restricted permissions
        try content.write(
            to: URL(fileURLWithPath: Self.credentialsPath),
            atomically: true,
            encoding: .utf8)

        // Set file permissions to 600 (readable/writable by owner only)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.credentialsPath)
    }

    /// Strip comments from JSONC content
    public func stripJSONComments(from json: String) -> String {
        var result = ""
        var inString = false
        var escapeNext = false
        var inSingleLineComment = false
        var inMultiLineComment = false

        let characters = Array(json)
        var i = 0

        while i < characters.count {
            let char = characters[i]
            let nextChar = i + 1 < characters.count ? characters[i + 1] : nil

            // Handle escape sequences
            if escapeNext {
                if !inSingleLineComment, !inMultiLineComment {
                    result.append(char)
                }
                escapeNext = false
                i += 1
                continue
            }

            // Check for escape character
            if char == "\\", inString {
                escapeNext = true
                if !inSingleLineComment, !inMultiLineComment {
                    result.append(char)
                }
                i += 1
                continue
            }

            // Handle string boundaries
            if char == "\"", !inSingleLineComment, !inMultiLineComment {
                inString.toggle()
                result.append(char)
                i += 1
                continue
            }

            // Inside string, keep everything
            if inString {
                result.append(char)
                i += 1
                continue
            }

            // Check for comment start
            if char == "/", nextChar == "/", !inMultiLineComment {
                inSingleLineComment = true
                i += 2
                continue
            }

            if char == "/", nextChar == "*", !inSingleLineComment {
                inMultiLineComment = true
                i += 2
                continue
            }

            // Check for comment end
            if char == "\n", inSingleLineComment {
                inSingleLineComment = false
                result.append(char)
                i += 1
                continue
            }

            if char == "*", nextChar == "/", inMultiLineComment {
                inMultiLineComment = false
                i += 2
                continue
            }

            // Add character if not in comment
            if !inSingleLineComment, !inMultiLineComment {
                result.append(char)
            }

            i += 1
        }

        return result
    }

    /// Expand environment variables in the format ${VAR_NAME}
    public func expandEnvironmentVariables(in text: String) -> String {
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
                    if let value = ProcessInfo.processInfo.environment[varName],
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
           let envValue = ProcessInfo.processInfo.environment[envVar]
        {
            // Try to convert string to the expected type
            if T.self == String.self {
                return envValue as! T
            } else if T.self == Bool.self {
                return (envValue.lowercased() == "true" || envValue == "1") as! T
            } else if T.self == Int.self {
                if let intValue = Int(envValue) {
                    return intValue as! T
                }
            } else if T.self == Double.self {
                if let doubleValue = Double(envValue) {
                    return doubleValue as! T
                }
            }
            // For other types, we can't convert from string, so fall through
        }

        // Config file value takes third precedence
        if let configValue {
            return configValue
        }

        // Default value as fallback
        return defaultValue
    }

    /// Get AI providers with proper precedence
    public func getAIProviders(cliValue: String? = nil) -> String {
        self.getValue(
            cliValue: cliValue,
            envVar: "PEEKABOO_AI_PROVIDERS",
            configValue: self.configuration?.aiProviders?.providers,
            defaultValue: "openai/gpt-5,ollama/llava:latest,anthropic/claude-opus-4-20250514")
    }

    /// Get OpenAI API key with proper precedence
    public func getOpenAIAPIKey() -> String? {
        // 1. Environment variable (highest priority)
        if let envValue = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
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
        if let envValue = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
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

    /// Create default configuration file
    public func createDefaultConfiguration() throws {
        let configPath = Self.configPath

        // Create directory with proper permissions
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        let defaultConfig = """
        {
          // AI Provider Settings
          "aiProviders": {
            // Comma-separated list of AI providers in order of preference
            // Format: "provider/model,provider/model"
            // Supported providers: openai, anthropic, ollama
            "providers": "anthropic/claude-opus-4-20250514,openai/gpt-4.1,ollama/llava:latest",

            // NOTE: API keys should be stored in ~/.peekaboo/credentials
            // or set as environment variables, not in this file

            // Ollama server URL (if not using default)
            // "ollamaBaseUrl": "http://localhost:11434"
          },

          // MCP Client Configuration
          "mcpClients": {
            // External MCP servers to connect to
            // Peekaboo ships with BrowserMCP by default (https://browsermcp.io)
            // To disable the default browser server, add:
            // "browser": {
            //   "transport": "stdio",
            //   "command": "npx", 
            //   "args": ["-y", "@agent-infra/mcp-server-browser@latest"],
            //   "enabled": false,
            //   "timeout": 15.0,
            //   "autoReconnect": true,
            //   "description": "Browser automation via BrowserMCP"
            // }
            
            // Example: Add GitHub MCP server
            // "github": {
            //   "transport": "stdio",
            //   "command": "npx",
            //   "args": ["-y", "@modelcontextprotocol/server-github"],
            //   "enabled": true,
            //   "timeout": 15.0,
            //   "autoReconnect": true,
            //   "description": "GitHub repository integration"
            // }
          },

          // Default Settings for Capture Operations
          "defaults": {
            // Default path for saving screenshots
            "savePath": "~/Desktop/Screenshots",

            // Default image format (png, jpg, jpeg)
            "imageFormat": "png",

            // Default capture mode (window, screen, area)
            "captureMode": "window",

            // Default focus behavior (auto, frontmost, none)
            "captureFocus": "auto"
          },

          // Logging Configuration
          "logging": {
            // Log level (trace, debug, info, warn, error, fatal)
            "level": "info",

            // Log file path
            "path": "~/.peekaboo/logs/peekaboo.log"
          }
        }
        """

        try defaultConfig.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)

        // Create a sample credentials file if it doesn't exist
        if !FileManager.default.fileExists(atPath: Self.credentialsPath) {
            let sampleCredentials = """
            # Peekaboo credentials file
            # This file contains sensitive API keys and should not be shared
            #
            # Example:
            # OPENAI_API_KEY=sk-...
            # ANTHROPIC_API_KEY=sk-ant-...
            """

            try sampleCredentials.write(
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
        "test"
    }
    
    // MARK: - MCP Client Configuration
    
    /// Get MCP client servers dictionary 
    public func getMCPClientServers() -> [String: Configuration.MCPClientConfig] {
        return self.getConfiguration()?.mcpClients ?? [:]
    }
    
    /// Initialize MCP client with default servers
    public func initializeMCPClient() async {
        // Get user-configured servers
        let userServers = getMCPClientServers()
        
        // Initialize default servers through MCPClientManager
        await MCPClientManager.shared.initializeDefaultServers(userConfigs: userServers)
        
        // Add user-configured servers - process each server individually to avoid data race issues
        for (serverName, serverConfig) in userServers {
            do {
                // Create a copy of the config to avoid data race issues
                let configCopy = Configuration.MCPClientConfig(
                    transport: serverConfig.transport,
                    command: serverConfig.command,
                    args: serverConfig.args,
                    env: serverConfig.env,
                    enabled: serverConfig.enabled,
                    timeout: serverConfig.timeout,
                    autoReconnect: serverConfig.autoReconnect,
                    description: serverConfig.description
                )
                try await MCPClientManager.shared.addServer(name: serverName, config: configCopy)
            } catch {
                // Log error but continue with other servers
                print("Warning: Failed to initialize MCP server '\(serverName)': \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Custom Provider Management

    /// Add a custom AI provider to the configuration
    /// - Parameters:
    ///   - provider: The custom provider configuration
    ///   - id: Unique identifier for the provider
    /// - Throws: Configuration errors if save fails
    public func addCustomProvider(_ provider: Configuration.CustomProvider, id: String) throws {
        var config = self.loadConfiguration() ?? Configuration()

        // Initialize customProviders if needed
        if config.customProviders == nil {
            config.customProviders = [:]
        }

        // Add the provider
        config.customProviders?[id] = provider

        // Save configuration
        try self.saveConfiguration(config)

        // Reload in memory
        self.configuration = config
    }

    /// Remove a custom provider from the configuration
    /// - Parameter id: Provider identifier to remove
    /// - Throws: Configuration errors if save fails
    public func removeCustomProvider(id: String) throws {
        var config = self.loadConfiguration() ?? Configuration()

        // Remove the provider if it exists
        config.customProviders?.removeValue(forKey: id)

        // If no providers left, clean up the empty dictionary
        if config.customProviders?.isEmpty == true {
            config.customProviders = nil
        }

        // Save configuration
        try self.saveConfiguration(config)

        // Reload in memory
        self.configuration = config
    }

    /// Get a specific custom provider by ID
    /// - Parameter id: Provider identifier
    /// - Returns: The custom provider if found
    public func getCustomProvider(id: String) -> Configuration.CustomProvider? {
        self.loadConfiguration()?.customProviders?[id]
    }

    /// List all configured custom providers
    /// - Returns: Dictionary of provider ID to provider configuration
    public func listCustomProviders() -> [String: Configuration.CustomProvider] {
        self.loadConfiguration()?.customProviders ?? [:]
    }

    /// Test connection to a custom provider
    /// - Parameter id: Provider identifier to test
    /// - Returns: True if connection successful
    public func testCustomProvider(id: String) async -> (success: Bool, error: String?) {
        guard let provider = getCustomProvider(id: id) else {
            return (false, "Provider '\(id)' not found")
        }

        // Resolve API key from environment
        guard let apiKey = resolveCredential(provider.options.apiKey) else {
            return (false, "API key not found or invalid: \(provider.options.apiKey)")
        }

        // Test basic connection based on provider type
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

    /// Discover available models from a custom provider
    /// - Parameter id: Provider identifier
    /// - Returns: List of available model IDs
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
                // Anthropic doesn't have a models endpoint, return configured models
                let configuredModels = provider.models?.keys.map { String($0) } ?? []
                return (configuredModels, nil)
            }
        } catch {
            return ([], "Model discovery failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helper Methods

    /// Save configuration to disk
    private func saveConfiguration(_ config: Configuration) throws {
        let encoder = JSONCoding.encoder
        let data = try encoder.encode(config)

        // Ensure directory exists
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        // Write file atomically
        try data.write(to: URL(fileURLWithPath: Self.configPath), options: .atomic)
    }

    /// Resolve a credential reference like {env:API_KEY} to actual value
    private func resolveCredential(_ reference: String) -> String? {
        // Handle {env:VAR_NAME} format
        if reference.hasPrefix("{env:"), reference.hasSuffix("}") {
            let varName = String(reference.dropFirst(5).dropLast(1))

            // Try environment variable first
            if let envValue = ProcessInfo.processInfo.environment[varName] {
                return envValue
            }

            // Try credentials file
            if let credValue = credentials[varName] {
                return credValue
            }

            return nil
        }

        // Return as-is if not an environment reference
        return reference
    }

    /// Test OpenAI-compatible provider connection
    private func testOpenAICompatibleProvider(
        provider: Configuration.CustomProvider,
        apiKey: String) async throws -> (success: Bool, error: String?)
    {
        let url = URL(string: "\(provider.options.baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        provider.options.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return (false, "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            return (true, nil)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            return (false, errorMessage)
        }
    }

    /// Test Anthropic-compatible provider connection
    private func testAnthropicCompatibleProvider(
        provider: Configuration.CustomProvider,
        apiKey: String) async throws -> (success: Bool, error: String?)
    {
        // For Anthropic-compatible providers, we'll try a simple message request
        let url = URL(string: "\(provider.options.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Add custom headers
        provider.options.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let testPayload: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hi"],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return (false, "Invalid response")
        }

        // Accept both success (200) and client errors (400s) as "connection working"
        // since we're just testing connectivity, not actual API functionality
        if httpResponse.statusCode < 500 {
            return (true, nil)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            return (false, errorMessage)
        }
    }

    /// Discover models from OpenAI-compatible provider
    private func discoverOpenAICompatibleModels(
        provider: Configuration.CustomProvider,
        apiKey: String) async throws -> (models: [String], error: String?)
    {
        let url = URL(string: "\(provider.options.baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
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

        // Parse OpenAI models response format
        struct ModelsResponse: Codable {
            let data: [ModelInfo]

            struct ModelInfo: Codable {
                let id: String
            }
        }

        do {
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let modelIds = response.data.map(\.id)
            return (modelIds, nil)
        } catch {
            return ([], "Failed to parse models response: \(error.localizedDescription)")
        }
    }
}
