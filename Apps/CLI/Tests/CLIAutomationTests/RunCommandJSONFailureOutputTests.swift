import Foundation
import PeekabooCore
import Testing

@testable import PeekabooCLI

@Suite("RunCommand JSON Failure Output", .serialized, .tags(.unit))
struct RunCommandJSONFailureOutputTests {
    @Test("run --json outputs a single JSON payload when steps fail")
    func runCommandJSONFailureDoesNotDoublePrint() async throws {
        let scriptPath = "/tmp/failing-json-script-\(UUID().uuidString).peekaboo.json"
        let script = PeekabooScript(
            description: "Failing script",
            steps: [
                ScriptStep(stepId: "fail", comment: nil, command: "click", params: nil)
            ]
        )

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

        let services = TestServicesFactory.makePeekabooServices(process: process)
        let result = try await InProcessCommandRunner.run([
            "run",
            scriptPath,
            "--json-output",
        ], services: services)

        #expect(result.exitStatus != 0)

        let data = Data(result.stdout.utf8)
        let payload = try JSONDecoder().decode(CodableJSONResponse<ScriptExecutionResult>.self, from: data)
        #expect(payload.success == false)
        #expect(payload.data.failedSteps == 1)
        #expect(payload.data.totalSteps == 1)
    }
}
