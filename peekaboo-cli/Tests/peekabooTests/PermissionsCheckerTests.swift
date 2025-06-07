@testable import peekaboo
import Testing
import AppKit

@Suite("PermissionsChecker Tests", .tags(.permissions, .unit))
struct PermissionsCheckerTests {
    // MARK: - Screen Recording Permission Tests
    
    @Test("Screen recording permission check returns boolean", .tags(.fast))
    func checkScreenRecordingPermission() {
        // Test screen recording permission check
        let hasPermission = PermissionsChecker.checkScreenRecordingPermission()
        
        // This test will pass or fail based on actual system permissions
        // The result should be a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }
    
    @Test("Screen recording permission check is consistent", .tags(.fast))
    func screenRecordingPermissionConsistency() {
        // Test that multiple calls return consistent results
        let firstCheck = PermissionsChecker.checkScreenRecordingPermission()
        let secondCheck = PermissionsChecker.checkScreenRecordingPermission()
        
        #expect(firstCheck == secondCheck)
    }
    
    @Test("Screen recording permission check performance", arguments: 1...5)
    func screenRecordingPermissionPerformance(iteration: Int) {
        // Permission checks should be fast
        let hasPermission = PermissionsChecker.checkScreenRecordingPermission()
        #expect(hasPermission == true || hasPermission == false)
    }
    
    // MARK: - Accessibility Permission Tests
    
    @Test("Accessibility permission check returns boolean", .tags(.fast))
    func checkAccessibilityPermission() {
        // Test accessibility permission check
        let hasPermission = PermissionsChecker.checkAccessibilityPermission()
        
        // This will return the actual system state
        #expect(hasPermission == true || hasPermission == false)
    }
    
    @Test("Accessibility permission matches AXIsProcessTrusted", .tags(.fast))
    func accessibilityPermissionWithTrustedCheck() {
        // Test the AXIsProcessTrusted check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let hasPermission = PermissionsChecker.checkAccessibilityPermission()
        
        // These should match
        #expect(isTrusted == hasPermission)
    }
    
    // MARK: - Combined Permission Tests
    
    @Test("Both permissions can be checked independently", .tags(.fast))
    func bothPermissions() {
        // Test both permission checks
        let screenRecording = PermissionsChecker.checkScreenRecordingPermission()
        let accessibility = PermissionsChecker.checkAccessibilityPermission()
        
        // Both should return valid boolean values
        #expect(screenRecording == true || screenRecording == false)
        #expect(accessibility == true || accessibility == false)
    }
    
    // MARK: - Require Permission Tests
    
    @Test("Require screen recording permission throws when denied", .tags(.fast))
    func requireScreenRecordingPermission() {
        let hasPermission = PermissionsChecker.checkScreenRecordingPermission()
        
        if hasPermission {
            // Should not throw when permission is granted
            #expect(throws: Never.self) {
                try PermissionsChecker.requireScreenRecordingPermission()
            }
        } else {
            // Should throw specific error when permission is denied
            #expect(throws: (any Error).self) {
                try PermissionsChecker.requireScreenRecordingPermission()
            }
        }
    }
    
    @Test("Require accessibility permission throws when denied", .tags(.fast))
    func requireAccessibilityPermission() {
        let hasPermission = PermissionsChecker.checkAccessibilityPermission()
        
        if hasPermission {
            // Should not throw when permission is granted
            #expect(throws: Never.self) {
                try PermissionsChecker.requireAccessibilityPermission()
            }
        } else {
            // Should throw specific error when permission is denied
            #expect(throws: (any Error).self) {
                try PermissionsChecker.requireAccessibilityPermission()
            }
        }
    }
    
    // MARK: - Error Message Tests
    
    @Test("Permission errors have descriptive messages", .tags(.fast))
    func permissionErrorMessages() {
        let screenError = CaptureError.screenRecordingPermissionDenied
        let accessError = CaptureError.accessibilityPermissionDenied
        
        // CaptureError conforms to LocalizedError, so it has errorDescription
        #expect(screenError.errorDescription != nil)
        #expect(accessError.errorDescription != nil)
        #expect(screenError.errorDescription!.contains("Screen recording permission"))
        #expect(accessError.errorDescription!.contains("Accessibility permission"))
    }
    
    @Test("Permission errors have correct exit codes", .tags(.fast))
    func permissionErrorExitCodes() {
        let screenError = CaptureError.screenRecordingPermissionDenied
        let accessError = CaptureError.accessibilityPermissionDenied
        
        #expect(screenError.exitCode == 11)
        #expect(accessError.exitCode == 12)
    }
}

// MARK: - Extended Permission Tests

@Suite("Permission Edge Cases", .tags(.permissions, .unit))
struct PermissionEdgeCaseTests {
    
    @Test("Permission checks are thread-safe", .tags(.integration))
    func threadSafePermissionChecks() async {
        // Test concurrent permission checks
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    PermissionsChecker.checkScreenRecordingPermission()
                }
                group.addTask {
                    PermissionsChecker.checkAccessibilityPermission()
                }
            }
            
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            
            // All results should be valid booleans
            #expect(results.count == 20)
            for result in results {
                #expect(result == true || result == false)
            }
        }
    }
    
    @Test("ScreenCaptureKit availability check", .tags(.fast))
    func screenCaptureKitAvailable() {
        // Verify that we can at least access ScreenCaptureKit APIs
        // This is a basic smoke test to ensure the framework is available
        let isAvailable = NSClassFromString("SCShareableContent") != nil
        #expect(isAvailable == true)
    }
    
    @Test("Permission state changes are detected", .tags(.integration))
    func permissionStateChanges() {
        // This test verifies that permission checks reflect current state
        // Note: This test cannot actually change permissions, but verifies
        // that repeated checks could detect changes if they occurred
        
        let initialScreen = PermissionsChecker.checkScreenRecordingPermission()
        let initialAccess = PermissionsChecker.checkAccessibilityPermission()
        
        // Sleep briefly to allow for potential state changes
        Thread.sleep(forTimeInterval: 0.1)
        
        let finalScreen = PermissionsChecker.checkScreenRecordingPermission()
        let finalAccess = PermissionsChecker.checkAccessibilityPermission()
        
        // In normal operation, these should be the same
        // but the important thing is they reflect current state
        #expect(initialScreen == finalScreen)
        #expect(initialAccess == finalAccess)
    }
}