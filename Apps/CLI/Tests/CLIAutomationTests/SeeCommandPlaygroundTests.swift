import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "SeeCommand Playground Tests",
    .serialized,
    .tags(.automation)
)
struct SeeCommandPlaygroundTests {
    @Test("Hidden web-style fields are detected in Playground")
    func hiddenFieldsAreDetected() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }

        _ = try? await self.runPeekabooCommand([
            "app", "launch",
            "--name", "Playground",
            "--wait-until-ready",
        ])

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let output = try await self.runPeekabooCommand([
            "see",
            "--app", "Playground",
            "--json-output",
        ])

        let data = try #require(output.data(using: .utf8))
        let result = try JSONDecoder().decode(SeeResult.self, from: data)

        let identifiers = Set(result.ui_elements.compactMap { $0.identifier })
        #expect(identifiers.contains("hidden-email-field"))
        #expect(identifiers.contains("hidden-password-field"))

        let roles = Dictionary(grouping: result.ui_elements, by: { $0.identifier ?? "" })
        #expect(roles["hidden-email-field"]?.first?.role == "textField")
        #expect(roles["hidden-password-field"]?.first?.role == "textField")

        #expect(identifiers.contains("permission-allow-button"))
        #expect(identifiers.contains("permission-deny-button"))
        #expect(roles["permission-allow-button"]?.first?.label == "Allow")
        #expect(roles["permission-deny-button"]?.first?.label == "Don't Allow")
    }

    private func runPeekabooCommand(
        _ arguments: [String],
        allowedExitStatuses: Set<Int32> = [0]
    ) async throws -> String {
        do {
            let result = try await InProcessCommandRunner.runShared(
                arguments,
                allowedExitCodes: allowedExitStatuses
            )
            return result.combinedOutput
        } catch let error as CommandExecutionError {
            throw TestError.commandFailed(status: error.status, output: error.stdout + error.stderr)
        }
    }

    enum TestError: Error, LocalizedError {
        case commandFailed(status: Int32, output: String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(status, output):
                "Exit status: \(status)\n\(output)"
            }
        }
    }
}
#endif
