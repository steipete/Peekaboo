import Testing
import ArgumentParser
import Foundation
@testable import peekaboo

@available(macOS 14.0, *)
@Suite("ConfigCommandV2 Tests")
struct ConfigCommandV2Tests {
    
    @Test("ConfigCommandV2 exists and has correct subcommands")
    func testConfigCommandV2Structure() {
        // Verify the command exists
        let command = ConfigCommandV2.self
        
        // Check command configuration
        #expect(command.configuration.commandName == "config-v2")
        #expect(command.configuration.abstract == "Manage Peekaboo configuration using PeekabooCore")
        
        // Check subcommands
        let subcommands = command.configuration.subcommands
        #expect(subcommands.count == 5)
        #expect(subcommands.contains { $0 == ConfigCommandV2.InitCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommandV2.ShowCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommandV2.EditCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommandV2.ValidateCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommandV2.SetCredentialCommand.self })
    }
    
    @Test("InitCommand has correct configuration")
    func testInitCommand() {
        let command = ConfigCommandV2.InitCommand.self
        #expect(command.configuration.commandName == "init")
        #expect(command.configuration.abstract == "Create a default configuration file")
    }
    
    @Test("ShowCommand has correct configuration")
    func testShowCommand() {
        let command = ConfigCommandV2.ShowCommand.self
        #expect(command.configuration.commandName == "show")
        #expect(command.configuration.abstract == "Display current configuration")
    }
    
    @Test("EditCommand has correct configuration")
    func testEditCommand() {
        let command = ConfigCommandV2.EditCommand.self
        #expect(command.configuration.commandName == "edit")
        #expect(command.configuration.abstract == "Open configuration file in your default editor")
    }
    
    @Test("ValidateCommand has correct configuration")
    func testValidateCommand() {
        let command = ConfigCommandV2.ValidateCommand.self
        #expect(command.configuration.commandName == "validate")
        #expect(command.configuration.abstract == "Validate configuration file syntax")
    }
    
    @Test("SetCredentialCommand has correct configuration")
    func testSetCredentialCommand() {
        let command = ConfigCommandV2.SetCredentialCommand.self
        #expect(command.configuration.commandName == "set-credential")
        #expect(command.configuration.abstract == "Set an API key or credential securely")
    }
}