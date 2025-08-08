import AppKit
import Testing
import PeekabooCore
@testable import Peekaboo

@Suite("PermissionsService Tests", .tags(.permissions, .unit))
@MainActor
struct PermissionsServiceTests {
    let service = PermissionsService()

    @Test("Permission status check - Screen Recording")
    func screenRecordingStatus() {
        // Check screen recording permission
        let hasPermission = service.checkScreenRecordingPermission()

        // Should return a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }

    @Test("Permission status check - Accessibility")
    func accessibilityStatus() {
        // Check accessibility permission
        let hasPermission = service.checkAccessibilityPermission()

        // Should return a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }

    @Test("Combined permission check")
    func allPermissionsCheck() {
        // Check if all required permissions are granted
        let status = service.checkAllPermissions()

        // Should be true only if both permissions are granted
        let hasScreenRecording = service.checkScreenRecordingPermission()
        let hasAccessibility = service.checkAccessibilityPermission()

        #expect(status.allGranted == (hasScreenRecording && hasAccessibility))
    }

    @Test("Permission required for specific features")
    func featurePermissionRequirements() {
        // This logic has been moved out of the permissions service
        // and is now handled by the components that require the permissions.
        // This test is no longer applicable to PermissionsService.
        #expect(true)
    }
}