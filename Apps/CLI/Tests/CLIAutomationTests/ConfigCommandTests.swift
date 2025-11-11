import Foundation
import Testing
@testable import PeekabooCLI

@Suite("ConfigCommand Tests", .tags(.safe))
struct ConfigCommandTests {
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
}
