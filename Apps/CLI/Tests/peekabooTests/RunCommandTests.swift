import AXorcist
import Foundation
import PeekabooCore
import Testing
@testable import peekaboo

@Suite("RunCommand Tests", .serialized)
struct RunCommandTests {
    @Test("Run command parses script path")
    func parseScriptPath() throws {
        let command = try RunCommand.parse(["/path/to/script.peekaboo.json"])
        #expect(command.scriptPath == "/path/to/script.peekaboo.json")
        #expect(command.output == nil)
        #expect(command.noFailFast == false) // default
        #expect(command.verbose == false) // default
    }

    @Test("Run command parses all options")
    func parseAllOptions() throws {
        let command = try RunCommand.parse([
            "/tmp/automation.peekaboo.json",
            "--output", "results.json",
            "--no-fail-fast",
            "--verbose",
        ])
        #expect(command.scriptPath == "/tmp/automation.peekaboo.json")
        #expect(command.output == "results.json")
        #expect(command.noFailFast == true)
        #expect(command.verbose == true)
    }

    @Test("Run command requires script path")
    func requiresScriptPath() {
        #expect(throws: Error.self) {
            _ = try RunCommand.parse([])
        }
    }

    @Test("Script structure validation")
    func scriptStructure() {
        // Create script steps with proper structure
        let steps = [
            TestScriptStep(
                stepId: "step1",
                comment: "Capture Safari UI",
                command: "see",
                params: ["app": "Safari"]
            ),
            TestScriptStep(
                stepId: "step2",
                comment: "Click login button",
                command: "click",
                params: ["query": "Login"]
            ),
            TestScriptStep(
                stepId: "step3",
                comment: nil,
                command: "type",
                params: ["text": "user@example.com", "on": "T1"]
            ),
        ]

        let script = TestPeekabooScript(
            description: "Automates the login flow",
            steps: steps
        )

        #expect(script.description == "Automates the login flow")
        #expect(script.steps.count == 3)
        #expect(script.steps[0].command == "see")
        #expect(script.steps[0].params?["app"] == "Safari")
        #expect(script.steps[0].comment == "Capture Safari UI")
        #expect(script.steps[2].comment == nil)
    }

    @Test("Run result structure")
    func runResultStructure() {
        let stepResults = [
            StepResult(
                stepId: "step1",
                stepNumber: 1,
                command: "see",
                success: true,
                output: AnyCodable(["success": true]),
                error: nil,
                executionTime: 1.5
            ),
            StepResult(
                stepId: "step2",
                stepNumber: 2,
                command: "click",
                success: false,
                output: nil,
                error: "Element not found",
                executionTime: 2.0
            ),
        ]

        let result = ScriptExecutionResult(
            success: false,
            scriptPath: "/tmp/test.peekaboo.json",
            description: "Test script",
            totalSteps: 5,
            completedSteps: 1,
            failedSteps: 1,
            executionTime: 12.5,
            steps: stepResults
        )

        #expect(result.success == false)
        #expect(result.scriptPath == "/tmp/test.peekaboo.json")
        #expect(result.totalSteps == 5)
        #expect(result.completedSteps == 1)
        #expect(result.failedSteps == 1)
        #expect(result.executionTime == 12.5)
        #expect(result.steps.count == 2)
        #expect(result.steps[1].error == "Element not found")
    }

    @Test("Script JSON parsing")
    func scriptJSONParsing() throws {
        let jsonData = """
        {
            "description": "A test automation script",
            "steps": [
                {
                    "stepId": "step1",
                    "command": "see",
                    "params": {
                        "app": "Finder"
                    }
                },
                {
                    "stepId": "step2",
                    "command": "sleep",
                    "params": {
                        "duration": "1000"
                    },
                    "comment": "Wait for UI to settle"
                }
            ]
        }
        """.data(using: .utf8)!

        let script = try JSONDecoder().decode(TestPeekabooScript.self, from: jsonData)
        #expect(script.description == "A test automation script")
        #expect(script.steps.count == 2)
        #expect(script.steps[1].comment == "Wait for UI to settle")
    }
}

// MARK: - Test Helper Types

struct TestPeekabooScript: Codable {
    let description: String?
    let steps: [TestScriptStep]
}

struct TestScriptStep: Codable {
    let stepId: String
    let comment: String?
    let command: String
    let params: [String: String]?
}
