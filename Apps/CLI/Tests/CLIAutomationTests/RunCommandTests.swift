import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "RunCommand CLI Harness Tests",
    .serialized,
    .tags(.safe),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct RunCommandCLIHarnessTests {
    @Test("run command executes scripts via process service")
    func runCommandOutputsJSON() async throws {
        let scriptPath = "/tmp/test-script.peekaboo.json"
        let script = PeekabooScript(
            description: "Sample script",
            steps: [
                ScriptStep(stepId: "step1", comment: "Capture UI", command: "see", params: nil),
                ScriptStep(stepId: "step2", comment: "Click login", command: "click", params: nil),
            ]
        )

        let stepResults = [
            StepResult(
                stepId: "step1",
                stepNumber: 1,
                command: "see",
                success: true,
                output: .success("Captured"),
                error: nil,
                executionTime: 0.5
            ),
            StepResult(
                stepId: "step2",
                stepNumber: 2,
                command: "click",
                success: true,
                output: .success("Clicked"),
                error: nil,
                executionTime: 0.3
            ),
        ]

        let process = StubProcessService()
        process.scriptsByPath[scriptPath] = script
        process.nextExecuteScriptResults = stepResults

        let services = await self.makeServices(process: process)
        let result = try await InProcessCommandRunner.run([
            "run",
            scriptPath,
            "--json",
        ], services: services)

        #expect(result.exitStatus == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let payload = try JSONDecoder().decode(CodableJSONResponse<ScriptExecutionResult>.self, from: data)
        #expect(payload.data.totalSteps == 2)
        #expect(payload.data.success)
        #expect(process.loadScriptCalls.count == 1)
        #expect(process.executeScriptCalls.count == 1)
    }

    @Test("run command writes output file")
    func runCommandWritesOutputFile() async throws {
        let scriptPath = "/tmp/output-script.peekaboo.json"
        let script = PeekabooScript(description: "Write output", steps: [])
        let process = StubProcessService()
        process.scriptsByPath[scriptPath] = script
        process.nextExecuteScriptResults = []

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("run-results-\(UUID().uuidString).json")

        defer { try? FileManager.default.removeItem(at: outputURL) }

        let services = await self.makeServices(process: process)
        let result = try await InProcessCommandRunner.run([
            "run",
            scriptPath,
            "--output", outputURL.path,
        ], services: services)

        #expect(result.exitStatus == 0)
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        let data = try Data(contentsOf: outputURL)
        let payload = try JSONDecoder().decode(ScriptExecutionResult.self, from: data)
        #expect(payload.scriptPath == scriptPath)
    }

    @Test("run command exits with failure when a step fails")
    func runCommandFailure() async throws {
        let scriptPath = "/tmp/failing-script.peekaboo.json"
        let script = PeekabooScript(description: "Failing script", steps: [
            ScriptStep(stepId: "fail", comment: nil, command: "click", params: nil),
        ])
        let failingStep = StepResult(
            stepId: "fail",
            stepNumber: 1,
            command: "click",
            success: false,
            output: nil,
            error: "Element not found",
            executionTime: 0.2
        )

        let process = StubProcessService()
        process.scriptsByPath[scriptPath] = script
        process.nextExecuteScriptResults = [failingStep]

        let services = await self.makeServices(process: process)
        let result = try await InProcessCommandRunner.run(["run", scriptPath], services: services)

        #expect(result.exitStatus != 0)
        let output = result.stdout + result.stderr
        #expect(output.contains("❌ Script failed") || output.contains("❌ Error"))
    }

    @MainActor
    private func makeServices(process: StubProcessService) -> PeekabooServices {
        TestServicesFactory.makePeekabooServices(process: process)
    }
}
#endif

@Suite("RunCommand Data Tests", .serialized, .tags(.unit))
struct RunCommandDataTests {
    @Test("Run command parses script path")
    func parseScriptPath() throws {
        let command = try RunCommand.parse(["/path/to/script.peekaboo.json"])
        #expect(command.scriptPath == "/path/to/script.peekaboo.json")
        #expect(command.output == nil)
        #expect(command.noFailFast == false)
    }

    @Test("Run command parses all options")
    func parseAllOptions() throws {
        let command = try RunCommand.parse([
            "/tmp/automation.peekaboo.json",
            "--output", "results.json",
            "--no-fail-fast",
        ])
        #expect(command.scriptPath == "/tmp/automation.peekaboo.json")
        #expect(command.output == "results.json")
        #expect(command.noFailFast == true)
    }

    @Test("Run command requires script path")
    func requiresScriptPath() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try RunCommand.parse([])
            }
        }
    }

    @Test("Script structure validation")
    func scriptStructure() {
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
                output: .success("Step completed successfully"),
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
        let jsonString = """
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
        """
        let jsonData = Data(jsonString.utf8)

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
