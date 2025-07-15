import Testing
import Foundation
@testable import Peekaboo
import PeekabooCore

@Suite("PeekabooToolExecutor Tests", .tags(.services, .unit))
@MainActor
struct PeekabooToolExecutorTests {
    
    @Test("Executor initializes with PeekabooCore services")
    func initialization() {
        let executor = PeekabooToolExecutor()
        
        // Verify executor is created (services are internal)
        #expect(executor != nil)
    }
    
    @Test("Execute see tool with valid arguments")
    func executeSeeValid() async throws {
        let executor = PeekabooToolExecutor()
        
        // Test with mode argument
        let args = """
        {
            "mode": "frontmost"
        }
        """
        
        let result = await executor.executeTool(name: "see", arguments: args)
        
        // Result should be valid JSON
        #expect(result.contains("{"))
        #expect(result.contains("}"))
        
        // Parse result to verify structure
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Should have either success with file path or error
            #expect(json["file"] != nil || json["error"] != nil)
        }
    }
    
    @Test("Execute see tool with invalid arguments")
    func executeSeeInvalid() async {
        let executor = PeekabooToolExecutor()
        
        // Test with invalid JSON
        let result = await executor.executeTool(name: "see", arguments: "not json")
        
        // Should return error
        #expect(result.contains("error"))
        #expect(result.contains("Invalid arguments"))
    }
    
    @Test("Execute click tool")
    func executeClick() async {
        let executor = PeekabooToolExecutor()
        
        // Test click with text target
        let args = """
        {
            "target": "OK"
        }
        """
        
        let result = await executor.executeTool(name: "click", arguments: args)
        
        // Should return JSON response
        #expect(result.contains("{"))
        #expect(result.contains("}"))
    }
    
    @Test("Execute type tool")
    func executeType() async {
        let executor = PeekabooToolExecutor()
        
        // Test typing text
        let args = """
        {
            "text": "Hello, World!"
        }
        """
        
        let result = await executor.executeTool(name: "type", arguments: args)
        
        // Should return JSON response
        #expect(result.contains("{"))
        #expect(result.contains("}"))
    }
    
    @Test("Execute hotkey tool")
    func executeHotkey() async {
        let executor = PeekabooToolExecutor()
        
        // Test command+a hotkey
        let args = """
        {
            "keys": "cmd+a"
        }
        """
        
        let result = await executor.executeTool(name: "hotkey", arguments: args)
        
        // Should return JSON response
        #expect(result.contains("{"))
        #expect(result.contains("}"))
    }
    
    @Test("Execute list tool for applications")
    func executeListApps() async {
        let executor = PeekabooToolExecutor()
        
        // Test listing applications
        let args = """
        {
            "target": "apps"
        }
        """
        
        let result = await executor.executeTool(name: "list", arguments: args)
        
        // Should return JSON with apps array
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(json["apps"] != nil || json["error"] != nil)
        }
    }
    
    @Test("Execute window tool")
    func executeWindow() async {
        let executor = PeekabooToolExecutor()
        
        // Test window focus
        let args = """
        {
            "action": "focus",
            "app": "Finder"
        }
        """
        
        let result = await executor.executeTool(name: "window", arguments: args)
        
        // Should return JSON response
        #expect(result.contains("{"))
        #expect(result.contains("}"))
    }
    
    @Test("Execute unknown tool")
    func executeUnknownTool() async {
        let executor = PeekabooToolExecutor()
        
        let result = await executor.executeTool(name: "unknown_tool", arguments: "{}")
        
        // Should return error for unknown tool
        #expect(result.contains("error"))
        #expect(result.contains("Unknown tool"))
    }
    
    @Test("Tool execution timing")
    func executionTiming() async {
        let executor = PeekabooToolExecutor()
        
        let startTime = Date()
        let result = await executor.executeTool(name: "list", arguments: """
        {
            "target": "apps"
        }
        """)
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time (5 seconds)
        #expect(duration < 5.0)
        
        // Result should contain execution time
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(json["executionTime"] != nil)
        }
    }
    
    @Test("Concurrent tool execution")
    func concurrentExecution() async {
        let executor = PeekabooToolExecutor()
        
        // Execute multiple tools concurrently
        async let result1 = executor.executeTool(name: "list", arguments: """
        {
            "target": "apps"
        }
        """)
        
        async let result2 = executor.executeTool(name: "list", arguments: """
        {
            "target": "windows",
            "app": "Finder"
        }
        """)
        
        let results = await [result1, result2]
        
        // Both should return valid JSON
        for result in results {
            #expect(result.contains("{"))
            #expect(result.contains("}"))
        }
    }
    
    @Test("Error handling and recovery")
    func errorHandling() async {
        let executor = PeekabooToolExecutor()
        
        // Test various error conditions
        let errorCases = [
            (name: "click", args: """{"target": ""}"""), // Empty target
            (name: "type", args: """{"text": null}"""), // Null text
            (name: "window", args: """{"action": "invalid"}"""), // Invalid action
        ]
        
        for errorCase in errorCases {
            let result = await executor.executeTool(name: errorCase.name, arguments: errorCase.args)
            
            // Should return error response, not crash
            #expect(result.contains("error") || result.contains("Error"))
        }
    }
}