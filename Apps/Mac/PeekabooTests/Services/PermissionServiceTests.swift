import Foundation
import Testing
@testable import Peekaboo
@testable import PeekabooCore

@Suite("Permissions Tests", .tags(.services, .unit))
@MainActor
struct PermissionsTests {
    class MockObservablePermissionsService: ObservablePermissionsServiceProtocol {
        var screenRecordingStatus: ObservablePermissionsService.PermissionState = .notDetermined
        var accessibilityStatus: ObservablePermissionsService.PermissionState = .notDetermined
        var appleScriptStatus: ObservablePermissionsService.PermissionState = .notDetermined
        var hasAllPermissions: Bool {
            self.screenRecordingStatus == .authorized && self.accessibilityStatus == .authorized
        }

        func checkPermissions() {}
        func requestScreenRecording() throws {}
        func requestAccessibility() throws {}
        func requestAppleScript() throws {}
        func startMonitoring(interval: TimeInterval) {}
        func stopMonitoring() {}
    }

    let permissions: Permissions
    let mockPermissionsService: MockObservablePermissionsService

    init() {
        let mockService = MockObservablePermissionsService()
        self.mockPermissionsService = mockService
        self.permissions = Permissions(permissionsService: mockService)
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
        self.mockPermissionsService.screenRecordingStatus = .authorized
        self.mockPermissionsService.accessibilityStatus = .authorized
        #expect(self.permissions.hasAllPermissions == true)

        // Test various combinations
        self.mockPermissionsService.screenRecordingStatus = .denied
        #expect(self.permissions.hasAllPermissions == false)

        self.mockPermissionsService.screenRecordingStatus = .authorized
        self.mockPermissionsService.accessibilityStatus = .denied
        #expect(self.permissions.hasAllPermissions == false)

        self.mockPermissionsService.screenRecordingStatus = .notDetermined
        self.mockPermissionsService.accessibilityStatus = .authorized
        #expect(self.permissions.hasAllPermissions == false)
    }

    @Test("Permission status combinations", arguments: [
        (
            ObservablePermissionsService.PermissionState.authorized,
            ObservablePermissionsService.PermissionState.authorized,
            true),
        (
            ObservablePermissionsService.PermissionState.authorized,
            ObservablePermissionsService.PermissionState.denied,
            false),
        (
            ObservablePermissionsService.PermissionState.denied,
            ObservablePermissionsService.PermissionState.authorized,
            false),
        (
            ObservablePermissionsService.PermissionState.denied,
            ObservablePermissionsService.PermissionState.denied,
            false),
        (
            ObservablePermissionsService.PermissionState.notDetermined,
            ObservablePermissionsService.PermissionState.authorized,
            false),
        (
            ObservablePermissionsService.PermissionState.authorized,
            ObservablePermissionsService.PermissionState.notDetermined,
            false),
        (
            ObservablePermissionsService.PermissionState.notDetermined,
            ObservablePermissionsService.PermissionState.notDetermined,
            false)
    ])
    func permissionCombinations(
        screenRecording: ObservablePermissionsService.PermissionState,
        accessibility: ObservablePermissionsService.PermissionState,
        expectedHasAll: Bool)
    {
        self.mockPermissionsService.screenRecordingStatus = screenRecording
        self.mockPermissionsService.accessibilityStatus = accessibility
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
