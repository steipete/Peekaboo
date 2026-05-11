import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite(.tags(.safe), .serialized)
struct PasteCommandTests {
    @Test
    @MainActor
    func `Paste fails before mutating clipboard when explicit app target is missing`() async throws {
        let automation = StubAutomationService()
        let clipboard = StubClipboardService()
        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: []),
            clipboard: clipboard,
            automation: automation
        )

        let result = try await InProcessCommandRunner.run(
            [
                "paste",
                "--app", "NoSuchPeekabooApp",
                "--text", "smoke",
                "--json",
                "--no-remote",
            ],
            services: services
        )

        #expect(result.exitStatus == 1)
        #expect(result.stdout.contains("\"success\" : false"))
        #expect(result.stdout.contains("\"code\" : \"APP_NOT_FOUND\""))
        #expect(automation.hotkeyCalls.isEmpty)
        #expect(try clipboard.get(prefer: nil) == nil)
    }
}
