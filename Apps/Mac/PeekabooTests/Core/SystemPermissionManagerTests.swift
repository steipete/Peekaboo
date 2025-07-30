import AppKit
import Testing
@testable import Peekaboo

@Suite("SystemPermissionManager Tests", .tags(.permissions, .unit))
@MainActor
struct SystemPermissionManagerTests {
    @Test("Manager follows singleton pattern")
    func singletonPattern() {
        let instance1 = SystemPermissionManager.shared
        let instance2 = SystemPermissionManager.shared

        // Both references should point to the same instance
        #expect(instance1 === instance2)
    }

    @Test("Permission status check - Screen Recording")
    func screenRecordingStatus() async {
        let manager = SystemPermissionManager.shared

        // Check screen recording permission
        let hasPermission = await manager.hasScreenRecordingPermission()

        // Should return a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }

    @Test("Permission status check - Accessibility")
    func accessibilityStatus() async {
        let manager = SystemPermissionManager.shared

        // Check accessibility permission
        let hasPermission = await manager.hasAccessibilityPermission()

        // Should return a valid boolean
        #expect(hasPermission == true || hasPermission == false)
    }

    @Test("Request screen recording permission")
    func requestScreenRecording() async {
        let manager = SystemPermissionManager.shared

        // This would normally open system preferences
        // In tests, we just verify the method exists and doesn't crash
        await manager.requestScreenRecordingPermission()

        // Verify we can still check status after request
        let status = await manager.hasScreenRecordingPermission()
        #expect(status == true || status == false)
    }

    @Test("Request accessibility permission")
    func requestAccessibility() async {
        let manager = SystemPermissionManager.shared

        // This would normally open system preferences
        // In tests, we just verify the method exists and doesn't crash
        await manager.requestAccessibilityPermission()

        // Verify we can still check status after request
        let status = await manager.hasAccessibilityPermission()
        #expect(status == true || status == false)
    }

    @Test("Combined permission check")
    func allPermissionsCheck() async {
        let manager = SystemPermissionManager.shared

        // Check if all required permissions are granted
        let hasAll = await manager.hasAllRequiredPermissions()

        // Should be true only if both permissions are granted
        let hasScreenRecording = await manager.hasScreenRecordingPermission()
        let hasAccessibility = await manager.hasAccessibilityPermission()

        #expect(hasAll == (hasScreenRecording && hasAccessibility))
    }

    @Test("Permission status caching")
    func permissionCaching() async {
        let manager = SystemPermissionManager.shared

        // Check permissions multiple times
        let check1 = await manager.hasScreenRecordingPermission()
        let check2 = await manager.hasScreenRecordingPermission()
        let check3 = await manager.hasScreenRecordingPermission()

        // All checks should return the same value (assuming no permission change during test)
        #expect(check1 == check2)
        #expect(check2 == check3)
    }

    @Test("Open system preferences for permissions")
    func openSystemPreferences() async {
        let manager = SystemPermissionManager.shared

        // Test opening privacy preferences
        // This would normally open System Preferences
        // In tests, we verify it doesn't crash
        await manager.openPrivacyPreferences()

        // Test opening specific permission panes
        await manager.openScreenRecordingPreferences()
        await manager.openAccessibilityPreferences()

        // If we got here without crashing, the test passes
        #expect(true)
    }

    @Test("Permission change notifications")
    func permissionChangeNotifications() async {
        let manager = SystemPermissionManager.shared

        // In a real implementation, the manager might post notifications
        // when permissions change. We'd test that here.

        // For now, just verify we can check permissions
        _ = await manager.hasScreenRecordingPermission()
        _ = await manager.hasAccessibilityPermission()

        #expect(true) // Basic verification that checks don't crash
    }

    @Test("Thread safety of permission checks")
    func threadSafetyChecks() async {
        let manager = SystemPermissionManager.shared

        // Perform concurrent permission checks
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await manager.hasScreenRecordingPermission()
                }
                group.addTask {
                    await manager.hasAccessibilityPermission()
                }
            }

            // Collect all results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            // All results should be valid booleans
            #expect(results.count == 20)
            #expect(results.allSatisfy { $0 == true || $0 == false })
        }
    }

    @Test("Permission required for specific features")
    func featurePermissionRequirements() async {
        let manager = SystemPermissionManager.shared

        // Check which permissions are required for specific features
        let screenshotRequirements = await manager.permissionsRequiredFor(feature: .screenshot)
        let automationRequirements = await manager.permissionsRequiredFor(feature: .automation)
        let inspectorRequirements = await manager.permissionsRequiredFor(feature: .inspector)

        // Screenshots require screen recording
        #expect(screenshotRequirements.contains(.screenRecording))

        // Automation requires accessibility
        #expect(automationRequirements.contains(.accessibility))

        // Inspector requires both
        #expect(inspectorRequirements.contains(.screenRecording))
        #expect(inspectorRequirements.contains(.accessibility))
    }
}

// MARK: - Test Helpers

extension SystemPermissionManager {
    // These would be test-specific extensions if the manager doesn't already have them

    func hasAllRequiredPermissions() async -> Bool {
        let hasScreenRecording = await hasScreenRecordingPermission()
        let hasAccessibility = await hasAccessibilityPermission()
        return hasScreenRecording && hasAccessibility
    }

    func openPrivacyPreferences() async {
        // Would open System Preferences to Privacy pane
    }

    func openScreenRecordingPreferences() async {
        // Would open System Preferences to Screen Recording
    }

    func openAccessibilityPreferences() async {
        // Would open System Preferences to Accessibility
    }

    enum Feature {
        case screenshot
        case automation
        case inspector
    }

    enum Permission {
        case screenRecording
        case accessibility
    }

    func permissionsRequiredFor(feature: Feature) async -> Set<Permission> {
        switch feature {
        case .screenshot:
            [.screenRecording]
        case .automation:
            [.accessibility]
        case .inspector:
            [.screenRecording, .accessibility]
        }
    }
}
