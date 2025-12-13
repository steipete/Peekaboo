import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "ScrollCommand Tests",
    .serialized,
    .tags(.safe),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct ScrollCommandTests {
    @Test("scroll --help surfaces command documentation")
    func scrollHelp() async throws {
        let context = await self.makeContext()
        let result = try await self.runScroll(arguments: ["--help"], context: context)

        #expect(result.exitStatus == 0)
        let output = self.output(from: result)
        #expect(output.contains("Scroll the mouse wheel in any direction"))
    }

    @Test("Scroll command requires a direction")
    func requiresDirection() async throws {
        let context = await self.makeContext()
        let result = try await self.runScroll(arguments: [], context: context)

        #expect(result.exitStatus != 0)
        let output = self.output(from: result)
        #expect(output.contains("--direction"))
        let scrollCalls = await self.automationState(context) { $0.scrollCalls }
        #expect(scrollCalls.isEmpty)
    }

    @Test("Scroll forwards parameters to automation service")
    func forwardsParameters() async throws {
        let context = await self.makeContext()
        let result = try await self.runScroll(
            arguments: [
                "--direction", "down",
                "--amount", "5",
                "--delay", "10",
                "--smooth",
                "--snapshot", "snapshot-42",
                "--on", "B1",
                "--json-output",
            ],
            context: context
        )

        #expect(result.exitStatus == 0)

        let scrollCalls = await self.automationState(context) { $0.scrollCalls }
        let call = try #require(scrollCalls.first)
        #expect(call.request.direction == .down)
        #expect(call.request.amount == 5)
        #expect(call.request.delay == 10)
        #expect(call.request.smooth == true)
        #expect(call.request.target == "B1")
        #expect(call.request.snapshotId == "snapshot-42")

        let payloadData = try #require(self.output(from: result).data(using: .utf8))
        let payload = try JSONDecoder().decode(ScrollResult.self, from: payloadData)
        #expect(payload.success)
        #expect(payload.direction == "down")
        #expect(payload.amount == 5)
    }

    @Test("Scroll without snapshot still executes")
    func executesWithoutSnapshot() async throws {
        let context = await self.makeContext()
        let result = try await self.runScroll(
            arguments: ["--direction", "up", "--amount", "2"],
            context: context
        )

        #expect(result.exitStatus == 0)
        let scrollCalls = await self.automationState(context) { $0.scrollCalls }
        #expect(scrollCalls.count == 1)
        let call = try #require(scrollCalls.first)
        #expect(call.request.snapshotId == nil)
        #expect(call.request.amount == 2)
    }

    @Test("Smooth scrolling adjusts total ticks in JSON output")
    func smoothScrollingIncreasesTicks() async throws {
        let context = await self.makeContext()
        let result = try await self.runScroll(
            arguments: ["--direction", "down", "--amount", "4", "--smooth", "--json-output"],
            context: context
        )

        #expect(result.exitStatus == 0)
        let payloadData = try #require(self.output(from: result).data(using: .utf8))
        let payload = try JSONDecoder().decode(ScrollResult.self, from: payloadData)
        #expect(payload.totalTicks == 12) // 4 * 3 when smooth
    }

    @Test("Direction validation accepts common values", arguments: [
        "up", "down", "left", "right",
    ])
    func directionValidation(value: String) async throws {
        let context = await self.makeContext()
        let result = try await self.runScroll(arguments: ["--direction", value], context: context)
        #expect(result.exitStatus == 0)
    }

    // MARK: - Helpers

    private func runScroll(
        arguments: [String],
        context: TestServicesFactory.AutomationTestContext
    ) async throws -> CommandRunResult {
        try await InProcessCommandRunner.run(["scroll"] + arguments, services: context.services)
    }

    private func output(from result: CommandRunResult) -> String {
        result.stdout.isEmpty ? result.stderr : result.stdout
    }

    private func makeContext(
        configure: (@MainActor (StubAutomationService, StubSnapshotManager) -> Void)? = nil
    ) async -> TestServicesFactory.AutomationTestContext {
        await MainActor.run {
            let context = TestServicesFactory.makeAutomationTestContext()
            configure?(context.automation, context.snapshots)
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

@Suite("ScrollCommand Result Structures", .tags(.safe))
struct ScrollCommandResultStructTests {
    @Test("Scroll result structure maintains fields")
    func scrollResultStructure() {
        let result = ScrollResult(
            success: true,
            direction: "down",
            amount: 5,
            location: ["x": 500.0, "y": 300.0],
            totalTicks: 5,
            executionTime: 0.15
        )

        #expect(result.success == true)
        #expect(result.direction == "down")
        #expect(result.amount == 5)
        #expect(result.location["x"] == 500.0)
        #expect(result.location["y"] == 300.0)
        #expect(result.totalTicks == 5)
        #expect(result.executionTime == 0.15)
    }
}
