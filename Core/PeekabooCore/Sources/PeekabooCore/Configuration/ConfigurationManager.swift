import Foundation

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
        _ = loadConfiguration()
    }
    
    /// Migrate from legacy configuration if needed
    public func migrateIfNeeded() throws {
        let fileManager = FileManager.default
        
        // Check if legacy config exists but new config doesn't
        if fileManager.fileExists(atPath: Self.legacyConfigPath) && 
           !fileManager.fileExists(atPath: Self.configPath) {
            
            // Create new base directory
            try fileManager.createDirectory(
                atPath: Self.baseDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            
            // Copy config file
            try fileManager.copyItem(
                atPath: Self.legacyConfigPath,
                toPath: Self.configPath
            )
            
            // Load the config to extract any API keys
            if let config = loadConfigurationFromPath(Self.configPath) {
                var credentialsToSave: [String: String] = [:]
                
                // Extract OpenAI API key if it's hardcoded (not an env var reference)
                if let apiKey = config.aiProviders?.openaiApiKey,
                   !apiKey.hasPrefix("${"),
                   !apiKey.isEmpty {
                    credentialsToSave["OPENAI_API_KEY"] = apiKey
                }
                
                // Save credentials if any were found
                if !credentialsToSave.isEmpty {
                    try saveCredentials(credentialsToSave)
                    
                    // Remove hardcoded API key from config and update it
                    var updatedConfig = config
                    if updatedConfig.aiProviders?.openaiApiKey != nil {
                        updatedConfig.aiProviders?.openaiApiKey = nil
                    }
                    
                    // Save updated config without hardcoded credentials
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted]
                    let data = try encoder.encode(updatedConfig)
                    try data.write(to: URL(fileURLWithPath: Self.configPath))
                }
            }
            
            print("✅ Migrated configuration from \(Self.legacyConfigPath) to \(Self.configPath)")
        }
    }

    /// Load configuration from file
    public func loadConfiguration() -> Configuration? {
        // Try migration first
        try? migrateIfNeeded()
        
        // Load credentials
        loadCredentials()
        
        // Load configuration
        configuration = loadConfigurationFromPath(Self.configPath)
        return configuration
    }
    
    /// Get the current configuration.
    ///
    /// Returns the loaded configuration or loads it if not already loaded.
    public func getConfiguration() -> Configuration? {
        if configuration == nil {
            _ = loadConfiguration()
        }
        return configuration
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
                let config = try JSONDecoder().decode(Configuration.self, from: expandedData)
                self.configuration = config
                return config
            }
        } catch let error as DecodingError {
            // Provide more detailed error information for JSON decoding errors
            switch error {
            case .keyNotFound(let key, let context):
                print("Warning: JSON key not found '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .typeMismatch(let type, let context):
                print("Warning: Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                print("Warning: Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                print("Warning: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                if let underlyingError = context.underlyingError {
                    print("Underlying error: \(underlyingError)")
                }
            @unknown default:
                print("Warning: Unknown decoding error: \(error)")
            }
            
            // For debugging, print the cleaned JSON
            if expandedJSON.count < 5000 {  // Only print if reasonably sized
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
                    let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty && !value.isEmpty {
                        credentials[key] = value
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
            credentials[key] = value
        }
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        
        // Build credentials file content
        var lines: [String] = []
        lines.append("# Peekaboo credentials file")
        lines.append("# This file contains sensitive API keys and should not be shared")
        lines.append("")
        
        for (key, value) in credentials.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key)=\(value)")
        }
        
        let content = lines.joined(separator: "\n")
        
        // Write file with restricted permissions
        try content.write(
            to: URL(fileURLWithPath: Self.credentialsPath),
            atomically: true,
            encoding: .utf8
        )
        
        // Set file permissions to 600 (readable/writable by owner only)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.credentialsPath
        )
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
            defaultValue: "ollama/llava:latest")
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
            attributes: [.posixPermissions: 0o700]
        )

        let defaultConfig = """
        {
          // AI Provider Settings
          "aiProviders": {
            // Comma-separated list of AI providers in order of preference
            // Format: "provider/model,provider/model"
            // Supported providers: openai, ollama
            "providers": "openai/gpt-4o,ollama/llava:latest",
            
            // NOTE: API keys should be stored in ~/.peekaboo/credentials
            // or set as environment variables, not in this file

            // Ollama server URL (if not using default)
            // "ollamaBaseUrl": "http://localhost:11434"
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
                encoding: .utf8
            )
            
            // Set proper permissions
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: Self.credentialsPath
            )
        }
    }
    
    /// Set or update a credential
    public func setCredential(key: String, value: String) throws {
        // Load existing credentials first
        loadCredentials()
        
        // Update
        try saveCredentials([key: value])
    }
}