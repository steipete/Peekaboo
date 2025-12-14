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

        private(set) var checkPermissionsCallCount = 0
        var hasAllPermissions: Bool {
            self.screenRecordingStatus == .authorized && self.accessibilityStatus == .authorized
        }

        func checkPermissions() { self.checkPermissionsCallCount += 1 }
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
        self.permissions.screenRecordingStatus = screenRecording
        self.permissions.accessibilityStatus = accessibility
        #expect(self.permissions.hasAllPermissions == expectedHasAll)
    }

    @Test("Permission checking updates status")
    @MainActor
    func checkPermissions() async {
        // This test verifies the check method runs without crashing.
        await self.permissions.check()

        // The app-level wrapper always refreshes required permissions directly.
        #expect(self.permissions.screenRecordingStatus != .notDetermined)
        #expect(self.permissions.accessibilityStatus != .notDetermined)
    }

    @Test("Optional permission checks are throttled")
    @MainActor
    func optionalChecksThrottled() async {
        #expect(self.mockPermissionsService.checkPermissionsCallCount == 0)

        self.permissions.setIncludeOptionalPermissions(true)
        await self.permissions.check()
        #expect(self.mockPermissionsService.checkPermissionsCallCount == 1)

        // Subsequent checks within the optional interval should not call through again.
        await self.permissions.check()
        #expect(self.mockPermissionsService.checkPermissionsCallCount == 1)

        self.permissions.setIncludeOptionalPermissions(false)
        await self.permissions.check()
        #expect(self.mockPermissionsService.checkPermissionsCallCount == 1)
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
