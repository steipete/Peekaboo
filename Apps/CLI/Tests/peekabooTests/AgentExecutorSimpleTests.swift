import Foundation
import Testing
@testable import peekaboo

@Suite("Agent Executor Simple Tests")
struct AgentExecutorSimpleTests {
    @Test("AgentExecutor initializes correctly")
    @available(macOS 14.0, *)
    func executorInitialization() {
        let executor = AgentExecutor(verbose: false)
        #expect(executor.verbose == false)

        let verboseExecutor = AgentExecutor(verbose: true)
        #expect(verboseExecutor.verbose == true)
    }

    @Test("AgentExecutor handles invalid JSON arguments")
    @available(macOS 14.0, *)
    func invalidJSONArguments() async throws {
        let executor = AgentExecutor(verbose: false)
        let invalidJSON = "{invalid json"

        let result = try await executor.executeFunction(name: "peekaboo_see", arguments: invalidJSON)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
        #expect((error?["message"] as? String ?? "").contains("Failed to parse JSON"))
    }

    @Test("AgentExecutor handles unknown commands")
    @available(macOS 14.0, *)
    func unknownCommand() async throws {
        let executor = AgentExecutor(verbose: false)
        let args: [String: Any] = [:]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_unknown", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
        #expect((error?["message"] as? String ?? "").contains("Unknown command"))
    }

    @Test("AgentExecutor executes wait command")
    @available(macOS 14.0, *)
    func executeWaitCommand() async throws {
        let executor = AgentExecutor(verbose: false)
        let args = ["duration": 0.01] // 10ms to keep test fast
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let start = Date()
        let result = try await executor.executeFunction(name: "peekaboo_wait", arguments: argsString)
        let elapsed = Date().timeIntervalSince(start)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)
        #expect(elapsed >= 0.01)

        let responseData = json["data"] as? [String: Any]
        #expect((responseData?["message"] as? String ?? "").contains("Waited for"))
    }

    @Test("AgentExecutor handles missing required parameters")
    @available(macOS 14.0, *)
    func missingRequiredParameters() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test click without required parameters
        let clickArgs: [String: Any] = [:]
        let clickArgsJSON = try JSONSerialization.data(withJSONObject: clickArgs)
        let clickArgsString = String(data: clickArgsJSON, encoding: .utf8)!

        let clickResult = try await executor.executeFunction(name: "peekaboo_click", arguments: clickArgsString)
        let clickData = clickResult.data(using: .utf8)!
        let clickJSON = try JSONSerialization.jsonObject(with: clickData) as! [String: Any]

        #expect(clickJSON["success"] as? Bool == false)
        let clickError = clickJSON["error"] as? [String: Any]
        #expect(clickError?["code"] as? String == "INVALID_ARGUMENTS")

        // Test type without required text parameter
        let typeArgs: [String: Any] = [:]
        let typeArgsJSON = try JSONSerialization.data(withJSONObject: typeArgs)
        let typeArgsString = String(data: typeArgsJSON, encoding: .utf8)!

        let typeResult = try await executor.executeFunction(name: "peekaboo_type", arguments: typeArgsString)
        let typeData = typeResult.data(using: .utf8)!
        let typeJSON = try JSONSerialization.jsonObject(with: typeData) as! [String: Any]

        #expect(typeJSON["success"] as? Bool == false)
        let typeError = typeJSON["error"] as? [String: Any]
        #expect(typeError?["code"] as? String == "INVALID_ARGUMENTS")
    }

    @Test("AgentExecutor handles shell command")
    @available(macOS 14.0, *)
    func executeShellCommand() async throws {
        let executor = AgentExecutor(verbose: false)
        let args = ["command": "echo 'test'", "timeout": 5]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_shell", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)
        let responseData = json["data"] as? [String: Any]
        #expect(responseData?["output"] as? String == "test\n")
        #expect(responseData?["exit_code"] as? Int == 0)
    }

    @Test("AgentExecutor handles all implemented commands")
    @available(macOS 14.0, *)
    func allCommandsRecognized() async throws {
        let executor = AgentExecutor(verbose: false)
        let commands = [
            "see", "click", "type", "app", "window", "image",
            "wait", "hotkey", "scroll", "analyze_screenshot",
            "list", "shell", "menu", "dialog", "drag", "dock", "swipe"
        ]

        for command in commands {
            let args: [String: Any] = [:]
            let argsJSON = try JSONSerialization.data(withJSONObject: args)
            let argsString = String(data: argsJSON, encoding: .utf8)!

            let result = try await executor.executeFunction(name: "peekaboo_\(command)", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // Should not get "Unknown command" error
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                #expect(!message.contains("Unknown command"), "Command \(command) should be recognized")
            }
        }
    }
}
