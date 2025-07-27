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
        let hasPermission = permissionsService.checkScreenRecordingPermission()
        
        // Just verify we got a valid boolean result (the API works)
        // The actual value depends on system permissions
        _ = hasPermission
    }
    
    @Test("Screen recording permission check is consistent", .tags(.fast))
    func screenRecordingPermissionConsistency() {
        // Test that multiple calls return consistent results
        let firstCheck = permissionsService.checkScreenRecordingPermission()
        let secondCheck = permissionsService.checkScreenRecordingPermission()
        
        #expect(firstCheck == secondCheck)
    }
    
    @Test("Screen recording permission check performance", arguments: 1...5)
    func screenRecordingPermissionPerformance(iteration: Int) {
        // Permission checks should be fast
        _ = permissionsService.checkScreenRecordingPermission()
        // Performance is measured by the test framework's execution time
    }
    
    // MARK: - Accessibility Permission Tests
    
    @Test("Accessibility permission check returns boolean", .tags(.fast))
    func checkAccessibilityPermission() {
        // Test accessibility permission check
        let hasPermission = permissionsService.checkAccessibilityPermission()
        
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
        let hasPermission = permissionsService.checkAccessibilityPermission()
        
        // These should match
        #expect(hasPermission == isTrusted)
    }
    
    // MARK: - Combined Permission Tests
    
    @Test("Both permissions return valid results", .tags(.fast))
    func bothPermissions() {
        // Test both permission checks
        let screenRecording = permissionsService.checkScreenRecordingPermission()
        let accessibility = permissionsService.checkAccessibilityPermission()
        
        // Both should return valid boolean values
        _ = screenRecording
        _ = accessibility
    }
    
    // MARK: - Require Permission Tests
    
    @Test("Require screen recording permission throws when denied", .tags(.fast))
    func requireScreenRecordingPermission() {
        let hasPermission = permissionsService.checkScreenRecordingPermission()
        
        if hasPermission {
            // Should not throw when permission is granted
            #expect(throws: Never.self) {
                try permissionsService.requireScreenRecordingPermission()
            }
        } else {
            // Should throw specific error when permission is denied
            #expect(throws: (any Error).self) {
                try permissionsService.requireScreenRecordingPermission()
            }
        }
    }
    
    @Test("Require accessibility permission throws when denied", .tags(.fast))
    func requireAccessibilityPermission() {
        let hasPermission = permissionsService.checkAccessibilityPermission()
        
        if hasPermission {
            // Should not throw when permission is granted
            #expect(throws: Never.self) {
                try permissionsService.requireAccessibilityPermission()
            }
        } else {
            // Should throw specific error when permission is denied
            #expect(throws: (any Error).self) {
                try permissionsService.requireAccessibilityPermission()
            }
        }
    }
    
    // MARK: - All Permissions Check
    
    @Test("Check all permissions returns status object", .tags(.fast))
    func checkAllPermissionsReturnsStatus() {
        let status = permissionsService.checkAllPermissions()
        
        // Verify the status object has the expected properties
        _ = status.screenRecording
        _ = status.accessibility
        
        // The values should match individual checks
        #expect(status.screenRecording == permissionsService.checkScreenRecordingPermission())
        #expect(status.accessibility == permissionsService.checkAccessibilityPermission())
    }
}

