import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite(
    "ClickCommand Tests",
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct ClickCommandTests {
    @Test("Click command  requires argument or option")
    func requiresArgumentOrOption() async throws {
        var command = try ClickCommand.parse([])
        #expect(throws: (any Error).self) {
            try command.validate()
        }
    }

    @Test("Click command  parses coordinates correctly")
    func parsesCoordinates() async throws {
        let context = await self.makeContext()
        let result = try await InProcessCommandRunner.run(
            ["click", "--coords", "100,200", "--json"],
            services: context.services
        )

        #expect(result.exitStatus == 0)
        let calls = await self.automationState(context) { $0.clickCalls }
        let call = try #require(calls.first)
        if case let .coordinates(point) = call.target {
            #expect(point == CGPoint(x: 100, y: 200))
        } else {
            Issue.record("Expected coordinates click target")
        }
    }

    @Test("Click command  validates coordinate format")
    func validatesCoordinateFormat() async throws {
        var command = try ClickCommand.parse(["--coords", "invalid", "--json"])
        #expect(throws: (any Error).self) {
            try command.validate()
        }
    }

    private func makeContext() async -> TestServicesFactory.AutomationTestContext {
        await MainActor.run {
            TestServicesFactory.makeAutomationTestContext()
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
