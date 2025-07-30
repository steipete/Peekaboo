import Foundation
import Testing
@testable import peekaboo

@Suite("Agent Shell Command Tests")
struct AgentShellCommandTests {
    @Test("Shell function is included in agent tools")
    func shellFunctionExists() {
        // Verify shell tool is created with correct parameters
        let shellTool = OpenAIAgent.makePeekabooTool(
            "shell",
            "Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)"
        )

        #expect(shellTool.type == "function")
        #expect(shellTool.function.name == "peekaboo_shell")
        #expect(shellTool.function
            .description == "Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)"
        )

        // Check parameters
        let params = shellTool.function.parameters.dictionary
        #expect(params["type"] as? String == "object")

        let properties = params["properties"] as? [String: Any]
        #expect(properties != nil)

        let commandParam = properties?["command"] as? [String: Any]
        #expect(commandParam?["type"] as? String == "string")
        #expect(commandParam?["description"] as? String ==
            "Shell command to execute (e.g., 'open https://google.com', 'ls -la', 'echo Hello')"
        )

        let required = params["required"] as? [String]
        #expect(required == ["command"])
    }

    @Test("Agent executor handles shell commands")
    @available(macOS 14.0, *)
    func executorHandlesShellCommand() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test echo command
        let result = try await executor.executeFunction(
            name: "peekaboo_shell",
            arguments: """
            {"command": "echo 'Hello from shell'"}
            """
        )

        // Parse result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)

        let resultData = json["data"] as? [String: Any]
        #expect(resultData != nil)
        #expect(resultData?["exit_code"] as? Int == 0)
        #expect((resultData?["output"] as? String)?.contains("Hello from shell") == true)
    }

    @Test("Shell command handles errors correctly")
    @available(macOS 14.0, *)
    func shellCommandErrorHandling() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test command that should fail
        let result = try await executor.executeFunction(
            name: "peekaboo_shell",
            arguments: """
            {"command": "false"}
            """
        )

        // Parse result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)

        let error = json["error"] as? [String: Any]
        #expect(error != nil)
        #expect(error?["code"] as? String == "SHELL_COMMAND_FAILED")
        #expect((error?["message"] as? String)?.contains("exited with code") == true)
    }

    @Test("Shell command respects timeout")
    @available(macOS 14.0, *)
    func shellCommandTimeout() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test command that would hang without timeout
        let result = try await executor.executeFunction(
            name: "peekaboo_shell",
            arguments: """
            {"command": "sleep 5", "timeout": 1}
            """
        )

        // Parse result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Should fail due to timeout
        #expect(json["success"] as? Bool == false)

        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "COMMAND_FAILED")
        #expect((error?["message"] as? String)?.contains("timed out") == true)
    }

    @Test("Shell command uses zsh")
    @available(macOS 14.0, *)
    func shellCommandUsesZsh() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test zsh-specific syntax
        let result = try await executor.executeFunction(
            name: "peekaboo_shell",
            arguments: """
            {"command": "echo $ZSH_VERSION"}
            """
        )

        // Parse result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)

        let resultData = json["data"] as? [String: Any]
        let output = resultData?["output"] as? String ?? ""

        // Should have zsh version in output (not empty)
        #expect(!output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("Shell command handles complex commands")
    @available(macOS 14.0, *)
    func shellCommandComplexCommands() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test piping and multiple commands
        let result = try await executor.executeFunction(
            name: "peekaboo_shell",
            arguments: """
            {"command": "echo 'test' | tr 'a-z' 'A-Z'"}
            """
        )

        // Parse result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)

        let resultData = json["data"] as? [String: Any]
        let output = resultData?["output"] as? String ?? ""

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "TEST")
    }

    @Test("Shell command validates required parameters")
    @available(macOS 14.0, *)
    func shellCommandParameterValidation() async throws {
        let executor = AgentExecutor(verbose: false)

        // Test missing command parameter
        let result = try await executor.executeFunction(
            name: "peekaboo_shell",
            arguments: """
            {}
            """
        )

        // Parse result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)

        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
        #expect((error?["message"] as? String)?.contains("Shell command requires") == true)
    }
}
