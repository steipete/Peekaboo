import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("ConfigCommand Tests", .tags(.safe))
struct ConfigCommandTests {
    // MARK: - Helpers

    private func makeRuntime(json: Bool = false) -> CommandRuntime {
        CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: json, logLevel: nil),
            services: PeekabooServices()
        )
    }

    private func withTempConfigDir(_ body: @escaping (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        setenv("PEEKABOO_CONFIG_DIR", tempDir.path, 1)
        #if DEBUG
        PeekabooCore.ConfigurationManager.shared.resetForTesting()
        #endif

        defer {
            unsetenv("PEEKABOO_CONFIG_DIR")
            #if DEBUG
            PeekabooCore.ConfigurationManager.shared.resetForTesting()
            #endif
            try? FileManager.default.removeItem(at: tempDir)
        }

        try await body(tempDir)
    }

    @Test("ConfigCommand exists and has correct subcommands")
    func configCommandStructure() {
        // Verify the command exists
        let command = ConfigCommand.self

        // Check command configuration
        #expect(command.commandDescription.commandName == "config")
        #expect(command.commandDescription.abstract == "Manage Peekaboo configuration")

        // Check subcommands
        let subcommands = command.commandDescription.subcommands
        #expect(subcommands.count == 10)
        let hasInit = subcommands.contains { $0 == ConfigCommand.InitCommand.self }
        #expect(hasInit)
        let hasShow = subcommands.contains { $0 == ConfigCommand.ShowCommand.self }
        #expect(hasShow)
        let hasEdit = subcommands.contains { $0 == ConfigCommand.EditCommand.self }
        #expect(hasEdit)
        let hasValidate = subcommands.contains { $0 == ConfigCommand.ValidateCommand.self }
        #expect(hasValidate)
        let hasSetCredential = subcommands.contains { $0 == ConfigCommand.SetCredentialCommand.self }
        #expect(hasSetCredential)
        let hasAddProvider = subcommands.contains { $0 == ConfigCommand.AddProviderCommand.self }
        #expect(hasAddProvider)
        let hasListProviders = subcommands.contains { $0 == ConfigCommand.ListProvidersCommand.self }
        #expect(hasListProviders)
        let hasTestProvider = subcommands.contains { $0 == ConfigCommand.TestProviderCommand.self }
        #expect(hasTestProvider)
        let hasRemoveProvider = subcommands.contains { $0 == ConfigCommand.RemoveProviderCommand.self }
        #expect(hasRemoveProvider)
        let hasModelsProvider = subcommands.contains { $0 == ConfigCommand.ModelsProviderCommand.self }
        #expect(hasModelsProvider)
    }

    @Test("InitCommand has correct configuration")
    func initCommand() {
        let command = ConfigCommand.InitCommand.self
        #expect(command.commandDescription.commandName == "init")
        #expect(command.commandDescription.abstract == "Create a default configuration file")
    }

    @Test("ShowCommand has correct configuration")
    func showCommand() {
        let command = ConfigCommand.ShowCommand.self
        #expect(command.commandDescription.commandName == "show")
        #expect(command.commandDescription.abstract == "Display current configuration")
    }

    @Test("EditCommand has correct configuration")
    func editCommand() {
        let command = ConfigCommand.EditCommand.self
        #expect(command.commandDescription.commandName == "edit")
        #expect(command.commandDescription.abstract == "Open configuration file in your default editor")
    }

    @Test("ValidateCommand has correct configuration")
    func validateCommand() {
        let command = ConfigCommand.ValidateCommand.self
        #expect(command.commandDescription.commandName == "validate")
        #expect(command.commandDescription.abstract == "Validate configuration file syntax")
    }

    @Test("SetCredentialCommand has correct configuration")
    func setCredentialCommand() {
        let command = ConfigCommand.SetCredentialCommand.self
        #expect(command.commandDescription.commandName == "set-credential")
        #expect(command.commandDescription.abstract == "Set an API key or credential securely")
    }

    @Test("AddProviderCommand validates provider IDs")
    func providerIdValidation() {
        #expect(ConfigCommand.AddProviderCommand.isValidProviderId("openrouter"))
        #expect(ConfigCommand.AddProviderCommand.isValidProviderId("acme-123"))
        #expect(!ConfigCommand.AddProviderCommand.isValidProviderId("spaces not-allowed"))
        #expect(!ConfigCommand.AddProviderCommand.isValidProviderId("🥸"))
    }

    @Test("AddProviderCommand parses headers and rejects invalid formats")
    func headerParsing() throws {
        let parsed = try ConfigCommand.AddProviderCommand.parseHeaders("X-Key:one,Auth: Bearer")
        #expect(parsed?["x-key"] == "one")
        #expect(parsed?["auth"] == "Bearer")

        #expect(throws: ConfigCommand.AddProviderCommand.HeaderParseError.self) {
            _ = try ConfigCommand.AddProviderCommand.parseHeaders("missingColon")
        }
    }

    @Test("Init command creates config file at overridden path", .serialized)
    func initCreatesConfig() async throws {
        try await self.withTempConfigDir { dir in
            var command = ConfigCommand.InitCommand()
            try await command.run(using: self.makeRuntime())

            let configPath = dir.appendingPathComponent("config.json")
            #expect(FileManager.default.fileExists(atPath: configPath.path))
        }
    }

    @Test("Add provider dry-run does not write", .serialized)
    func addProviderDryRun() async throws {
        try await self.withTempConfigDir { dir in
            var command = ConfigCommand.AddProviderCommand()
            command.providerId = "openrouter"
            command.type = "openai"
            command.name = "OpenRouter"
            command.baseUrl = "https://openrouter.ai/api/v1"
            command.apiKey = "{env:OPENROUTER_API_KEY}"
            command.dryRun = true

            try await command.run(using: self.makeRuntime())

            let configPath = dir.appendingPathComponent("config.json")
            #expect(!FileManager.default.fileExists(atPath: configPath.path))
        }
    }

    @Test("Add provider rejects invalid URL", .serialized)
    func addProviderInvalidURL() async throws {
        try await self.withTempConfigDir { _ in
            var command = ConfigCommand.AddProviderCommand()
            command.providerId = "bad"
            command.type = "openai"
            command.name = "Bad"
            command.baseUrl = "localhost"
            command.apiKey = "{env:BAD_API_KEY}"

            await #expect(throws: (any Error).self) {
                try await command.run(using: self.makeRuntime())
            }
        }
    }

    @Test("Remove provider dry-run leaves config intact", .serialized)
    func removeProviderDryRun() async throws {
        try await self.withTempConfigDir { _ in
            var add = ConfigCommand.AddProviderCommand()
            add.providerId = "keep"
            add.type = "openai"
            add.name = "Keep"
            add.baseUrl = "https://api.keep/v1"
            add.apiKey = "{env:KEEP_API_KEY}"
            try await add.run(using: self.makeRuntime())

            var remove = ConfigCommand.RemoveProviderCommand()
            remove.providerId = "keep"
            remove.dryRun = true
            try await remove.run(using: self.makeRuntime())

            let providersAfter = PeekabooCore.ConfigurationManager.shared.listCustomProviders()
            #expect(providersAfter["keep"] != nil)
        }
    }

    @Test("Validate command fails on malformed config", .serialized)
    func validateMalformedConfig() async throws {
        try await self.withTempConfigDir { dir in
            let badConfig = dir.appendingPathComponent("config.json")
            try """
            {
              "aiProviders": {
                "providers": "openai/gpt-5.1",
              }
            }
            """.write(to: badConfig, atomically: true, encoding: .utf8)

            var command = ConfigCommand.ValidateCommand()
            await #expect(throws: (any Error).self) {
                try await command.run(using: self.makeRuntime())
            }
        }
    }

    @Test("Add/remove provider persists to config", .serialized)
    func addAndRemoveProvider() async throws {
        try await self.withTempConfigDir { _ in
            var add = ConfigCommand.AddProviderCommand()
            add.providerId = "local"
            add.type = "openai"
            add.name = "Local"
            add.baseUrl = "https://api.local/v1"
            add.apiKey = "{env:LOCAL_API_KEY}"
            try await add.run(using: self.makeRuntime())

            let providersAfterAdd = PeekabooCore.ConfigurationManager.shared.listCustomProviders()
            #expect(providersAfterAdd["local"] != nil)
            #expect(providersAfterAdd["local"]?.options.baseURL == "https://api.local/v1")

            var remove = ConfigCommand.RemoveProviderCommand()
            remove.providerId = "local"
            remove.force = true
            try await remove.run(using: self.makeRuntime())

            let providersAfterRemove = PeekabooCore.ConfigurationManager.shared.listCustomProviders()
            #expect(providersAfterRemove["local"] == nil)
        }
    }

    @Test("Edit print-path leaves filesystem untouched", .serialized)
    func editPrintPath() async throws {
        try await self.withTempConfigDir { dir in
            let configPath = dir.appendingPathComponent("config.json").path

            var command = ConfigCommand.EditCommand()
            command.printPath = true
            try await command.run(using: self.makeRuntime())

            #expect(!FileManager.default.fileExists(atPath: configPath))
        }
    }
}
