import Testing
import Foundation
import PeekabooCore
@testable import peekaboo

@Suite("DockCommand")
struct DockCommandTests {
    
    @Test("Help output is consistent with V1")
    func helpOutput() async throws {
        // Test that the help command provides comprehensive information
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "peekaboo", "dock", "--help"]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Check for expected help content
        #expect(output.contains("Interact with the macOS Dock"))
        #expect(output.contains("launch"))
        #expect(output.contains("right-click"))
        #expect(output.contains("hide"))
        #expect(output.contains("show"))
        #expect(output.contains("list"))
    }
    
    @Test("List command JSON structure", .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil))
    func listCommandJSON() async throws {
        // Test that list command returns valid JSON
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "peekaboo", "dock", "list", "--json-output"]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Parse JSON
        let jsonData = output.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONResponse.self, from: jsonData)
        
        #expect(response.success == true)
        #expect(response.data != nil)
        
        // Check for expected data structure
        if let data = response.data?.value as? [String: Any] {
            #expect(data["dock_items"] != nil)
            #expect(data["count"] != nil)
        }
    }
}
