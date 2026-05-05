import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@MainActor
struct HotkeyCommandBackgroundSafeTests {
    @Test
    func `background flag is available on hotkey command`() throws {
        let command = try HotkeyCommand.parse([
            "cmd,l",
            "--app", "Safari",
            "--focus-background",
        ])

        #expect(command.resolvedKeys == "cmd,l")
        #expect(command.target.app == "Safari")
        #expect(command.focusBackground)
        #expect(command.focusOptions.focusBackground)
        #expect(command.focusOptions.autoFocus == true)
    }

    @Test
    func `background flag is not accepted by press command`() throws {
        #expect(throws: (any Error).self) {
            _ = try PressCommand.parse(["escape", "--focus-background"])
        }
    }

    @Test
    func `permission status response includes event synthesizing JSON fields`() async throws {
        let services = PeekabooServices()

        let response = await PermissionHelpers.getCurrentPermissionsWithSource(
            services: services,
            allowRemote: false
        )

        #expect(response.source == "local")
        #expect(response.permissions.count == 3)
        let eventSynthesizing = try #require(
            response.permissions.first { $0.name == "Event Synthesizing" }
        )
        #expect(eventSynthesizing.isRequired == false)

        let payload = CodableJSONResponse(
            success: true,
            data: response,
            messages: nil,
            debug_logs: []
        )
        let data = try JSONEncoder().encode(payload)
        let fields = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payloadData = try #require(fields?["data"] as? [String: Any])
        let permissions = try #require(payloadData["permissions"] as? [[String: Any]])
        let eventPayload = try #require(permissions.first { $0["name"] as? String == "Event Synthesizing" })

        #expect(eventPayload["isRequired"] as? Bool == false)
        #expect(eventPayload.keys.contains("isGranted"))
        #expect(eventPayload.keys.contains("grantInstructions"))
    }
}
