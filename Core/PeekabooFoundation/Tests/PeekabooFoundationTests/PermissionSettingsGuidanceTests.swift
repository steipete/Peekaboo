import Foundation
import Testing
@testable import PeekabooFoundation

struct PermissionSettingsGuidanceTests {
    @Test(arguments: [
        (14, "Screen Recording"),
        (15, "Screen & System Audio Recording"),
        (26, "Screen & System Audio Recording"),
        (27, "Screen & System Audio Recording"),
    ])
    func `screen recording uses the OS row name`(majorVersion: Int, row: String) {
        let version = OperatingSystemVersion(majorVersion: majorVersion, minorVersion: 0, patchVersion: 0)

        #expect(PermissionSettingsGuidance.path(for: .screenRecording, on: version) ==
            "System Settings > Privacy & Security > \(row)")
    }

    @Test(arguments: [
        (14, "Accessibility"),
        (15, "Accessibility"),
        (26, "Accessibility"),
        (27, "Device Control and Data Access"),
    ])
    func `accessibility and event synthesizing share the OS Settings list`(majorVersion: Int, row: String) {
        let version = OperatingSystemVersion(majorVersion: majorVersion, minorVersion: 0, patchVersion: 0)
        let expected = "System Settings > Privacy & Security > \(row)"

        #expect(PermissionSettingsGuidance.path(for: .accessibility, on: version) == expected)
        #expect(PermissionSettingsGuidance.path(for: .eventSynthesizing, on: version) == expected)
    }

    @Test
    func `default version follows the current OS`() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        for permission in [PermissionSettingsGuidance.Permission.screenRecording, .accessibility, .eventSynthesizing] {
            #expect(PermissionSettingsGuidance.path(for: permission) ==
                PermissionSettingsGuidance.path(for: permission, on: version))
        }
    }

    @Test(arguments: [
        (PeekabooError.permissionDeniedScreenRecording, PermissionSettingsGuidance.Permission.screenRecording),
        (.permissionDeniedAccessibility, .accessibility),
        (.permissionDeniedEventSynthesizing, .eventSynthesizing),
    ])
    func `permission recovery uses current Settings guidance`(
        error: PeekabooError,
        permission: PermissionSettingsGuidance.Permission)
    {
        let path = PermissionSettingsGuidance.path(for: permission)

        #expect(error.suggestedAction?.contains(path) == true)
        #expect(error.recoverySuggestion?.contains(path) == true)
    }

    @Test(arguments: [
        (CaptureError.screenRecordingPermissionDenied, PermissionSettingsGuidance.Permission.screenRecording),
        (.permissionDeniedScreenRecording, .screenRecording),
        (.accessibilityPermissionDenied, .accessibility),
    ])
    func `capture errors use current Settings guidance`(
        error: CaptureError,
        permission: PermissionSettingsGuidance.Permission)
    {
        #expect(error.errorDescription?.contains(PermissionSettingsGuidance.path(for: permission)) == true)
    }
}
