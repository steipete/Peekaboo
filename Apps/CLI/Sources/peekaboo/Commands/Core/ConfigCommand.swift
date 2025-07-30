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
