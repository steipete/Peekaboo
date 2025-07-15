import Testing
import Foundation
import ArgumentParser
@testable import peekaboo

@Suite("TypeCommand Tests")
struct TypeCommandTests {
    
    @Test("Type command with text argument")
    func typeWithText() async throws {
        var command = TypeCommand()
        command.text = "Hello World"
        command.jsonOutput = true
        
        // We can't directly test the command execution since it requires
        // actual system permissions and UI interaction.
        // Instead, we'll test the command configuration and argument parsing.
        
        #expect(command.text == "Hello World")
        #expect(command.jsonOutput == true)
        #expect(command.delay == 5) // default delay
        #expect(command.pressReturn == false)
        #expect(command.clear == false)
    }
    
    @Test("Type command with special keys")
    func typeWithSpecialKeys() async throws {
        var command = TypeCommand()
        command.tab = 2
        command.pressReturn = true
        command.jsonOutput = true
        
        #expect(command.text == nil)
        #expect(command.tab == 2)
        #expect(command.pressReturn == true)
        #expect(command.escape == false)
        #expect(command.delete == false)
    }
    
    @Test("Type command with clear flag")
    func typeWithClear() async throws {
        var command = TypeCommand()
        command.text = "New Text"
        command.clear = true
        command.jsonOutput = true
        
        #expect(command.text == "New Text")
        #expect(command.clear == true)
        #expect(command.delay == 5) // default delay
    }
    
    @Test("Type command with custom delay")
    func typeWithCustomDelay() async throws {
        var command = TypeCommand()
        command.text = "Fast"
        command.delay = 0
        command.jsonOutput = true
        
        #expect(command.text == "Fast")
        #expect(command.delay == 0)
    }
    
    @Test("Type command argument parsing")
    func typeCommandArgumentParsing() throws {
        // Test parsing with ArgumentParser
        let arguments = ["type", "Hello World", "--delay", "10", "--return"]
        let command = try Peekaboo.parseAsRoot(arguments) as? TypeCommand
        
        #expect(command != nil)
        if let typeCommand = command {
            #expect(typeCommand.text == "Hello World")
            #expect(typeCommand.delay == 10)
            #expect(typeCommand.pressReturn == true)
        }
    }
    
    @Test("Type command with all special keys")
    func typeWithAllSpecialKeys() async throws {
        var command = TypeCommand()
        command.text = "Test"
        command.clear = true
        command.tab = 1
        command.pressReturn = true
        command.escape = true
        command.delete = true
        command.jsonOutput = true
        
        #expect(command.text == "Test")
        #expect(command.clear == true)
        #expect(command.tab == 1)
        #expect(command.pressReturn == true)
        #expect(command.escape == true)
        #expect(command.delete == true)
    }
}