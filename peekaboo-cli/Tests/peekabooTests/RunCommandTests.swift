import Foundation
@testable import peekaboo
import Testing

#if os(macOS) && swift(>=5.9)
@available(macOS 14.0, *)
@Suite("RunCommand Tests")
struct RunCommandTests {
    @Test("Run command parses script path")
    func parseScriptPath() throws {
        let command = try RunCommand.parse(["/path/to/script.peekaboo.json"])
        #expect(command.scriptPath == "/path/to/script.peekaboo.json")
        #expect(command.session == nil)
        #expect(command.stopOnError == true) // default
        #expect(command.timeout == 300_000) // default 5 minutes
    }

    @Test("Run command parses all options")
    func parseAllOptions() throws {
        let command = try RunCommand.parse([
            "/tmp/automation.peekaboo.json",
            "--session", "test-123",
            "--continue-on-error",
            "--timeout", "60000",
            "--json-output"
        ])
        #expect(command.scriptPath == "/tmp/automation.peekaboo.json")
        #expect(command.session == "test-123")
        #expect(command.stopOnError == false) // inverted by --continue-on-error
        #expect(command.timeout == 60000)
        #expect(command.jsonOutput == true)
    }

    @Test("Run command requires script path")
    func requiresScriptPath() {
        #expect(throws: Error.self) {
            _ = try RunCommand.parse([])
        }
    }

    @Test("Script structure validation")
    func scriptStructure() {
        let script = PeekabooScript(
            name: "Login Automation",
            description: "Automates the login flow",
            commands: [
                PeekabooScript.Command(
                    command: "see",
                    args: ["--app", "Safari"],
                    comment: "Capture Safari UI"
                ),
                PeekabooScript.Command(
                    command: "click",
                    args: ["Login"],
                    comment: "Click login button"
                ),
                PeekabooScript.Command(
                    command: "type",
                    args: ["user@example.com", "--on", "T1"],
                    comment: nil
                )
            ]
        )

        #expect(script.name == "Login Automation")
        #expect(script.description == "Automates the login flow")
        #expect(script.commands.count == 3)
        #expect(script.commands[0].command == "see")
        #expect(script.commands[0].args == ["--app", "Safari"])
        #expect(script.commands[0].comment == "Capture Safari UI")
        #expect(script.commands[2].comment == nil)
    }

    @Test("Run result structure")
    func runResultStructure() {
        let result = RunResult(
            success: false,
            scriptPath: "/tmp/test.peekaboo.json",
            commandsExecuted: 3,
            totalCommands: 5,
            sessionId: "session-123",
            executionTime: 12.5,
            errors: ["Command 4 failed: Element not found", "Command 5 failed: Timeout"]
        )

        #expect(result.success == false)
        #expect(result.scriptPath == "/tmp/test.peekaboo.json")
        #expect(result.commandsExecuted == 3)
        #expect(result.totalCommands == 5)
        #expect(result.sessionId == "session-123")
        #expect(result.executionTime == 12.5)
        #expect(result.errors?.count == 2)
        #expect(result.errors?.first == "Command 4 failed: Element not found")
    }

    @Test("Script JSON parsing")
    func scriptJSONParsing() throws {
        let jsonData = """
        {
            "name": "Test Script",
            "description": "A test automation script",
            "commands": [
                {
                    "command": "see",
                    "args": ["--app", "Finder"]
                },
                {
                    "command": "sleep",
                    "args": ["--duration", "1000"],
                    "comment": "Wait for UI to settle"
                }
            ]
        }
        """.data(using: .utf8)!

        let script = try JSONDecoder().decode(PeekabooScript.self, from: jsonData)
        #expect(script.name == "Test Script")
        #expect(script.commands.count == 2)
        #expect(script.commands[1].comment == "Wait for UI to settle")
    }
}
#endif
