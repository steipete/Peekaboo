import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

@available(macOS 14.0, *)
@MainActor
extension ConfigCommand {
    /// Create a default configuration file.
    struct InitCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "init",
            abstract: "Create a default configuration file"
        )

        @Flag(name: .long, help: "Force overwrite existing configuration")
        var force = false
        @RuntimeStorage var runtime: CommandRuntime?

        private var io: ConfigCommandOutput { self.output }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            let path = self.configPath
            try self.ensureWritableConfig(at: path)
            try self.createConfiguration(at: path)
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
                try self.configManager.createDefaultConfiguration()
                self.io.success(
                    message: "Configuration file created successfully",
                    data: ["path": path],
                    textLines: [
                        "[ok] Configuration file created at: \(path)",
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
                    textLines: ["[error] Failed to create configuration file: \(error)"]
                )
                throw ExitCode.failure
            }
        }
    }

    /// Display the current configuration.
    struct ShowCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "show",
            abstract: "Display current configuration"
        )

        @Flag(name: .long, help: "Show effective configuration (merged with environment)")
        var effective = false
        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            if !self.effective {
                try self.showRawConfiguration()
                return
            }

            try self.showEffectiveConfiguration()
        }

        private func showRawConfiguration() throws {
            guard FileManager.default.fileExists(atPath: self.configPath) else {
                if self.jsonOutput {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "FILE_IO_ERROR",
                        message: "No configuration file found",
                        details: "Path: \(self.configPath). Run 'peekaboo config init' to create one."
                    )
                    outputJSON(errorOutput, logger: self.logger)
                } else {
                    print("No configuration file found at: \(self.configPath)")
                    print("Run 'peekaboo config init' to create one.")
                }
                throw ExitCode.failure
            }

            do {
                let contents = try String(contentsOfFile: self.configPath)
                if self.jsonOutput {
                    guard let config = self.configManager.loadConfiguration() else {
                        let errorOutput = ErrorOutput(
                            error: true,
                            code: "FILE_IO_ERROR",
                            message: "Failed to parse configuration file",
                            details: nil
                        )
                        outputJSON(errorOutput, logger: self.logger)
                        throw ExitCode.failure
                    }

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(config)
                    if let json = String(data: data, encoding: .utf8) {
                        print(json)
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
        }

        private func showEffectiveConfiguration() throws {
            _ = self.configManager.loadConfiguration()

            let effectiveConfig: [String: Any] = [
                "aiProviders": [
                    "providers": self.configManager.getAIProviders(),
                    "openaiApiKey": self.configManager.getOpenAIAPIKey() != nil ? "***SET***" : "NOT SET",
                    "ollamaBaseUrl": self.configManager.getOllamaBaseURL(),
                ],
                "defaults": [
                    "savePath": self.configManager.getDefaultSavePath(),
                ],
                "logging": [
                    "level": self.configManager.getLogLevel(),
                    "path": self.configManager.getLogPath(),
                ],
                "configFile": FileManager.default.fileExists(atPath: self.configPath) ? self.configPath : "NOT FOUND",
                "credentialsFile": FileManager.default.fileExists(atPath: self.credentialsPath) ? self.credentialsPath : "NOT FOUND",
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
                print("  Providers: \(self.configManager.getAIProviders())")
                print("  OpenAI API Key: \(self.configManager.getOpenAIAPIKey() != nil ? "***SET***" : "NOT SET")")
                print("  Ollama Base URL: \(self.configManager.getOllamaBaseURL())")
                print()
                print("Defaults:")
                print("  Save Path: \(self.configManager.getDefaultSavePath())")
                print()
                print("Logging:")
                print("  Level: \(self.configManager.getLogLevel())")
                print("  Path: \(self.configManager.getLogPath())")
                print()
                print("Files:")
                let configFilePath = FileManager.default.fileExists(atPath: self.configPath) ? self.configPath : "NOT FOUND"
                let credentialsFilePath = FileManager.default.fileExists(atPath: self.credentialsPath) ? self.credentialsPath : "NOT FOUND"

                print("  Config File: \(configFilePath)")
                print("  Credentials: \(credentialsFilePath)")
            }
        }
    }

    /// Open configuration in an editor.
    struct EditCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "edit",
            abstract: "Open configuration file in your default editor"
        )

        @Option(name: .long, help: "Editor to use (defaults to $EDITOR or nano)")
        var editor: String?
        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            // Create config if it doesn't exist
            if !FileManager.default.fileExists(atPath: self.configPath) {
                if self.jsonOutput {
                    let data: [String: Any] = [
                        "message": "Creating default configuration file",
                        "path": self.configPath,
                    ]
                    let successOutput = SuccessOutput(success: true, data: data)
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    print("No configuration file found. Creating default configuration...")
                }

                try self.configManager.createDefaultConfiguration()
            }

            let editorCommand = self.editor ?? ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editorCommand, self.configPath]

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    throw ExitCode.failure
                }

                if self.jsonOutput {
                    let data: [String: Any] = [
                        "message": "Configuration edited successfully",
                        "editor": editorCommand,
                        "path": self.configPath,
                    ]
                    let successOutput = SuccessOutput(success: true, data: data)
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    print("[ok] Configuration saved.")

                    // Validate the edited configuration
                    if self.configManager.loadConfiguration() != nil {
                        print("[ok] Configuration is valid.")
                    } else {
                        print("[warn] Configuration may be invalid. Please check your changes.")
                    }
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
                    print("Failed to open editor: \(error)")
                }
                throw ExitCode.failure
            }
        }
    }
}
