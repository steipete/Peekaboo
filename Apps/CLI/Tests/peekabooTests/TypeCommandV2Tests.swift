import Testing
import Foundation
@testable import peekaboo

@available(macOS 14.0, *)
@Suite("TypeCommandV2 Tests")
struct TypeCommandV2Tests {
    
    @Test("Type command with text argument")
    func typeWithText() async throws {
        let cli = CLI()
        let result = try await cli.run(args: ["type-v2", "Hello World", "--json-output"])
        
        #expect(result.exitCode == 0)
        
        let output = try #require(result.jsonOutput)
        #expect(output["success"] as? Bool == true)
        #expect(output["typedText"] as? String == "Hello World")
        #expect(output["totalCharacters"] as? Int == 11)
        #expect(output["keyPresses"] as? Int == 0)
    }
    
    @Test("Type command with special keys")
    func typeWithSpecialKeys() async throws {
        let cli = CLI()
        let result = try await cli.run(args: ["type-v2", "--tab", "2", "--return", "--json-output"])
        
        #expect(result.exitCode == 0)
        
        let output = try #require(result.jsonOutput)
        #expect(output["success"] as? Bool == true)
        #expect(output["typedText"] as? String == nil)
        #expect(output["totalCharacters"] as? Int == 0)
        #expect(output["keyPresses"] as? Int == 3) // 2 tabs + 1 return
    }
    
    @Test("Type command with clear flag")
    func typeWithClear() async throws {
        let cli = CLI()
        let result = try await cli.run(args: ["type-v2", "New Text", "--clear", "--json-output"])
        
        #expect(result.exitCode == 0)
        
        let output = try #require(result.jsonOutput)
        #expect(output["success"] as? Bool == true)
        #expect(output["typedText"] as? String == "New Text")
        #expect(output["totalCharacters"] as? Int == 8)
        #expect(output["keyPresses"] as? Int == 2) // Cmd+A and Delete for clear
    }
    
    @Test("Type command with custom delay")
    func typeWithCustomDelay() async throws {
        let cli = CLI()
        let result = try await cli.run(args: ["type-v2", "Fast", "--delay", "0", "--json-output"])
        
        #expect(result.exitCode == 0)
        
        let output = try #require(result.jsonOutput)
        #expect(output["success"] as? Bool == true)
        #expect(output["typedText"] as? String == "Fast")
        #expect(output["totalCharacters"] as? Int == 4)
    }
    
    @Test("Type command with no input should fail")
    func typeWithNoInput() async throws {
        let cli = CLI()
        let result = try await cli.run(args: ["type-v2", "--json-output"])
        
        #expect(result.exitCode != 0)
        
        let output = try #require(result.jsonOutput)
        #expect(output["error"] as? String != nil)
        #expect(output["code"] as? String == "INVALID_INPUT")
    }
    
    @Test("Type command with all special keys")
    func typeWithAllSpecialKeys() async throws {
        let cli = CLI()
        let result = try await cli.run(args: [
            "type-v2",
            "Test",
            "--clear",
            "--tab", "1",
            "--return",
            "--escape",
            "--delete",
            "--json-output"
        ])
        
        #expect(result.exitCode == 0)
        
        let output = try #require(result.jsonOutput)
        #expect(output["success"] as? Bool == true)
        #expect(output["typedText"] as? String == "Test")
        #expect(output["totalCharacters"] as? Int == 4)
        #expect(output["keyPresses"] as? Int == 6) // 2 for clear + 1 tab + 1 return + 1 escape + 1 delete
    }
}