import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "PressCommand Tests",
    .serialized,
    .tags(.safe),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct PressCommandTests {
    @Test("press --help documents command")
    func pressHelp() async throws {
        let context = await self.makeContext()
        let result = try await self.runPress(arguments: ["--help"], context: context)

        #expect(result.exitStatus == 0)
        #expect(self.output(from: result).contains("Press individual keys or key sequences"))
    }

    @Test("Press command forwards keys to automation service")
    func forwardsKeys() async throws {
        let context = await self.makeContext()
        let result = try await self.runPress(arguments: ["return", "--json"], context: context)

        #expect(result.exitStatus == 0)
        let calls = await self.automationState(context) { $0.typeActionsCalls }
        let call = try #require(calls.first)
        #expect(call.actions.count == 1)

        let payloadData = try #require(self.output(from: result).data(using: .utf8))
        let payload = try JSONDecoder().decode(CodableJSONResponse<PressResult>.self, from: payloadData)
        #expect(payload.success)
        #expect(payload.data.success)
        #expect(payload.data.keys == ["return"])
        #expect(payload.data.totalPresses == 1)
    }

    @Test("Repeat count multiplies key actions")
    func repeatCount() async throws {
        let context = await self.makeContext()
        let result = try await self.runPress(arguments: ["tab", "--count", "3"], context: context)

        #expect(result.exitStatus == 0)
        let calls = await self.automationState(context) { $0.typeActionsCalls }
        let call = try #require(calls.first)
        #expect(call.actions.count == 3)
        #expect(call.cadence == .fixed(milliseconds: 100))
    }

    @Test("Press command supports multiple keys in sequence")
    func multipleKeysSequence() async throws {
        let context = await self.makeContext()
        let result = try await self.runPress(arguments: ["up", "down", "left", "right"], context: context)

        #expect(result.exitStatus == 0)
        let calls = await self.automationState(context) { $0.typeActionsCalls }
        let call = try #require(calls.first)
        #expect(call.actions.count == 4)
        #expect(call.actions.allSatisfy {
            if case .key = $0 { true } else { false }
        })
    }

    @Test("Snapshot argument is forwarded")
    func forwardsSnapshot() async throws {
        let context = await self.makeContext()
        let result = try await self.runPress(arguments: ["escape", "--snapshot", "snapshot-42"], context: context)

        #expect(result.exitStatus == 0)
        let calls = await self.automationState(context) { $0.typeActionsCalls }
        let call = try #require(calls.first)
        #expect(call.snapshotId == "snapshot-42")
    }

    @Test("Invalid key results in failure")
    func invalidKey() async throws {
        let context = await self.makeContext()
        let result = try await self.runPress(arguments: ["notakey"], context: context)

        #expect(result.exitStatus != 0)
        let calls = await self.automationState(context) { $0.typeActionsCalls }
        #expect(calls.isEmpty)
    }

    // MARK: - Helpers

    private func runPress(
        arguments: [String],
        context: TestServicesFactory.AutomationTestContext
    ) async throws -> CommandRunResult {
        try await InProcessCommandRunner.run(["press"] + arguments, services: context.services)
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
