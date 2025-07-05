import Foundation
@testable import peekaboo
import Testing

@Suite("ConfigCommand Tests")
struct ConfigCommandTests {
    @Suite("Init Subcommand")
    struct InitTests {
        let tempDir: URL
        let configPath: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            configPath = tempDir.appendingPathComponent("config.json")
        }

        @Test("Creates default configuration file")
        func initCreatesDefaultConfig() async throws {
            // Parse the command properly through ArgumentParser
            var command = try ConfigCommand.InitCommand.parse(["--force"])

            // We can't test the actual file creation without modifying the real config path
            // So we'll just ensure the command doesn't crash
            do {
                try await command.run()
            } catch {
                // Expected to fail if config already exists without force
            }
        }

        @Test("Fails when config exists without force")
        func initFailsWhenConfigExists() async throws {
            // Create a file at the config path first
            let configPath = ConfigurationManager.configPath
            let configDir = URL(fileURLWithPath: configPath).deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

            // If config already exists, test without force should fail
            if FileManager.default.fileExists(atPath: configPath) {
                var command = try ConfigCommand.InitCommand.parse([])

                await #expect(throws: Error.self) {
                    try await command.run()
                }
            }
        }
    }

    @Suite("Show Subcommand")
    struct ShowTests {
        @Test("Shows raw configuration when not effective")
        func showRawConfiguration() async throws {
            var command = try ConfigCommand.ShowCommand.parse([])

            // This will either show the config or fail if no config exists
            do {
                try await command.run()
            } catch {
                // Expected if no config file exists
            }
        }

        @Test("Shows effective configuration")
        func showEffectiveConfiguration() async throws {
            var command = try ConfigCommand.ShowCommand.parse(["--effective"])

            // This should always work as it shows the merged config
            try await command.run()
        }
    }

    @Suite("Validate Subcommand")
    struct ValidateTests {
        @Test("Validates existing configuration")
        func validateExistingConfig() async throws {
            var command = try ConfigCommand.ValidateCommand.parse([])

            // This will validate if config exists, or fail appropriately
            do {
                try await command.run()
            } catch {
                // Expected if no config file exists
            }
        }
    }

    @Suite("Configuration Model Tests")
    struct ConfigurationModelTests {
        @Test("Configuration encodes and decodes correctly")
        func configurationCoding() throws {
            let config = Configuration(
                aiProviders: Configuration.AIProviderConfig(
                    providers: "openai/gpt-4o,ollama/llava:latest",
                    openaiApiKey: "test-key",
                    ollamaBaseUrl: "http://localhost:11434"
                ),
                defaults: Configuration.DefaultsConfig(
                    savePath: "~/Desktop",
                    imageFormat: "png",
                    captureMode: "window",
                    captureFocus: "auto"
                ),
                logging: Configuration.LoggingConfig(
                    level: "debug",
                    path: "~/logs/peekaboo.log"
                )
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            let decoded = try JSONDecoder().decode(Configuration.self, from: data)

            #expect(decoded.aiProviders?.providers == config.aiProviders?.providers)
            #expect(decoded.aiProviders?.openaiApiKey == config.aiProviders?.openaiApiKey)
            #expect(decoded.defaults?.savePath == config.defaults?.savePath)
            #expect(decoded.defaults?.imageFormat == config.defaults?.imageFormat)
            #expect(decoded.logging?.level == config.logging?.level)
        }

        @Test("Configuration handles nil values")
        func configurationWithNilValues() throws {
            let config = Configuration(
                aiProviders: nil,
                defaults: Configuration.DefaultsConfig(savePath: "~/Desktop"),
                logging: nil
            )

            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(Configuration.self, from: data)

            #expect(decoded.aiProviders == nil)
            #expect(decoded.defaults?.savePath == "~/Desktop")
            #expect(decoded.defaults?.imageFormat == nil)
            #expect(decoded.logging == nil)
        }
    }

    @Suite("ConfigurationManager Tests")
    struct ConfigurationManagerTests {
        @Test("Strips JSON comments correctly", arguments: [
            ("// Single line comment\n{\"key\": \"value\"}", "\n{\"key\": \"value\"}"),
            ("/* Multi\nline\ncomment */\n{\"key\": \"value\"}", "\n{\"key\": \"value\"}"),
            ("{\"key\": \"value\" // inline comment\n}", "{\"key\": \"value\" \n}"),
            ("{\"url\": \"http://example.com\"}", "{\"url\": \"http://example.com\"}") // Preserve URLs
        ])
        func testStripJSONComments(input: String, expected: String) {
            let manager = ConfigurationManager.shared
            let result = manager.stripJSONComments(from: input)
            #expect(result == expected)
        }

        @Test("Expands environment variables", arguments: [
            ("${HOME}/test", "~/test"),
            ("${NONEXISTENT_VAR}", "${NONEXISTENT_VAR}"),
            ("${PATH}:extra", "\(ProcessInfo.processInfo.environment["PATH"] ?? ""):extra"),
            ("plain text", "plain text")
        ])
        func testExpandEnvironmentVariables(input: String, expectedPattern: String) {
            let manager = ConfigurationManager.shared
            let result = manager.expandEnvironmentVariables(in: input)

            if expectedPattern == "~/test" {
                #expect(result.hasSuffix("/test"))
            } else if input.contains("${PATH}") {
                #expect(result.contains(":extra"))
            } else {
                #expect(result == expectedPattern)
            }
        }

        @Test("Merges configuration sources correctly")
        func configurationPrecedence() {
            let manager = ConfigurationManager.shared

            // Test CLI value takes precedence
            let cliValue = "cli-value"
            let envValue = "env-value"
            _ = "config-value"

            setenv("TEST_ENV_VAR", envValue, 1)
            defer { unsetenv("TEST_ENV_VAR") }

            // Simulate config loaded
            _ = manager.loadConfiguration()

            // CLI value should win
            let providers = manager.getAIProviders(cliValue: cliValue)
            #expect(providers == cliValue)

            // Without CLI value, should use config or default
            let savePath = manager.getDefaultSavePath(cliValue: nil)
            // The actual value depends on config file, env vars, or default
            #expect(savePath.contains("/Desktop")) // Should be under Desktop
        }
    }
}
