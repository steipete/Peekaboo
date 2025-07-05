import ArgumentParser
import Foundation

/// Command for managing Peekaboo configuration.
///
/// Provides subcommands to create, view, edit, and validate the JSONC configuration
/// file that controls AI providers, default settings, and logging preferences.
struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage Peekaboo configuration",
        discussion: """
        The config command helps you manage Peekaboo's configuration file.

        Configuration file location: ~/.config/peekaboo/config.json

        The configuration file uses JSONC format (JSON with Comments) and supports:
        • Comments using // and /* */
        • Environment variable expansion using ${VAR_NAME}
        • Tilde expansion for home directories

        Configuration precedence (highest to lowest):
        1. Command-line arguments
        2. Environment variables
        3. Configuration file
        4. Built-in defaults
        """,
        subcommands: [InitCommand.self, ShowCommand.self, EditCommand.self, ValidateCommand.self]
    )

    /// Subcommand to create a default configuration file.
    ///
    /// Generates a new configuration file with sensible defaults and example settings
    /// at the standard location (~/.config/peekaboo/config.json).
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

            if configExists && !force {
                if jsonOutput {
                    outputError(
                        message: "Configuration file already exists. Use --force to overwrite.",
                        code: .FILE_IO_ERROR,
                        details: "Path: \(configPath)"
                    )
                } else {
                    print("Configuration file already exists at: \(configPath)")
                    print("Use --force to overwrite.")
                }
                throw ExitCode.failure
            }

            do {
                try ConfigurationManager.shared.createDefaultConfiguration()

                if jsonOutput {
                    outputSuccess(data: [
                        "message": "Configuration file created successfully",
                        "path": configPath
                    ])
                } else {
                    print("✅ Configuration file created at: \(configPath)")
                    print("\nYou can now edit it to customize your settings.")
                    print("Use 'peekaboo config edit' to open it in your default editor.")
                }
            } catch {
                if jsonOutput {
                    outputError(
                        message: error.localizedDescription,
                        code: .FILE_IO_ERROR,
                        details: "Path: \(configPath)"
                    )
                } else {
                    print("❌ Failed to create configuration file: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to display current configuration.
    ///
    /// Shows either the raw configuration file contents or the effective configuration
    /// after merging all sources (CLI args, environment variables, config file).
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

            if !effective {
                // Show raw configuration file
                if !FileManager.default.fileExists(atPath: configPath) {
                    if jsonOutput {
                        outputError(
                            message: "No configuration file found",
                            code: .FILE_IO_ERROR,
                            details: "Path: \(configPath). Run 'peekaboo config init' to create one."
                        )
                    } else {
                        print("No configuration file found at: \(configPath)")
                        print("Run 'peekaboo config init' to create one.")
                    }
                    throw ExitCode.failure
                }

                do {
                    let contents = try String(contentsOfFile: configPath)
                    if jsonOutput {
                        // For JSON output, parse and re-encode to ensure valid JSON
                        if let config = ConfigurationManager.shared.loadConfiguration() {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            let data = try encoder.encode(config)
                            print(String(data: data, encoding: .utf8)!)
                        } else {
                            outputError(
                                message: "Failed to parse configuration file",
                                code: .FILE_IO_ERROR
                            )
                            throw ExitCode.failure
                        }
                    } else {
                        print(contents)
                    }
                } catch {
                    if jsonOutput {
                        outputError(
                            message: error.localizedDescription,
                            code: .FILE_IO_ERROR
                        )
                    } else {
                        print("Failed to read configuration file: \(error)")
                    }
                    throw ExitCode.failure
                }
            } else {
                // Show effective configuration
                let manager = ConfigurationManager.shared
                _ = manager.loadConfiguration()

                let effectiveConfig: [String: Any] = [
                    "aiProviders": [
                        "providers": manager.getAIProviders(cliValue: nil),
                        "openaiApiKey": manager.getOpenAIAPIKey() != nil ? "***SET***" : "NOT SET",
                        "ollamaBaseUrl": manager.getOllamaBaseURL()
                    ],
                    "defaults": [
                        "savePath": manager.getDefaultSavePath(cliValue: nil)
                    ],
                    "logging": [
                        "level": manager.getLogLevel(),
                        "path": manager.getLogPath()
                    ],
                    "configFile": FileManager.default.fileExists(atPath: configPath) ? configPath : "NOT FOUND"
                ]

                if jsonOutput {
                    outputSuccess(data: effectiveConfig)
                } else {
                    print("Effective Configuration (after merging all sources):")
                    print(String(repeating: "=", count: 50))
                    print()
                    print("AI Providers:")
                    print("  Providers: \(manager.getAIProviders(cliValue: nil))")
                    print("  OpenAI API Key: \(manager.getOpenAIAPIKey() != nil ? "***SET***" : "NOT SET")")
                    print("  Ollama Base URL: \(manager.getOllamaBaseURL())")
                    print()
                    print("Defaults:")
                    print("  Save Path: \(manager.getDefaultSavePath(cliValue: nil))")
                    print()
                    print("Logging:")
                    print("  Level: \(manager.getLogLevel())")
                    print("  Path: \(manager.getLogPath())")
                    print()
                    print(
                        "Config File: \(FileManager.default.fileExists(atPath: configPath) ? configPath : "NOT FOUND")"
                    )
                }
            }
        }
    }

    /// Subcommand to open configuration in an editor.
    ///
    /// Opens the configuration file in the user's preferred text editor,
    /// creating a default configuration if one doesn't exist.
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

            // Create config if it doesn't exist
            if !FileManager.default.fileExists(atPath: configPath) {
                if jsonOutput {
                    outputSuccess(data: [
                        "message": "Creating default configuration file",
                        "path": configPath
                    ])
                } else {
                    print("No configuration file found. Creating default configuration...")
                }

                try ConfigurationManager.shared.createDefaultConfiguration()
            }

            // Determine editor
            let editorCommand = editor ?? ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"

            // Open editor
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editorCommand, configPath]

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    if jsonOutput {
                        outputSuccess(data: [
                            "message": "Configuration edited successfully",
                            "editor": editorCommand,
                            "path": configPath
                        ])
                    } else {
                        print("✅ Configuration saved.")

                        // Validate the edited configuration
                        if let _ = ConfigurationManager.shared.loadConfiguration() {
                            print("✅ Configuration is valid.")
                        } else {
                            print("⚠️  Warning: Configuration may have errors. Run 'peekaboo config validate' to check.")
                        }
                    }
                } else {
                    if jsonOutput {
                        outputError(
                            message: "Editor exited with non-zero status: \(process.terminationStatus)",
                            code: .UNKNOWN_ERROR,
                            details: "Editor: \(editorCommand)"
                        )
                    } else {
                        print("Editor exited with status: \(process.terminationStatus)")
                    }
                    throw ExitCode.failure
                }
            } catch {
                if jsonOutput {
                    outputError(
                        message: error.localizedDescription,
                        code: .UNKNOWN_ERROR,
                        details: "Editor: \(editorCommand)"
                    )
                } else {
                    print("Failed to open editor: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    /// Subcommand to validate configuration syntax.
    ///
    /// Checks that the configuration file contains valid JSONC syntax and can be
    /// successfully parsed, reporting any syntax errors found.
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
                if jsonOutput {
                    outputError(
                        message: "No configuration file found",
                        code: .FILE_IO_ERROR,
                        details: "Path: \(configPath). Run 'peekaboo config init' to create one."
                    )
                } else {
                    print("No configuration file found at: \(configPath)")
                    print("Run 'peekaboo config init' to create one.")
                }
                throw ExitCode.failure
            }

            // Try to load and validate
            if let config = ConfigurationManager.shared.loadConfiguration() {
                if jsonOutput {
                    outputSuccess(data: [
                        "valid": true,
                        "message": "Configuration is valid",
                        "path": configPath,
                        "hasAIProviders": config.aiProviders != nil,
                        "hasDefaults": config.defaults != nil,
                        "hasLogging": config.logging != nil
                    ])
                } else {
                    print("✅ Configuration is valid!")
                    print()
                    print("Detected sections:")
                    if config.aiProviders != nil { print("  ✓ AI Providers") }
                    if config.defaults != nil { print("  ✓ Defaults") }
                    if config.logging != nil { print("  ✓ Logging") }
                }
            } else {
                if jsonOutput {
                    outputError(
                        message: "Failed to parse configuration file. Check for syntax errors.",
                        code: .FILE_IO_ERROR,
                        details: "Path: \(configPath). Common issues: trailing commas, unclosed comments, invalid JSON syntax."
                    )
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
}
