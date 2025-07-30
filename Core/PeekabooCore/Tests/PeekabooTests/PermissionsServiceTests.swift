import AppKit
import Testing
@testable import PeekabooCore

@Suite("PermissionsService Tests", .tags(.permissions, .unit))
struct PermissionsServiceTests {
    let permissionsService = PermissionsService()

    // MARK: - Screen Recording Permission Tests

    @Test("Screen recording permission check returns boolean", .tags(.fast))
    func checkScreenRecordingPermission() {
        // Test screen recording permission check
        let hasPermission = self.permissionsService.checkScreenRecordingPermission()

        // Just verify we got a valid boolean result (the API works)
        // The actual value depends on system permissions
        _ = hasPermission
    }

    @Test("Screen recording permission check is consistent", .tags(.fast))
    func screenRecordingPermissionConsistency() {
        // Test that multiple calls return consistent results
        let firstCheck = self.permissionsService.checkScreenRecordingPermission()
        let secondCheck = self.permissionsService.checkScreenRecordingPermission()

        #expect(firstCheck == secondCheck)
    }

    @Test("Screen recording permission check performance", arguments: 1...5)
    func screenRecordingPermissionPerformance(iteration: Int) {
        // Permission checks should be fast
        _ = self.permissionsService.checkScreenRecordingPermission()
        // Performance is measured by the test framework's execution time
    }

    // MARK: - Accessibility Permission Tests

    @Test("Accessibility permission check returns boolean", .tags(.fast))
    func checkAccessibilityPermission() {
        // Test accessibility permission check
        let hasPermission = self.permissionsService.checkAccessibilityPermission()

        // Just verify we got a valid boolean result (the API works)
        // The actual value depends on system permissions
        _ = hasPermission
    }

    @Test("Accessibility permission matches AXIsProcessTrusted", .tags(.fast))
    func accessibilityPermissionWithTrustedCheck() {
        // Compare our check with direct AX API
        // Use CFDictionary for options to avoid bridging issues
        let options = ["AXTrustedCheckOptionPrompt": false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let hasPermission = self.permissionsService.checkAccessibilityPermission()

        // These should match
        #expect(hasPermission == isTrusted)
    }

    // MARK: - Combined Permission Tests

    @Test("Both permissions return valid results", .tags(.fast))
    func bothPermissions() {
        // Test both permission checks
        let screenRecording = self.permissionsService.checkScreenRecordingPermission()
        let accessibility = self.permissionsService.checkAccessibilityPermission()

        // Both should return valid boolean values
        _ = screenRecording
        _ = accessibility
    }

    // MARK: - Require Permission Tests

    @Test("Require screen recording permission throws CaptureError when denied", .tags(.fast))
    func requireScreenRecordingPermission() {
        let hasPermission = self.permissionsService.checkScreenRecordingPermission()

        if hasPermission {
            // Should not throw when permission is granted
            #expect(throws: Never.self) {
                try permissionsService.requireScreenRecordingPermission()
            }
        } else {
            // Should throw specific CaptureError when permission is denied
            #expect(throws: CaptureError.self) {
                try permissionsService.requireScreenRecordingPermission()
            } catch: { error in
                guard case .screenRecordingPermissionDenied = error else {
                    Issue.record("Expected screenRecordingPermissionDenied but got \(error)")
                    return
                }
                // Verify error message is helpful
                #expect(error.localizedDescription.contains("Screen recording permission"))
            }
        }
    }

    @Test("Require accessibility permission throws CaptureError when denied", .tags(.fast))
    func requireAccessibilityPermission() {
        let hasPermission = self.permissionsService.checkAccessibilityPermission()

        if hasPermission {
            // Should not throw when permission is granted
            #expect(throws: Never.self) {
                try permissionsService.requireAccessibilityPermission()
            }
        } else {
            // Should throw specific CaptureError when permission is denied
            #expect(throws: CaptureError.self) {
                try permissionsService.requireAccessibilityPermission()
            } catch: { error in
                guard case .accessibilityPermissionDenied = error else {
                    Issue.record("Expected accessibilityPermissionDenied but got \(error)")
                    return
                }
                // Verify error message is helpful
                #expect(error.localizedDescription.contains("Accessibility permission"))
            }
        }
    }

    // MARK: - All Permissions Check

    @Test("Check all permissions returns status object", .tags(.fast))
    func checkAllPermissionsReturnsStatus() {
        let status = self.permissionsService.checkAllPermissions()

        // Verify the status object has the expected properties
        _ = status.screenRecording
        _ = status.accessibility

        // The values should match individual checks
        #expect(status.screenRecording == self.permissionsService.checkScreenRecordingPermission())
        #expect(status.accessibility == self.permissionsService.checkAccessibilityPermission())
    }
}
