import Foundation
import Testing
@testable import Peekaboo

@Suite("Permissions Tests", .tags(.services, .unit))
@MainActor
struct PermissionsTests {
    let permissions: Permissions

    init() {
        self.permissions = Permissions()
    }

    @Test("Service initializes with unknown permissions")
    func initialState() {
        // Initial state should be unknown since we haven't checked yet
        #expect(self.permissions.screenRecordingStatus == .notDetermined)
        #expect(self.permissions.accessibilityStatus == .notDetermined)
    }

    @Test("Has all permissions when both are authorized")
    func testHasAllPermissions() {
        // This is a unit test, so we're testing the logic, not actual permissions
        // In a real scenario, these would be set by checkPermissions()

        // Simulate both permissions granted
        self.permissions.screenRecordingStatus = .authorized
        self.permissions.accessibilityStatus = .authorized
        #expect(self.permissions.hasAllPermissions == true)

        // Test various combinations
        self.permissions.screenRecordingStatus = .denied
        #expect(self.permissions.hasAllPermissions == false)

        self.permissions.screenRecordingStatus = .authorized
        self.permissions.accessibilityStatus = .denied
        #expect(self.permissions.hasAllPermissions == false)

        self.permissions.screenRecordingStatus = .notDetermined
        self.permissions.accessibilityStatus = .authorized
        #expect(self.permissions.hasAllPermissions == false)
    }

    @Test("Permission status combinations", arguments: [
        (PermissionStatus.authorized, PermissionStatus.authorized, true),
        (PermissionStatus.authorized, PermissionStatus.denied, false),
        (PermissionStatus.denied, PermissionStatus.authorized, false),
        (PermissionStatus.denied, PermissionStatus.denied, false),
        (PermissionStatus.notDetermined, PermissionStatus.authorized, false),
        (PermissionStatus.authorized, PermissionStatus.notDetermined, false),
        (PermissionStatus.notDetermined, PermissionStatus.notDetermined, false)
    ])
    func permissionCombinations(
        screenRecording: PermissionStatus,
        accessibility: PermissionStatus,
        expectedHasAll: Bool)
    {
        self.permissions.screenRecordingStatus = screenRecording
        self.permissions.accessibilityStatus = accessibility
        #expect(self.permissions.hasAllPermissions == expectedHasAll)
    }

    @Test("Permission checking updates status")
    @MainActor
    func checkPermissions() async {
        // This test verifies the checkPermissions method runs without crashing
        // Actual permission status depends on system state
        await self.permissions.check()

        // After checking, statuses should no longer be .notDetermined
        #expect(self.permissions.screenRecordingStatus != .notDetermined)
        #expect(self.permissions.accessibilityStatus != .notDetermined)
    }
}

@Suite("Permissions System Tests", .tags(.services, .integration, .permissions))
@MainActor
struct PermissionsSystemTests {
    @Test("Request permissions opens system preferences")
    @MainActor
    func requestPermissions() async throws {
        let permissions = Permissions()

        // This test is mainly to ensure the method doesn't crash
        // We can't actually test if System Preferences opens in unit tests
        permissions.requestScreenRecording()
        permissions.requestAccessibility()

        // Give a moment for any async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // If we get here without crashing, the test passes
        #expect(Bool(true))
    }
}
