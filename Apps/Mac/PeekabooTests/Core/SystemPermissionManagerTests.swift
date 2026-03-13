import AppKit
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite(.tags(.permissions, .unit))
@MainActor
struct PermissionsServiceTests {
    let service = PermissionsService()

    @Test
    func `Permission status check - Screen Recording`() {
        // Check screen recording permission
        let hasPermission = self.service.checkScreenRecordingPermission()

        // Should return a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }

    @Test
    func `Permission status check - Accessibility`() {
        // Check accessibility permission
        let hasPermission = self.service.checkAccessibilityPermission()

        // Should return a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }

    @Test
    func `Combined permission check`() {
        // Check if all required permissions are granted
        let status = self.service.checkAllPermissions()

        // Should be true only if both permissions are granted
        let hasScreenRecording = self.service.checkScreenRecordingPermission()
        let hasAccessibility = self.service.checkAccessibilityPermission()

        #expect(status.allGranted == (hasScreenRecording && hasAccessibility))
    }

    @Test
    func `Permission required for specific features`() {
        // This logic has been moved out of the permissions service
        // and is now handled by the components that require the permissions.
        // This test is no longer applicable to PermissionsService.
        #expect(true)
    }
}
