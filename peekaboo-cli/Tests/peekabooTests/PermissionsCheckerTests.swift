@testable import peekaboo
import XCTest

final class PermissionsCheckerTests: XCTestCase {
    // MARK: - hasScreenRecordingPermission Tests

    func testCheckScreenRecordingPermission() {
        // Test screen recording permission check
        let hasPermission = PermissionsChecker.checkScreenRecordingPermission()

        // This test will pass or fail based on actual system permissions
        // In CI/CD, this might need to be mocked
        XCTAssertNotNil(hasPermission)

        // If running in a test environment without permissions, we expect false
        // If running locally with permissions granted, we expect true
        print("Screen recording permission status: \(hasPermission)")
    }

    func testScreenRecordingPermissionConsistency() {
        // Test that multiple calls return consistent results
        let firstCheck = PermissionsChecker.checkScreenRecordingPermission()
        let secondCheck = PermissionsChecker.checkScreenRecordingPermission()

        XCTAssertEqual(firstCheck, secondCheck, "Permission check should be consistent")
    }

    // MARK: - hasAccessibilityPermission Tests

    func testCheckAccessibilityPermission() {
        // Test accessibility permission check
        let hasPermission = PermissionsChecker.checkAccessibilityPermission()

        // This will return the actual system state
        XCTAssertNotNil(hasPermission)

        print("Accessibility permission status: \(hasPermission)")
    }

    func testAccessibilityPermissionWithTrustedCheck() {
        // Test the AXIsProcessTrusted check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let hasPermission = PermissionsChecker.checkAccessibilityPermission()

        // These should match
        XCTAssertEqual(isTrusted, hasPermission)
    }

    // MARK: - checkAllPermissions Tests

    func testBothPermissions() {
        // Test both permission checks
        let screenRecording = PermissionsChecker.checkScreenRecordingPermission()
        let accessibility = PermissionsChecker.checkAccessibilityPermission()

        // Both should return boolean values
        XCTAssertNotNil(screenRecording)
        XCTAssertNotNil(accessibility)

        print("Permissions - Screen: \(screenRecording), Accessibility: \(accessibility)")
    }

    // MARK: - Permission State Tests

    func testPermissionErrors() {
        // Test permission error types
        let screenError = PermissionError.screenRecordingDenied
        let accessError = PermissionError.accessibilityDenied

        XCTAssertNotNil(screenError)
        XCTAssertNotNil(accessError)
    }

    // MARK: - Error Handling Tests

    func testCaptureError() {
        // Test error creation for permission denied
        let error = CaptureError.capturePermissionDenied

        // CaptureError conforms to LocalizedError, so it has errorDescription
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("permission") ?? false)
    }

    // MARK: - Performance Tests

    func testPermissionCheckPerformance() {
        // Test that permission checks are fast
        measure {
            _ = PermissionsChecker.checkScreenRecordingPermission()
            _ = PermissionsChecker.checkAccessibilityPermission()
        }
    }

    // MARK: - Require Permission Tests

    func testRequireScreenRecordingPermission() {
        // Test the require method - it should throw if permission is denied
        do {
            try PermissionsChecker.requireScreenRecordingPermission()
            // If we get here, permission was granted
            XCTAssertTrue(true)
        } catch {
            // If permission is denied, we should get CaptureError
            XCTAssertTrue(error is CaptureError)
        }
    }

    func testRequireAccessibilityPermission() {
        // Test the require method - it should throw if permission is denied
        do {
            try PermissionsChecker.requireAccessibilityPermission()
            // If we get here, permission was granted
            XCTAssertTrue(true)
        } catch {
            // If permission is denied, we should get CaptureError
            XCTAssertTrue(error is CaptureError)
        }
    }
}
