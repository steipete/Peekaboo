import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "MoveCommand Tests",
    .serialized,
    .tags(.safe),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct MoveCommandTests {
    @Test("move --help lists options")
    func moveHelp() async throws {
        let context = await self.makeContext()
        let result = try await self.runMove(arguments: ["--help"], context: context)

        #expect(result.exitStatus == 0)
        #expect(self.output(from: result).contains("Move the mouse cursor"))
    }

    @Test("Coordinate moves call automation service")
    func coordinateMove() async throws {
        let context = await self.makeContext()
        let result = try await self.runMove(arguments: ["100,200", "--duration", "750", "--steps", "10"], context: context)

        #expect(result.exitStatus == 0)
        let moveCalls = await self.automationState(context) { $0.moveMouseCalls }
        let call = try #require(moveCalls.first)
        #expect(call.destination == CGPoint(x: 100, y: 200))
        #expect(call.duration == 750)
        #expect(call.steps == 10)
    }

    @Test("Move command requires a target")
    func requiresTarget() async throws {
        let context = await self.makeContext()
        let result = try await self.runMove(arguments: [], context: context)

        #expect(result.exitStatus != 0)
        let moveCalls = await self.automationState(context) { $0.moveMouseCalls }
        #expect(moveCalls.isEmpty)
    }

    @Test("Move by element ID resolves using stored detection results")
    func moveByElementId() async throws {
        let context = await self.makeContext()
        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "Submit",
            bounds: CGRect(x: 50, y: 70, width: 120, height: 40)
        )
        let detection = ElementDetectionResult(
            sessionId: "session-id",
            screenshotPath: "/tmp/screenshot.png",
            elements: DetectedElements(buttons: [element]),
            metadata: DetectionMetadata(detectionTime: 0, elementCount: 1, method: "stub")
        )
        try await context.sessions.storeDetectionResult(sessionId: "session-id", result: detection)

        let result = try await self.runMove(arguments: ["--id", "B1", "--session", "session-id", "--json-output"], context: context)

        #expect(result.exitStatus == 0)
        let moveCalls = await self.automationState(context) { $0.moveMouseCalls }
        let call = try #require(moveCalls.first)
        #expect(call.destination.x == element.bounds.midX)
        #expect(call.destination.y == element.bounds.midY)
    }

    @Test("Move by query waits for element using automation service")
    func moveByQuery() async throws {
        let context = await self.makeContext { automation, sessions in
            sessions.mostRecentSessionId = "session-query"
            let element = DetectedElement(
                id: "B2",
                type: .button,
                label: "Continue",
                bounds: CGRect(x: 200, y: 300, width: 80, height: 24)
            )
            automation.setWaitForElementResult(
                WaitForElementResult(found: true, element: element, waitTime: 0.05),
                for: .query("Continue")
            )
        }

        let result = try await self.runMove(arguments: ["--to", "Continue"], context: context)

        #expect(result.exitStatus == 0)
        let waitCalls = await self.automationState(context) { $0.waitForElementCalls }
        #expect(waitCalls.count == 1)
        let moveCalls = await self.automationState(context) { $0.moveMouseCalls }
        let call = try #require(moveCalls.first)
        #expect(call.destination == CGPoint(x: 240, y: 312)) // mid-point of element bounds
    }

    @Test("JSON output contains expected shape")
    func jsonOutput() async throws {
        let context = await self.makeContext()
        let result = try await self.runMove(arguments: ["150,250", "--json-output"], context: context)

        #expect(result.exitStatus == 0)
        let data = try #require(self.output(from: result).data(using: .utf8))
        let payload = try JSONDecoder().decode(MoveResult.self, from: data)
        #expect(payload.success)
        #expect(payload.targetDescription.contains("Coordinates"))
        #expect(payload.targetLocation["x"] == 150)
        #expect(payload.targetLocation["y"] == 250)
    }

    // MARK: - Helpers

    private func runMove(
        arguments: [String],
        context: TestServicesFactory.AutomationTestContext
    ) async throws -> CommandRunResult {
        try await InProcessCommandRunner.run(["move"] + arguments, services: context.services)
    }

    private func output(from result: CommandRunResult) -> String {
        result.stdout.isEmpty ? result.stderr : result.stdout
    }

    private func makeContext(
        configure: (@MainActor (StubAutomationService, StubSessionManager) -> Void)? = nil
    ) async -> TestServicesFactory.AutomationTestContext {
        await MainActor.run {
            let context = TestServicesFactory.makeAutomationTestContext()
            configure?(context.automation, context.sessions)
            return context
        }
    }

    private func automationState<T: Sendable>(
        _ context: TestServicesFactory.AutomationTestContext,
        _ operation: @MainActor (StubAutomationService) -> T
    ) async -> T {
        await MainActor.run {
            operation(context.automation)
        }
    }
}
#endif
