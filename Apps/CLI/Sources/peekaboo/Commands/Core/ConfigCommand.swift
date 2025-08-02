import ArgumentParser
import Foundation
import PeekabooCore

/// Manage Peekaboo configuration files and settings
@available(macOS 14.0, *)
struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage Peekaboo configuration",
        discussion: """
        The config command helps you manage Peekaboo's configuration files.

        Configuration locations:
        • Config file: ~/.peekaboo/config.json
        • Credentials: ~/.peekaboo/credentials

        The configuration file uses JSONC format (JSON with Comments) and supports:
        • Comments using // and /* */
        • Environment variable expansion using ${VAR_NAME}
        • Tilde expansion for home directories

        Configuration precedence (highest to lowest):
        1. Command-line arguments
        2. Environment variables
        3. Credentials file (for API keys)
        4. Configuration file
        5. Built-in defaults

        API keys should be stored in the credentials file or set as environment variables,
        not in the configuration file.
        """,
        subcommands: [
            InitCommand.self,
            ShowCommand.self,
            EditCommand.self,
            ValidateCommand.self,
            SetCredentialCommand.self,
            AddProviderCommand.self,
            ListProvidersCommand.self,
            TestProviderCommand.self,
            RemoveProviderCommand.self,
            ModelsProviderCommand.self,
        ]
    )

    /// Subcommand to create a default configuration file
    struct InitCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Create a default configuration file"
        )

        @Flag(name: .long, help: "Force overwrite existing configuration")
        var force = false

        @Flag(name: .long, help: "Output JSON data for programmatic use")
        var jsonOutput = false

        mutating func run() async throws {
            let configPath = ConfigurationManager.configPath
            let configExists = FileManager.default.fileExists(atPath: configPath)

            if configExists, !self.force {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: "Configuration file already exists. Use --force to overwrite.",
                        details: "Path: \(configPath)"
                    )
                    outputJSON(errorOutput)
                } else {
                    print("Configuration file already exists at: \(configPath)")
                    print("Use --force to overwrite.")
                }
                throw ExitCode.failure
            }

            do {
                try ConfigurationManager.shared.createDefaultConfiguration()

                if self.jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "message": "Configuration file created successfully",
                            "path": configPath,
                        ]
                    )
                    outputJSON(successOutput)
                } else {
                    print("✅ Configuration file created at: \(configPath)")
                    print("\nYou can now edit it to customize your settings.")
                    print("Use 'peekaboo config edit' to open it in your default editor.")
                }
            } catch {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: error.localizedDescription,
                        details: "Path: \(configPath)"
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Failed to create configuration file: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to display current configuration
    struct ShowCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Display current configuration"
        )

        @Flag(name: .long, help: "Show effective configuration (merged with environment)")
        var effective = false

        @Flag(name: .long, help: "Output JSON data for programmatic use")
        var jsonOutput = false

        mutating func run() async throws {
            let configPath = ConfigurationManager.configPath
            let manager = ConfigurationManager.shared

            if !self.effective {
                // Show raw configuration file
                if !FileManager.default.fileExists(atPath: configPath) {
                    if self.jsonOutput {
                        let errorOutput = ErrorOutput(
                            error: true,
                            code: "FILE_IO_ERROR",
                            message: "No configuration file found",
                            details: "Path: \(configPath). Run 'peekaboo config init' to create one."
                        )
                        outputJSON(errorOutput)
                    } else {
                        print("No configuration file found at: \(configPath)")
                        print("Run 'peekaboo config init' to create one.")
                    }
                    throw ExitCode.failure
                }

                do {
                    let contents = try String(contentsOfFile: configPath)
                    if self.jsonOutput {
                        // For JSON output, parse and re-encode to ensure valid JSON
                        if let config = manager.loadConfiguration() {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            let data = try encoder.encode(config)
                            print(String(data: data, encoding: .utf8)!)
                        } else {
                            let errorOutput = ErrorOutput(
                                error: true,
                                code: "FILE_IO_ERROR",
                                message: "Failed to parse configuration file",
                                details: nil
                            )
                            outputJSON(errorOutput)
                            throw ExitCode.failure
                        }
                    } else {
                        print(contents)
                    }
                } catch {
                    if self.jsonOutput {
                        let errorOutput = ErrorOutput(
                            error: true,
                            code: "FILE_IO_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        )
                        outputJSON(errorOutput)
                    } else {
                        print("Failed to read configuration file: \(error)")
                    }
                    throw ExitCode.failure
                }
            } else {
                // Show effective configuration
                _ = manager.loadConfiguration()

                let credentialsPath = ConfigurationManager.credentialsPath
                let effectiveConfig: [String: Any] = [
                    "aiProviders": [
                        "providers": manager.getAIProviders(),
                        "openaiApiKey": manager.getOpenAIAPIKey() != nil ? "***SET***" : "NOT SET",
                        "ollamaBaseUrl": manager.getOllamaBaseURL(),
                    ],
                    "defaults": [
                        "savePath": manager.getDefaultSavePath(),
                    ],
                    "logging": [
                        "level": manager.getLogLevel(),
                        "path": manager.getLogPath(),
                    ],
                    "configFile": FileManager.default.fileExists(atPath: configPath) ? configPath : "NOT FOUND",
                    "credentialsFile": FileManager.default
                        .fileExists(atPath: credentialsPath) ? credentialsPath : "NOT FOUND",
                ]

                if self.jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: effectiveConfig
                    )
                    outputJSON(successOutput)
                } else {
                    print("Effective Configuration (after merging all sources):")
                    print(String(repeating: "=", count: 50))
                    print()
                    print("AI Providers:")
                    print("  Providers: \(manager.getAIProviders())")
                    print("  OpenAI API Key: \(manager.getOpenAIAPIKey() != nil ? "***SET***" : "NOT SET")")
                    print("  Ollama Base URL: \(manager.getOllamaBaseURL())")
                    print()
                    print("Defaults:")
                    print("  Save Path: \(manager.getDefaultSavePath())")
                    print()
                    print("Logging:")
                    print("  Level: \(manager.getLogLevel())")
                    print("  Path: \(manager.getLogPath())")
                    print()
                    print("Files:")
                    print(
                        "  Config File: \(FileManager.default.fileExists(atPath: configPath) ? configPath : "NOT FOUND")"
                    )
                    print(
                        "  Credentials: \(FileManager.default.fileExists(atPath: credentialsPath) ? credentialsPath : "NOT FOUND")"
                    )
                }
            }
        }
    }

    /// Subcommand to open configuration in an editor
    struct EditCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "edit",
            abstract: "Open configuration file in your default editor"
        )

        @Option(name: .long, help: "Editor to use (defaults to $EDITOR or nano)")
        var editor: String?

        @Flag(name: .long, help: "Output JSON data for programmatic use")
        var jsonOutput = false

        mutating func run() async throws {
            let configPath = ConfigurationManager.configPath
            let manager = ConfigurationManager.shared

            // Create config if it doesn't exist
            if !FileManager.default.fileExists(atPath: configPath) {
                if self.jsonOutput {
                    let data: [String: Any] = [
                        "message": "Creating default configuration file",
                        "path": configPath,
                    ]
                    let successOutput = SuccessOutput(success: true, data: data)
                    outputJSON(successOutput)
                } else {
                    print("No configuration file found. Creating default configuration...")
                }

                try manager.createDefaultConfiguration()
            }

            // Determine editor
            let editorCommand = self.editor ?? ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"

            // Open editor
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editorCommand, configPath]

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    if self.jsonOutput {
                        let data: [String: Any] = [
                            "message": "Configuration edited successfully",
                            "editor": editorCommand,
                            "path": configPath,
                        ]
                        let successOutput = SuccessOutput(success: true, data: data)
                        outputJSON(successOutput)
                    } else {
                        print("✅ Configuration saved.")

                        // Validate the edited configuration
                        if let _ = manager.loadConfiguration() {
                            print("✅ Configuration is valid.")
                        } else {
                            print("⚠️  Warning: Configuration may have errors. Run 'peekaboo config validate' to check.")
                        }
                    }
                } else {
                    if self.jsonOutput {
                        let errorOutput = ErrorOutput(
                            error: true,
                            code: "UNKNOWN_ERROR",
                            message: "Editor exited with non-zero status: \(process.terminationStatus)",
                            details: "Editor: \(editorCommand)"
                        )
                        outputJSON(errorOutput)
                    } else {
                        print("Editor exited with status: \(process.terminationStatus)")
                    }
                    throw ExitCode.failure
                }
            } catch {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "UNKNOWN_ERROR",
                        message: error.localizedDescription,
                        details: "Editor: \(editorCommand)"
                    )
                    outputJSON(errorOutput)
                } else {
                    print("Failed to open editor: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to validate configuration syntax
    struct ValidateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "validate",
            abstract: "Validate configuration file syntax"
        )

        @Flag(name: .long, help: "Output JSON data for programmatic use")
        var jsonOutput = false

        mutating func run() async throws {
            let configPath = ConfigurationManager.configPath

            if !FileManager.default.fileExists(atPath: configPath) {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: "No configuration file found",
                        details: "Path: \(configPath). Run 'peekaboo config init' to create one."
                    )
                    outputJSON(errorOutput)
                } else {
                    print("No configuration file found at: \(configPath)")
                    print("Run 'peekaboo config init' to create one.")
                }
                throw ExitCode.failure
            }

            // Try to load and validate
            if let config = ConfigurationManager.shared.loadConfiguration() {
                if self.jsonOutput {
                    let data: [String: Any] = [
                        "valid": true,
                        "message": "Configuration is valid",
                        "path": configPath,
                        "hasAIProviders": config.aiProviders != nil,
                        "hasDefaults": config.defaults != nil,
                        "hasLogging": config.logging != nil,
                    ]
                    let successOutput = SuccessOutput(success: true, data: data)
                    outputJSON(successOutput)
                } else {
                    print("✅ Configuration is valid!")
                    print()
                    print("Detected sections:")
                    if config.aiProviders != nil { print("  ✓ AI Providers") }
                    if config.defaults != nil { print("  ✓ Defaults") }
                    if config.logging != nil { print("  ✓ Logging") }
                }
            } else {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: "Failed to parse configuration file. Check for syntax errors.",
                        details: "Path: \(configPath). Common issues: trailing commas, unclosed comments, invalid JSON syntax."
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Configuration is invalid!")
                    print()
                    print("Common issues:")
                    print("  • Trailing commas in JSON")
                    print("  • Unclosed comments")
                    print("  • Invalid JSON syntax")
                    print()
                    print("Run 'peekaboo config show' to view the raw file.")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to set credentials securely
    struct SetCredentialCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set-credential",
            abstract: "Set an API key or credential securely"
        )

        @Argument(help: "The credential name (e.g., OPENAI_API_KEY)")
        var key: String

        @Argument(help: "The credential value")
        var value: String

        @Flag(name: .long, help: "Output JSON data for programmatic use")
        var jsonOutput = false

        mutating func run() async throws {
            do {
                try ConfigurationManager.shared.setCredential(key: self.key, value: self.value)

                if self.jsonOutput {
                    let data: [String: Any] = [
                        "message": "Credential set successfully",
                        "key": key,
                        "path": ConfigurationManager.credentialsPath,
                    ]
                    let successOutput = SuccessOutput(success: true, data: data)
                    outputJSON(successOutput)
                } else {
                    print("✅ Credential '\(self.key)' set successfully.")
                    print("Stored in: \(ConfigurationManager.credentialsPath)")
                }
            } catch {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: error.localizedDescription,
                        details: "Failed to save credential"
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Failed to set credential: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }
    
    // MARK: - Custom Provider Management Commands
    
    /// Subcommand to add a custom AI provider
    struct AddProviderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add-provider",
            abstract: "Add a custom AI provider",
            discussion: """
            Add a custom AI provider to your Peekaboo configuration.
            
            This allows you to connect to OpenAI-compatible or Anthropic-compatible
            endpoints beyond the built-in providers.
            
            Examples:
            
            # Add OpenRouter
            peekaboo config add-provider openrouter \\
              --type openai \\
              --name "OpenRouter" \\
              --base-url "https://openrouter.ai/api/v1" \\
              --api-key "{env:OPENROUTER_API_KEY}" \\
              --description "Access to 300+ models via OpenRouter"
            
            # Add local Ollama with authentication
            peekaboo config add-provider local-ollama \\
              --type openai \\
              --name "Local Ollama" \\
              --base-url "http://localhost:11434/v1" \\
              --api-key "dummy-key"
            
            # Add Groq
            peekaboo config add-provider groq \\
              --type openai \\
              --name "Groq" \\
              --base-url "https://api.groq.com/openai/v1" \\
              --api-key "{env:GROQ_API_KEY}"
            """
        )
        
        @Argument(help: "Unique identifier for the provider (letters, numbers, hyphens only)")
        var providerId: String
        
        @Option(name: .long, help: "Provider type (openai or anthropic)")
        var type: String
        
        @Option(name: .long, help: "Human-readable name for the provider")
        var name: String
        
        @Option(name: .long, help: "Base URL for the API endpoint")
        var baseUrl: String
        
        @Option(name: .long, help: "API key or credential reference (e.g., {env:API_KEY})")
        var apiKey: String
        
        @Option(name: .long, help: "Optional description of the provider")
        var description: String?
        
        @Option(name: .long, help: "Additional HTTP headers (key:value,key:value)")
        var headers: String?
        
        @Flag(name: .long, help: "Enable JSON output")
        var jsonOutput: Bool = false
        
        @Flag(name: .long, help: "Overwrite existing provider with same ID")
        var force: Bool = false
        
        mutating func run() async throws {
            let manager = ConfigurationManager.shared
            
            // Validate provider ID format
            let validIdPattern = "^[a-zA-Z0-9-_]+$"
            let regex = try NSRegularExpression(pattern: validIdPattern)
            let range = NSRange(location: 0, length: providerId.utf16.count)
            if regex.firstMatch(in: providerId, options: [], range: range) == nil {
                if jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "INVALID_ID",
                        message: "Provider ID must contain only letters, numbers, hyphens, and underscores",
                        details: nil
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Provider ID must contain only letters, numbers, hyphens, and underscores")
                }
                throw ExitCode.failure
            }
            
            // Check if provider already exists
            if manager.getCustomProvider(id: providerId) != nil {
                if !force {
                    if jsonOutput {
                        let errorOutput = ErrorOutput(
                            error: true,
                            code: "PROVIDER_EXISTS",
                            message: "Provider '\(providerId)' already exists. Use --force to overwrite.",
                            details: nil
                        )
                        outputJSON(errorOutput)
                    } else {
                        print("❌ Provider '\(providerId)' already exists. Use --force to overwrite.")
                    }
                    throw ExitCode.failure
                }
            }
            
            // Validate and parse provider type
            guard let providerType = Configuration.CustomProvider.ProviderType(rawValue: type) else {
                if jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "INVALID_TYPE",
                        message: "Invalid provider type '\(type)'. Must be 'openai' or 'anthropic'.",
                        details: nil
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Invalid provider type '\(type)'. Must be 'openai' or 'anthropic'.")
                }
                throw ExitCode.failure
            }
            
            // Parse headers if provided
            var headerDict: [String: String]?
            if let headers = headers {
                headerDict = [:]
                let pairs = headers.split(separator: ",")
                for pair in pairs {
                    let components = pair.split(separator: ":", maxSplits: 1)
                    if components.count == 2 {
                        let key = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                        headerDict?[key] = value
                    }
                }
            }
            
            // Create provider configuration
            let options = Configuration.ProviderOptions(
                baseURL: baseUrl,
                apiKey: apiKey,
                headers: headerDict
            )
            
            let provider = Configuration.CustomProvider(
                name: name,
                description: description,
                type: providerType,
                options: options,
                models: nil, // User can add models later or they'll be discovered
                enabled: true
            )
            
            do {
                // Add provider to configuration
                try manager.addCustomProvider(provider, id: providerId)
                
                if jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "name": name,
                            "type": type,
                            "baseUrl": baseUrl
                        ]
                    )
                    outputJSON(successOutput)
                } else {
                    print("✅ Added custom provider '\(providerId)' (\(name))")
                    print("   Type: \(type)")
                    print("   Base URL: \(baseUrl)")
                    if let description = description {
                        print("   Description: \(description)")
                    }
                    print("\n💡 Test the connection with: peekaboo config test-provider \(providerId)")
                }
            } catch {
                if jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "ADD_FAILED",
                        message: "Failed to add provider: \(error.localizedDescription)",
                        details: nil
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Failed to add provider: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }
    
    /// Subcommand to list custom AI providers
    struct ListProvidersCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list-providers",
            abstract: "List configured custom AI providers",
            discussion: """
            Display all custom AI providers configured in Peekaboo.
            
            This shows providers you've added with 'peekaboo config add-provider',
            not the built-in providers (openai, anthropic, ollama).
            """
        )
        
        @Flag(name: .long, help: "Enable JSON output")
        var jsonOutput: Bool = false
        
        mutating func run() async throws {
            let manager = ConfigurationManager.shared
            let customProviders = manager.listCustomProviders()
            
            if jsonOutput {
                let data: [String: Any] = [
                    "providers": customProviders.mapValues { provider in
                        [
                            "name": provider.name,
                            "description": provider.description ?? "",
                            "type": provider.type.rawValue,
                            "baseUrl": provider.options.baseURL,
                            "enabled": provider.enabled,
                            "modelCount": provider.models?.count ?? 0
                        ]
                    }
                ]
                let output = SuccessOutput(success: true, data: data)
                outputJSON(output)
            } else {
                if customProviders.isEmpty {
                    print("No custom providers configured.")
                    print("Add one with: peekaboo config add-provider <id> --type <type> --name <name> --base-url <url> --api-key <key>")
                } else {
                    print("Custom AI Providers:")
                    print()
                    
                    for (id, provider) in customProviders.sorted(by: { $0.key < $1.key }) {
                        let status = provider.enabled ? "✅" : "❌"
                        print("  \(status) \(id) (\(provider.name))")
                        print("     Type: \(provider.type.rawValue)")
                        print("     URL: \(provider.options.baseURL)")
                        if let description = provider.description {
                            print("     Description: \(description)")
                        }
                        if let models = provider.models {
                            print("     Models: \(models.count) configured")
                        }
                        print()
                    }
                    
                    print("💡 Test a provider with: peekaboo config test-provider <id>")
                    print("💡 Remove a provider with: peekaboo config remove-provider <id>")
                }
            }
        }
    }
    
    /// Subcommand to test a custom AI provider connection
    struct TestProviderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "test-provider",
            abstract: "Test connection to a custom AI provider",
            discussion: """
            Test the connection to a custom AI provider by making a simple API call.
            
            This verifies that:
            • The base URL is accessible
            • The API key is valid
            • The endpoint responds correctly
            
            For OpenAI-compatible providers, this calls the /models endpoint.
            For Anthropic-compatible providers, this makes a simple message request.
            """
        )
        
        @Argument(help: "Provider ID to test")
        var providerId: String
        
        @Flag(name: .long, help: "Enable JSON output")
        var jsonOutput: Bool = false
        
        mutating func run() async throws {
            let manager = ConfigurationManager.shared
            let (success, error) = await manager.testCustomProvider(id: providerId)
            
            if jsonOutput {
                if success {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "connectionStatus": "successful"
                        ]
                    )
                    outputJSON(successOutput)
                } else {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "CONNECTION_FAILED",
                        message: error ?? "Connection test failed",
                        details: nil
                    )
                    outputJSON(errorOutput)
                }
            } else {
                if success {
                    print("✅ Connection to '\(providerId)' successful!")
                } else {
                    print("❌ Connection to '\(providerId)' failed: \(error ?? "Unknown error")")
                }
            }
            
            if !success {
                throw ExitCode.failure
            }
        }
    }
    
    /// Subcommand to remove a custom AI provider
    struct RemoveProviderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove-provider",
            abstract: "Remove a custom AI provider",
            discussion: """
            Remove a custom AI provider from your Peekaboo configuration.
            
            This only removes providers you've added with 'peekaboo config add-provider'.
            Built-in providers (openai, anthropic, ollama) cannot be removed.
            """
        )
        
        @Argument(help: "Provider ID to remove")
        var providerId: String
        
        @Flag(name: .long, help: "Enable JSON output")
        var jsonOutput: Bool = false
        
        @Flag(name: .long, help: "Skip confirmation prompt")
        var force: Bool = false
        
        mutating func run() async throws {
            let manager = ConfigurationManager.shared
            
            // Check if provider exists
            guard let provider = manager.getCustomProvider(id: providerId) else {
                if jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "PROVIDER_NOT_FOUND",
                        message: "Provider '\(providerId)' not found",
                        details: nil
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Provider '\(providerId)' not found")
                }
                throw ExitCode.failure
            }
            
            // Confirm removal unless forced
            if !force && !jsonOutput {
                print("Are you sure you want to remove provider '\(providerId)' (\(provider.name))? [y/N]: ", terminator: "")
                let response = readLine()?.lowercased()
                if response != "y" && response != "yes" {
                    print("Cancelled.")
                    return
                }
            }
            
            do {
                try manager.removeCustomProvider(id: providerId)
                
                if jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "action": "removed"
                        ]
                    )
                    outputJSON(successOutput)
                } else {
                    print("✅ Removed custom provider '\(providerId)'")
                }
            } catch {
                if jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "REMOVE_FAILED",
                        message: "Failed to remove provider: \(error.localizedDescription)",
                        details: nil
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Failed to remove provider: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }
    
    /// Subcommand to discover models from a custom AI provider
    struct ModelsProviderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "models-provider",
            abstract: "List available models from a custom AI provider",
            discussion: """
            Discover and list available models from a custom AI provider.
            
            For OpenAI-compatible providers, this queries the /models endpoint.
            For Anthropic-compatible providers, this shows configured models
            since Anthropic doesn't have a public models endpoint.
            """
        )
        
        @Argument(help: "Provider ID to query")
        var providerId: String
        
        @Flag(name: .long, help: "Enable JSON output")
        var jsonOutput: Bool = false
        
        @Flag(name: .long, help: "Discover models from API (for OpenAI-compatible providers)")
        var discover: Bool = false
        
        mutating func run() async throws {
            let manager = ConfigurationManager.shared
            
            guard let provider = manager.getCustomProvider(id: providerId) else {
                if jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "PROVIDER_NOT_FOUND",
                        message: "Provider '\(providerId)' not found",
                        details: nil
                    )
                    outputJSON(errorOutput)
                } else {
                    print("❌ Provider '\(providerId)' not found")
                }
                throw ExitCode.failure
            }
            
            var models: [String] = []
            var apiError: String?
            
            if discover && provider.type == .openai {
                let (discoveredModels, error) = await manager.discoverModelsForCustomProvider(id: providerId)
                models = discoveredModels
                apiError = error
            } else {
                // Use configured models
                models = provider.models?.keys.map { String($0) } ?? []
            }
            
            if jsonOutput {
                let data: [String: Any] = [
                    "providerId": providerId,
                    "models": models,
                    "source": discover && provider.type == .openai ? "api" : "configuration",
                    "error": apiError as Any
                ]
                let output = SuccessOutput(success: apiError == nil, data: data)
                outputJSON(output)
            } else {
                print("Models for provider '\(providerId)' (\(provider.name)):")
                print()
                
                if let error = apiError {
                    print("❌ Failed to discover models: \(error)")
                    if !models.isEmpty {
                        print("Showing configured models instead:")
                    }
                }
                
                if models.isEmpty {
                    if provider.type == .openai && !discover {
                        print("No configured models. Try --discover to query the API.")
                    } else {
                        print("No models available.")
                    }
                } else {
                    for model in models.sorted() {
                        print("  • \(model)")
                    }
                    print()
                    print("Found \(models.count) model(s)")
                    
                    if provider.type == .openai && !discover {
                        print("💡 Use --discover to query the API for all available models")
                    }
                }
            }
        }
    }
}

// MARK: - JSON Output Helpers

private struct SuccessOutput: Encodable {
    let success: Bool
    let data: [String: Any]

    enum CodingKeys: String, CodingKey {
        case success, data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.success, forKey: .success)
        try container.encode(JSONValue(self.data), forKey: .data)
    }
}

private struct ErrorOutput: Encodable {
    let error: Bool
    let code: String
    let message: String
    let details: String?
}

private struct JSONValue: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { JSONValue($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { JSONValue($0) })
        } else if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if self.value is NSNull {
            try container.encodeNil()
        } else {
            try container.encode(String(describing: self.value))
        }
    }
}

private func outputJSON(_ value: some Encodable) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    }
}
