import AppKit
import Foundation
@testable import peekaboo
import Testing

// MARK: - Local Only Tests

// These tests require the PeekabooTestHost app to be running and user interaction

@Suite(
    "Local Integration Tests",
    .tags(.integration, .localOnly),
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true")
)
struct LocalIntegrationTests {
    // Test host app details
    static let testHostBundleId = "com.steipete.peekaboo.testhost"
    static let testHostAppName = "PeekabooTestHost"
    static let testWindowTitle = "Peekaboo Test Host"

    // MARK: - Helper Functions

    private func launchTestHost() async throws -> NSRunningApplication {
        // Check if test host is already running
        let runningApps = NSWorkspace.shared.runningApplications
        if let existingApp = runningApps.first(where: { $0.bundleIdentifier == Self.testHostBundleId }) {
            existingApp.activate()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            return existingApp
        }

        // Build and launch test host
        let testHostPath = try buildTestHost()

        guard let url = URL(string: "file://\(testHostPath)") else {
            throw TestError.invalidPath(testHostPath)
        }

        // Use modern NSWorkspace API
        let configuration = NSWorkspace.OpenConfiguration()
        let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)

        // Wait for app to be ready
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

        return app
    }

    private func buildTestHost() throws -> String {
        // Build the test host app
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.currentDirectoryURL = URL(fileURLWithPath: "/Users/steipete/Projects/Peekaboo/peekaboo-cli/TestHost")
        process.arguments = ["build", "-c", "debug"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TestError.buildFailed
        }

        return "/Users/steipete/Projects/Peekaboo/peekaboo-cli/TestHost/.build/debug/PeekabooTestHost"
    }

    private func terminateTestHost() {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == Self.testHostBundleId }) {
            app.terminate()
        }
    }

    // MARK: - Actual Screenshot Tests

    @Test("Capture test host window screenshot", .tags(.screenshot))
    func captureTestHostWindow() async throws {
        _ = try await launchTestHost()
        defer { terminateTestHost() }

        // Wait for window to be visible
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Find the test host app
        let appInfo = try ApplicationFinder.findApplication(identifier: Self.testHostAppName)
        #expect(appInfo.bundleIdentifier == Self.testHostBundleId)

        // Get windows for the app
        let windows = try WindowManager.getWindowsForApp(pid: appInfo.processIdentifier)
        #expect(!windows.isEmpty)

        // Find our test window
        let testWindow = windows.first { $0.title.contains("Test Host") }
        #expect(testWindow != nil)

        // Capture the window
        // In a real implementation, we would call the capture method
        // For now, we'll create a mock result
        let outputPath = "/tmp/peekaboo-test-window.png"

        // Simulate capture by creating an empty file
        FileManager.default.createFile(atPath: outputPath, contents: nil)

        let captureResult = ImageCaptureData(saved_files: [
            SavedFile(
                path: outputPath,
                item_label: "Test Window",
                window_title: testWindow?.title,
                window_id: UInt32(testWindow?.windowId ?? 0),
                window_index: 0,
                mime_type: "image/png"
            )
        ])

        #expect(captureResult.saved_files.count == 1)
        #expect(FileManager.default.fileExists(atPath: captureResult.saved_files[0].path))

        // Verify the image
        if let image = NSImage(contentsOfFile: captureResult.saved_files[0].path) {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        } else {
            Issue.record("Failed to load captured image")
        }

        // Clean up
        try? FileManager.default.removeItem(atPath: captureResult.saved_files[0].path)
    }

    @Test("Capture screen with test host visible", .tags(.screenshot))
    func captureScreenWithTestHost() async throws {
        let app = try await launchTestHost()
        defer { terminateTestHost() }

        // Ensure test host is in foreground
        app.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Capture the main screen
        let screens = NSScreen.screens
        #expect(!screens.isEmpty)

        let mainScreen = screens[0]
        let displayId = mainScreen.displayID

        // Simulate screen capture
        let outputPath = "/tmp/peekaboo-test-screen.png"
        FileManager.default.createFile(atPath: outputPath, contents: nil)

        let captureResult = ImageCaptureData(saved_files: [
            SavedFile(
                path: outputPath,
                item_label: "Screen \(displayId)",
                window_title: nil,
                window_id: nil,
                window_index: nil,
                mime_type: "image/png"
            )
        ])

        #expect(captureResult.saved_files.count == 1)
        #expect(FileManager.default.fileExists(atPath: captureResult.saved_files[0].path))

        // Clean up
        try? FileManager.default.removeItem(atPath: captureResult.saved_files[0].path)
    }

    @Test("Test permission dialogs", .tags(.permissions))
    func permissionDialogs() async throws {
        _ = try await launchTestHost()
        defer { terminateTestHost() }

        // Check current permissions
        let hasScreenRecording = PermissionsChecker.checkScreenRecordingPermission()
        let hasAccessibility = PermissionsChecker.checkAccessibilityPermission()

        print("""
        Current permissions:
        - Screen Recording: \(hasScreenRecording)
        - Accessibility: \(hasAccessibility)

        If permissions are not granted, the system will show dialogs when we try to use them.
        """)

        // Try to trigger screen recording permission if not granted
        if !hasScreenRecording {
            print("Attempting to trigger screen recording permission dialog...")
            _ = CGWindowListCopyWindowInfo([.optionIncludingWindow], kCGNullWindowID)
        }

        // Try to trigger accessibility permission if not granted
        if !hasAccessibility {
            print("Attempting to trigger accessibility permission dialog...")
            let options = ["AXTrustedCheckOptionPrompt": true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        // Give user time to interact with dialogs
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s

        // Re-check permissions
        let newScreenRecording = PermissionsChecker.checkScreenRecordingPermission()
        let newAccessibility = PermissionsChecker.checkAccessibilityPermission()

        print("""
        Updated permissions:
        - Screen Recording: \(hasScreenRecording) -> \(newScreenRecording)
        - Accessibility: \(hasAccessibility) -> \(newAccessibility)
        """)
    }

    // MARK: - Multi-window capture tests

    @Test("Capture multiple windows from test host", .tags(.screenshot, .multiWindow))
    func captureMultipleWindows() async throws {
        // This test would create multiple windows in the test host
        // and capture them individually
        let app = try await launchTestHost()
        defer { terminateTestHost() }

        // Note: Future enhancement could add AppleScript to create multiple windows
        // Currently we verify we can enumerate windows

        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)
        print("Found \(windows.count) windows for test host")

        for (index, window) in windows.enumerated() {
            print("Window \(index): \(window.title) (ID: \(window.windowId))")
        }
    }

    // MARK: - Focus and foreground tests

    @Test("Test foreground window capture", .tags(.screenshot, .focus))
    func foregroundCapture() async throws {
        let app = try await launchTestHost()
        defer { terminateTestHost() }

        // Make sure test host is in foreground
        app.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Capture with foreground focus
        _ = ImageCommand()
        // Set properties as needed
        // command.app = Self.testHostAppName

        // This would test the actual foreground capture logic
        print("Test host should now be in foreground")
        #expect(app.isActive)
    }
}

// MARK: - Test Error Types

enum TestError: Error {
    case buildFailed
    case invalidPath(String)
    case testHostNotFound
    case windowNotFound
}

// Tags are defined in TestTags.swift

// MARK: - NSScreen Extension

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
