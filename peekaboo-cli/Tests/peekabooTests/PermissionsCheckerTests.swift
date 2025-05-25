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

    func testPermissionStateEncoding() throws {
        // Test that permission states can be properly encoded to JSON
        let serverStatus = ServerStatus(
            hasScreenRecordingPermission: true,
            hasAccessibilityPermission: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(serverStatus)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["has_screen_recording_permission"] as? Bool, true)
        XCTAssertEqual(json?["has_accessibility_permission"] as? Bool, false)
    }

    // MARK: - Error Handling Tests

    func testPermissionDeniedError() {
        // Test error creation for permission denied
        let error = CaptureError.capturePermissionDenied
        
        XCTAssertEqual(error.description, "Screen recording permission is required")
    }

    // MARK: - Performance Tests

    func testPermissionCheckPerformance() {
        // Test that permission checks are fast
        measure {
            _ = PermissionsChecker.checkScreenRecordingPermission()
            _ = PermissionsChecker.checkAccessibilityPermission()
        }
    }

    // MARK: - Mock Tests (for CI/CD)

    func testMockPermissionScenarios() {
        // Test various permission scenarios for error handling

        // Scenario 1: No permissions
        var status = ServerStatus(
            hasScreenRecordingPermission: false,
            hasAccessibilityPermission: false
        )
        XCTAssertFalse(status.hasScreenRecordingPermission)
        XCTAssertFalse(status.hasAccessibilityPermission)

        // Scenario 2: Only screen recording
        status = ServerStatus(
            hasScreenRecordingPermission: true,
            hasAccessibilityPermission: false
        )
        XCTAssertTrue(status.hasScreenRecordingPermission)
        XCTAssertFalse(status.hasAccessibilityPermission)

        // Scenario 3: Both permissions
        status = ServerStatus(
            hasScreenRecordingPermission: true,
            hasAccessibilityPermission: true
        )
        XCTAssertTrue(status.hasScreenRecordingPermission)
        XCTAssertTrue(status.hasAccessibilityPermission)
    }
}
