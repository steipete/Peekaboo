import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

// swiftlint:disable type_body_length

/// Manage Peekaboo configuration files and settings
@available(macOS 14.0, *)
@MainActor
struct ConfigCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
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
    @MainActor
    struct InitCommand {
        static let commandDescription = CommandDescription(
            commandName: "init",
            abstract: "Create a default configuration file"
        )

        @Flag(name: .long, help: "Force overwrite existing configuration")
        var force = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }
        private var io: ConfigCommandOutput {
            ConfigCommandOutput(logger: self.logger, jsonOutput: self.jsonOutput)
        }

        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            let configPath = ConfigurationManager.configPath
            try self.ensureWritableConfig(at: configPath)
            try self.createConfiguration(at: configPath)
        }

        private mutating func prepare(using runtime: CommandRuntime) {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)
        }

        private func ensureWritableConfig(at path: String) throws {
            guard FileManager.default.fileExists(atPath: path), !self.force else { return }
            self.io.error(
                code: "FILE_IO_ERROR",
                message: "Configuration file already exists. Use --force to overwrite.",
                details: "Path: \(path)",
                textLines: [
                    "Configuration file already exists at: \(path)",
                    "Use --force to overwrite."
                ]
            )
            throw ExitCode.failure
        }

        private func createConfiguration(at path: String) throws {
            do {
                try ConfigurationManager.shared.createDefaultConfiguration()
                self.io.success(
                    message: "Configuration file created successfully",
                    data: ["path": path],
                    textLines: [
                        "✅ Configuration file created at: \(path)",
                        "",
                        "You can now edit it to customize your settings.",
                        "Use 'peekaboo config edit' to open it in your default editor."
                    ]
                )
            } catch {
                self.io.error(
                    code: "FILE_IO_ERROR",
                    message: error.localizedDescription,
                    details: "Path: \(path)",
                    textLines: ["❌ Failed to create configuration file: \(error)"]
                )
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to display current configuration
    @MainActor
    struct ShowCommand {
        static let commandDescription = CommandDescription(
            commandName: "show",
            abstract: "Display current configuration"
        )

        @Flag(name: .long, help: "Show effective configuration (merged with environment)")
        var effective = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

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
                        outputJSON(errorOutput, logger: self.logger)
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
                            outputJSON(errorOutput, logger: self.logger)
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
                        outputJSON(errorOutput, logger: self.logger)
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
                    outputJSON(successOutput, logger: self.logger)
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
                    let configFilePath = FileManager.default.fileExists(atPath: configPath) ? configPath : "NOT FOUND"
                    let credentialsFilePath = FileManager.default
                        .fileExists(atPath: credentialsPath) ? credentialsPath : "NOT FOUND"

                    print("  Config File: \(configFilePath)")
                    print("  Credentials: \(credentialsFilePath)")
                }
            }
        }
    }

    /// Subcommand to open configuration in an editor
    @MainActor
    struct EditCommand {
        static let commandDescription = CommandDescription(
            commandName: "edit",
            abstract: "Open configuration file in your default editor"
        )

        @Option(name: .long, help: "Editor to use (defaults to $EDITOR or nano)")
        var editor: String?
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

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
                    outputJSON(successOutput, logger: self.logger)
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
                        outputJSON(successOutput, logger: self.logger)
                    } else {
                        print("✅ Configuration saved.")

                        // Validate the edited configuration
                        if manager.loadConfiguration() != nil {
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
                        outputJSON(errorOutput, logger: self.logger)
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
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("Failed to open editor: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to validate configuration syntax
    @MainActor
    struct ValidateCommand {
        static let commandDescription = CommandDescription(
            commandName: "validate",
            abstract: "Validate configuration file syntax"
        )
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let configPath = ConfigurationManager.configPath

            if !FileManager.default.fileExists(atPath: configPath) {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: "No configuration file found",
                        details: "Path: \(configPath). Run 'peekaboo config init' to create one."
                    )
                    outputJSON(errorOutput, logger: self.logger)
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
                    outputJSON(successOutput, logger: self.logger)
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
                        details: """
                        Path: \(configPath). Common issues: trailing commas, \
                        unclosed comments, invalid JSON syntax.
                        """
                    )
                    outputJSON(errorOutput, logger: self.logger)
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
    @MainActor
    struct SetCredentialCommand {
        static let commandDescription = CommandDescription(
            commandName: "set-credential",
            abstract: "Set an API key or credential securely"
        )

        @Argument(help: "The credential name (e.g., OPENAI_API_KEY)")
        var key: String

        @Argument(help: "The credential value")
        var value: String
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try ConfigurationManager.shared.setCredential(key: self.key, value: self.value)

                if self.jsonOutput {
                    let data: [String: Any] = [
                        "message": "Credential set successfully",
                        "key": key,
                        "path": ConfigurationManager.credentialsPath,
                    ]
                    let successOutput = SuccessOutput(success: true, data: data)
                    outputJSON(successOutput, logger: self.logger)
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
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Failed to set credential: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    // MARK: - Custom Provider Management Commands

    /// Subcommand to add a custom AI provider
    @MainActor
    struct AddProviderCommand {
        static let commandDescription = CommandDescription(
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
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @Flag(name: .long, help: "Overwrite existing provider with same ID")
        var force: Bool = false

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let manager = ConfigurationManager.shared

            // Validate provider ID format
            let validIdPattern = "^[a-zA-Z0-9-_]+$"
            let regex = try NSRegularExpression(pattern: validIdPattern)
            let range = NSRange(location: 0, length: providerId.utf16.count)
            if regex.firstMatch(in: self.providerId, options: [], range: range) == nil {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "INVALID_ID",
                        message: "Provider ID must contain only letters, numbers, hyphens, and underscores",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Provider ID must contain only letters, numbers, hyphens, and underscores")
                }
                throw ExitCode.failure
            }

            // Check if provider already exists
            if manager.getCustomProvider(id: self.providerId) != nil {
                if !self.force {
                    if self.jsonOutput {
                        let errorOutput = ErrorOutput(
                            error: true,
                            code: "PROVIDER_EXISTS",
                            message: "Provider '\(providerId)' already exists. Use --force to overwrite.",
                            details: nil
                        )
                        outputJSON(errorOutput, logger: self.logger)
                    } else {
                        print("❌ Provider '\(self.providerId)' already exists. Use --force to overwrite.")
                    }
                    throw ExitCode.failure
                }
            }

            // Validate and parse provider type
            guard let providerType = Configuration.CustomProvider.ProviderType(rawValue: type) else {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "INVALID_TYPE",
                        message: "Invalid provider type '\(type)'. Must be 'openai' or 'anthropic'.",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Invalid provider type '\(self.type)'. Must be 'openai' or 'anthropic'.")
                }
                throw ExitCode.failure
            }

            // Parse headers if provided
            var headerDict: [String: String]?
            if let headers {
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
                baseURL: self.baseUrl,
                apiKey: self.apiKey,
                headers: headerDict
            )

            let provider = Configuration.CustomProvider(
                name: self.name,
                description: self.description,
                type: providerType,
                options: options,
                models: nil, // User can add models later or they'll be discovered
                enabled: true
            )

            do {
                // Add provider to configuration
                try manager.addCustomProvider(provider, id: self.providerId)

                if self.jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "name": name,
                            "type": type,
                            "baseUrl": baseUrl
                        ]
                    )
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    print("✅ Added custom provider '\(self.providerId)' (\(self.name))")
                    print("   Type: \(self.type)")
                    print("   Base URL: \(self.baseUrl)")
                    if let description {
                        print("   Description: \(description)")
                    }
                    print("\n💡 Test the connection with: peekaboo config test-provider \(self.providerId)")
                }
            } catch {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "ADD_FAILED",
                        message: "Failed to add provider: \(error.localizedDescription)",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Failed to add provider: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to list custom AI providers
    @MainActor
    struct ListProvidersCommand {
        static let commandDescription = CommandDescription(
            commandName: "list-providers",
            abstract: "List configured custom AI providers",
            discussion: """
            Display all custom AI providers configured in Peekaboo.

            This shows providers you've added with 'peekaboo config add-provider',
            not the built-in providers (openai, anthropic, ollama).
            """
        )
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let manager = ConfigurationManager.shared
            let customProviders = manager.listCustomProviders()

            if self.jsonOutput {
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
                outputJSON(output, logger: self.logger)
            } else {
                if customProviders.isEmpty {
                    print("No custom providers configured.")
                    print("Add one with: peekaboo config add-provider <id> --type <type>")
                    print("  --name <name> --base-url <url> --api-key <key>")
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
    @MainActor
    struct TestProviderCommand {
        static let commandDescription = CommandDescription(
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
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let manager = ConfigurationManager.shared
            let (success, error) = await manager.testCustomProvider(id: self.providerId)

            if self.jsonOutput {
                if success {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "connectionStatus": "successful"
                        ]
                    )
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "CONNECTION_FAILED",
                        message: error ?? "Connection test failed",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                }
            } else {
                if success {
                    print("✅ Connection to '\(self.providerId)' successful!")
                } else {
                    print("❌ Connection to '\(self.providerId)' failed: \(error ?? "Unknown error")")
                }
            }

            if !success {
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to remove a custom AI provider
    @MainActor
    struct RemoveProviderCommand {
        static let commandDescription = CommandDescription(
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
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @Flag(name: .long, help: "Skip confirmation prompt")
        var force: Bool = false

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let manager = ConfigurationManager.shared

            // Check if provider exists
            guard let provider = manager.getCustomProvider(id: providerId) else {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "PROVIDER_NOT_FOUND",
                        message: "Provider '\(providerId)' not found",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Provider '\(self.providerId)' not found")
                }
                throw ExitCode.failure
            }

            // Confirm removal unless forced
            if !self.force && !self.jsonOutput {
                print(
                    "Are you sure you want to remove provider '\(self.providerId)' (\(provider.name))? [y/N]: ",
                    terminator: ""
                )
                let response = readLine()?.lowercased()
                if response != "y" && response != "yes" {
                    print("Cancelled.")
                    return
                }
            }

            do {
                try manager.removeCustomProvider(id: self.providerId)

                if self.jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "action": "removed"
                        ]
                    )
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    print("✅ Removed custom provider '\(self.providerId)'")
                }
            } catch {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "REMOVE_FAILED",
                        message: "Failed to remove provider: \(error.localizedDescription)",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Failed to remove provider: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to discover models from a custom AI provider
    @MainActor
    struct ModelsProviderCommand {
        static let commandDescription = CommandDescription(
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
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @Flag(name: .long, help: "Discover models from API (for OpenAI-compatible providers)")
        var discover: Bool = false

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let manager = ConfigurationManager.shared

            guard let provider = manager.getCustomProvider(id: providerId) else {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "PROVIDER_NOT_FOUND",
                        message: "Provider '\(providerId)' not found",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("❌ Provider '\(self.providerId)' not found")
                }
                throw ExitCode.failure
            }

            var models: [String] = []
            var apiError: String?

            if self.discover && provider.type == .openai {
                let (discoveredModels, error) = await manager.discoverModelsForCustomProvider(id: self.providerId)
                models = discoveredModels
                apiError = error
            } else {
                // Use configured models
                models = provider.models?.keys.map { String($0) } ?? []
            }

            if self.jsonOutput {
                let data: [String: Any] = [
                    "providerId": providerId,
                    "models": models,
                    "source": discover && provider.type == .openai ? "api" : "configuration",
                    "error": apiError as Any
                ]
                let output = SuccessOutput(success: apiError == nil, data: data)
                outputJSON(output, logger: self.logger)
            } else {
                print("Models for provider '\(self.providerId)' (\(provider.name)):")
                print()

                if let error = apiError {
                    print("❌ Failed to discover models: \(error)")
                    if !models.isEmpty {
                        print("Showing configured models instead:")
                    }
                }

                if models.isEmpty {
                    if provider.type == .openai && !self.discover {
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

                    if provider.type == .openai && !self.discover {
                        print("💡 Use --discover to query the API for all available models")
                    }
                }
            }
        }
    }
}

private func outputJSON(_ value: some Encodable, logger: Logger) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let data = try encoder.encode(value)
        if let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    } catch {
        logger.error("Failed to encode config JSON output: \(error.localizedDescription)")
        print("{\n  \"success\": false,\n  \"error\": {\n    \"message\": \"Failed to encode JSON response\"\n  }\n}")
    }
}

extension ConfigCommand.InitCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.InitCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.force = values.flag("force")
    }
}

extension ConfigCommand.ShowCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.ShowCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.effective = values.flag("effective")
    }
}

