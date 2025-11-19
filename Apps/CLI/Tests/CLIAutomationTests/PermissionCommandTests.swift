import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Permissions Command Tests", .tags(.permissions))
struct PermissionCommandTests {
    @Test("permissions command emits JSON with stub statuses")
    func permissionsJSONOutput() async throws {
        let automation = StubAutomationService()
        automation.accessibilityPermissionGranted = false
        let screenCapture = StubScreenCaptureService(permissionGranted: false)

        let services = await MainActor.run {
            TestServicesFactory.makePeekabooServices(
                automation: automation,
                screenCapture: screenCapture)
        }

        let result = try await InProcessCommandRunner.run([
            "permissions",
            "--json-output"
        ], services: services)

        let data = Data(result.stdout.utf8)
        let permissions = try JSONDecoder().decode(
            [PermissionHelpers.PermissionInfo].self,
            from: data)

        #expect(permissions.count == 2)
        if let screenRecording = permissions.first(where: { $0.name == "Screen Recording" }) {
            #expect(screenRecording.isGranted == false)
            #expect(screenRecording.isRequired == true)
        } else {
            Issue.record("Missing screen recording entry")
        }

        if let accessibility = permissions.first(where: { $0.name == "Accessibility" }) {
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
                screenCapture: screenCapture)
        }

        let result = try await InProcessCommandRunner.run([
            "permissions"
        ], services: services)

        let output = result.combinedOutput
        #expect(output.contains("Screen Recording"))
        #expect(output.contains("Accessibility"))
        #expect(output.contains("System Settings > Privacy & Security > Accessibility"))
    }
}
#endif
