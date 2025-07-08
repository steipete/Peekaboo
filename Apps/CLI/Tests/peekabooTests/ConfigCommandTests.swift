import Testing
import ArgumentParser
import Foundation
@testable import peekaboo

@available(macOS 14.0, *)
@Suite("ConfigCommand Tests")
struct ConfigCommandTests {
    
    @Test("ConfigCommand exists and has correct subcommands")
    func testConfigCommandStructure() {
        // Verify the command exists
        let command = ConfigCommand.self
        
        // Check command configuration
        #expect(command.configuration.commandName == "config")
        #expect(command.configuration.abstract == "Manage Peekaboo configuration using PeekabooCore")
        
        // Check subcommands
        let subcommands = command.configuration.subcommands
        #expect(subcommands.count == 5)
        #expect(subcommands.contains { $0 == ConfigCommand.InitCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommand.ShowCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommand.EditCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommand.ValidateCommand.self })
        #expect(subcommands.contains { $0 == ConfigCommand.SetCredentialCommand.self })
    }
    
    @Test("InitCommand has correct configuration")
    func testInitCommand() {
        let command = ConfigCommand.InitCommand.self
        #expect(command.configuration.commandName == "init")
        #expect(command.configuration.abstract == "Create a default configuration file")
    }
    
    @Test("ShowCommand has correct configuration")
    func testShowCommand() {
        let command = ConfigCommand.ShowCommand.self
        #expect(command.configuration.commandName == "show")
        #expect(command.configuration.abstract == "Display current configuration")
    }
    
    @Test("EditCommand has correct configuration")
    func testEditCommand() {
        let command = ConfigCommand.EditCommand.self
        #expect(command.configuration.commandName == "edit")
        #expect(command.configuration.abstract == "Open configuration file in your default editor")
    }
    
    @Test("ValidateCommand has correct configuration")
    func testValidateCommand() {
        let command = ConfigCommand.ValidateCommand.self
        #expect(command.configuration.commandName == "validate")
        #expect(command.configuration.abstract == "Validate configuration file syntax")
    }
    
    @Test("SetCredentialCommand has correct configuration")
    func testSetCredentialCommand() {
        let command = ConfigCommand.SetCredentialCommand.self
        #expect(command.configuration.commandName == "set-credential")
        #expect(command.configuration.abstract == "Set an API key or credential securely")
    }
}