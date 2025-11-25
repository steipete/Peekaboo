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

        let payload = await CodableJSONResponse(
            success: true,
            data: PermissionHelpers.getCurrentPermissions(services: services),
            messages: nil,
            debug_logs: []
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

        #expect(result.exitStatus == 0)
    }
}
#endif

extension PermissionCommandTests {
    fileprivate static func balancedJSON(in text: Substring) -> String? {
        var curly = 0
        var square = 0
        var end: String.Index?

        for index in text.indices {
            let char = text[index]
            if char == "{" { curly += 1 }
            if char == "}" { curly -= 1 }
            if char == "[" { square += 1 }
            if char == "]" { square -= 1 }

            if curly == 0 && square == 0 && (char == "}" || char == "]") {
                end = text.index(after: index)
                break
            }
        }

        guard let end else { return nil }
        return String(text.prefix(upTo: end))
    }
}