extension ConfigCommand.EditCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.EditCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.editor = values.singleOption("editor")
    }
}

extension ConfigCommand.ValidateCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.ValidateCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

extension ConfigCommand.SetCredentialCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.SetCredentialCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.key = try values.decodePositional(0, label: "key")
        self.value = try values.decodePositional(1, label: "value")
    }
}

extension ConfigCommand.AddProviderCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.AddProviderCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.providerId = try values.decodePositional(0, label: "providerId")
        self.type = try values.requireOption("type", as: String.self)
        self.name = try values.requireOption("name", as: String.self)
        self.baseUrl = try values.requireOption("baseUrl", as: String.self)
        self.apiKey = try values.requireOption("apiKey", as: String.self)
        self.description = values.singleOption("description")
        self.headers = values.singleOption("headers")
        self.force = values.flag("force")
    }
}

extension ConfigCommand.ListProvidersCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.ListProvidersCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

extension ConfigCommand.TestProviderCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.TestProviderCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.providerId = try values.decodePositional(0, label: "providerId")
    }
}

extension ConfigCommand.RemoveProviderCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.RemoveProviderCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.providerId = try values.decodePositional(0, label: "providerId")
        self.force = values.flag("force")
    }
}

extension ConfigCommand.ModelsProviderCommand: AsyncRuntimeCommand {}
@MainActor
extension ConfigCommand.ModelsProviderCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.providerId = try values.decodePositional(0, label: "providerId")
        self.discover = values.flag("discover")
    }
}

// swiftlint:enable type_body_length
