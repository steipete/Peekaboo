import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Permissions Command Tests", .serialized, .tags(.permissions))
struct PermissionCommandTests {
    @Test("permissions command emits JSON with stub statuses")
    func permissionsJSONOutput() async throws {
        let automation = StubAutomationService()
        automation.accessibilityPermissionGranted = false
        let screenCapture = StubScreenCaptureService(permissionGranted: false)

        let services = await MainActor.run {
            TestServicesFactory.makePeekabooServices(
                automation: automation,
                screenCapture: screenCapture
            )
        }

        let result = try await InProcessCommandRunner.run([
            "permissions",
            "--json-output"
        ], services: services)

        let output = result.combinedOutput
        guard let jsonStart = output.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            Issue.record("Permissions output did not contain JSON: \(output)")
            return
        }

        let jsonString = String(output[jsonStart...])
        let payload = try JSONDecoder().decode(
            CodableJSONResponse<[PermissionHelpers.PermissionInfo]>.self,
            from: Data(jsonString.utf8)
        )

        #expect(payload.success == true)
        #expect(payload.data.count == 2)
        if let screenRecording = payload.data.first(where: { $0.name == "Screen Recording" }) {
            #expect(screenRecording.isGranted == false)
            #expect(screenRecording.isRequired == true)
        } else {
            Issue.record("Missing screen recording entry")
        }

        if let accessibility = payload.data.first(where: { $0.name == "Accessibility" }) {
            #expect(accessibility.isGranted == false)
            #expect(accessibility.isRequired == false)
        } else {
            Issue.record("Missing accessibility entry")
        }
    }

    @Test("permissions command prints grant instructions when missing")
    func permissionsTextOutput() async throws {
        let automation = StubAutomationService()
        automation.accessibilityPermissionGranted = false
        let screenCapture = StubScreenCaptureService(permissionGranted: true)

        let services = await MainActor.run {
            TestServicesFactory.makePeekabooServices(
                automation: automation,
                screenCapture: screenCapture
            )
        }

        let result = try await InProcessCommandRunner.run([
            "permissions"
        ], services: services)

        let output = result.combinedOutput
        #expect(output.contains("Screen Recording (Required): Granted"))
        #expect(output.contains("Accessibility (Optional): Not Granted"))
    }
}
#endif
