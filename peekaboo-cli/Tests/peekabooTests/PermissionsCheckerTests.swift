import XCTest
@testable import peekaboo

final class PermissionsCheckerTests: XCTestCase {
    var permissionsChecker: PermissionsChecker!
    
    override func setUp() {
        super.setUp()
        permissionsChecker = PermissionsChecker()
    }
    
    override func tearDown() {
        permissionsChecker = nil
        super.tearDown()
    }
    
    // MARK: - hasScreenRecordingPermission Tests
    
    func testHasScreenRecordingPermission() {
        // Test screen recording permission check
        let hasPermission = permissionsChecker.hasScreenRecordingPermission()
        
        // This test will pass or fail based on actual system permissions
        // In CI/CD, this might need to be mocked
        XCTAssertNotNil(hasPermission)
        
        // If running in a test environment without permissions, we expect false
        // If running locally with permissions granted, we expect true
        print("Screen recording permission status: \(hasPermission)")
    }
    
    func testScreenRecordingPermissionConsistency() {
        // Test that multiple calls return consistent results
        let firstCheck = permissionsChecker.hasScreenRecordingPermission()
        let secondCheck = permissionsChecker.hasScreenRecordingPermission()
        
        XCTAssertEqual(firstCheck, secondCheck, "Permission check should be consistent")
    }
    
    // MARK: - hasAccessibilityPermission Tests
    
    func testHasAccessibilityPermission() {
        // Test accessibility permission check
        let hasPermission = permissionsChecker.hasAccessibilityPermission()
        
        // This will return the actual system state
        XCTAssertNotNil(hasPermission)
        
        print("Accessibility permission status: \(hasPermission)")
    }
    
    func testAccessibilityPermissionWithTrustedCheck() {
        // Test the AXIsProcessTrusted check
        let isTrusted = AXIsProcessTrusted()
        let hasPermission = permissionsChecker.hasAccessibilityPermission()
        
        // These should match
        XCTAssertEqual(isTrusted, hasPermission)
    }
    
    // MARK: - checkAllPermissions Tests
    
    func testCheckAllPermissions() {
        // Test combined permissions check
        let (screenRecording, accessibility) = permissionsChecker.checkAllPermissions()
        
        // Both should return boolean values
        XCTAssertNotNil(screenRecording)
        XCTAssertNotNil(accessibility)
        
        // Verify individual checks match combined check
        XCTAssertEqual(screenRecording, permissionsChecker.hasScreenRecordingPermission())
        XCTAssertEqual(accessibility, permissionsChecker.hasAccessibilityPermission())
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
        let screenError = CaptureError.permissionDeniedScreenRecording
        let accessError = CaptureError.permissionDeniedAccessibility
        
        XCTAssertEqual(screenError.description, "Screen recording permission is required")
        XCTAssertEqual(accessError.description, "Accessibility permission is required")
    }
    
    // MARK: - Performance Tests
    
    func testPermissionCheckPerformance() {
        // Test that permission checks are fast
        measure {
            _ = permissionsChecker.checkAllPermissions()
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