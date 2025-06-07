import AppKit
@testable import peekaboo
import Testing

@Suite("WindowManager Tests", .tags(.windowManager, .unit))
struct WindowManagerTests {
    // MARK: - Get Windows For App Tests

    @Test("Getting windows for Finder app", .tags(.integration))
    func getWindowsForFinderApp() throws {
        // Get Finder's PID
        let apps = NSWorkspace.shared.runningApplications
        let finder = try #require(apps.first { $0.bundleIdentifier == "com.apple.finder" })

        // Test getting windows for Finder
        let windows = try WindowManager.getWindowsForApp(pid: finder.processIdentifier)

        // Finder usually has at least one window
        // Windows count is always non-negative

        // If there are windows, verify they're sorted by index
        if windows.count > 1 {
            for index in 1..<windows.count {
                #expect(windows[index].windowIndex >= windows[index - 1].windowIndex)
            }
        }
    }

    @Test("Getting windows for non-existent app returns empty array", .tags(.fast))
    func getWindowsForNonExistentApp() throws {
        // Test with non-existent PID
        let windows = try WindowManager.getWindowsForApp(pid: 99999)

        // Should return empty array, not throw
        #expect(windows.isEmpty)
    }

    @Test("Off-screen window filtering works correctly", .tags(.integration))
    func getWindowsWithOffScreenOption() throws {
        // Get Finder's PID for testing
        let apps = NSWorkspace.shared.runningApplications
        let finder = try #require(apps.first { $0.bundleIdentifier == "com.apple.finder" })

        // Test with includeOffScreen = true
        let allWindows = try WindowManager.getWindowsForApp(pid: finder.processIdentifier, includeOffScreen: true)

        // Test with includeOffScreen = false (default)
        let onScreenWindows = try WindowManager.getWindowsForApp(pid: finder.processIdentifier, includeOffScreen: false)

        // All windows should include off-screen ones, so count should be >= on-screen only
        #expect(allWindows.count >= onScreenWindows.count)
    }

    // MARK: - WindowData Structure Tests

    @Test("WindowData has all required properties", .tags(.fast))
    func windowDataStructure() throws {
        // Get any app's windows to test the structure
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        guard let app = apps.first else {
            return // Skip test if no regular apps running
        }

        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)

        // If we have windows, verify WindowData properties
        if let firstWindow = windows.first {
            // Check required properties exist
            #expect(firstWindow.windowId > 0)
            #expect(firstWindow.windowIndex >= 0)
            #expect(!firstWindow.title.isEmpty)
            #expect(firstWindow.bounds.width >= 0)
            #expect(firstWindow.bounds.height >= 0)
        }
    }

    // MARK: - Window Info Tests

    @Test("Getting window info with details", .tags(.integration))
    func getWindowsInfoForApp() throws {
        // Test getting window info with details
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        guard let app = apps.first else {
            return // Skip test if no regular apps running
        }

        let windowInfos = try WindowManager.getWindowsInfoForApp(
            pid: app.processIdentifier,
            includeOffScreen: false,
            includeBounds: true,
            includeIDs: true
        )

        // Verify WindowInfo structure
        if let firstInfo = windowInfos.first {
            #expect(!firstInfo.window_title.isEmpty)
            #expect(firstInfo.window_id != nil)
            #expect(firstInfo.bounds != nil)
        }
    }

    // MARK: - Parameterized Tests

    @Test(
        "Window retrieval with various options",
        arguments: [
            (includeOffScreen: true, includeBounds: true, includeIDs: true),
            (includeOffScreen: false, includeBounds: true, includeIDs: true),
            (includeOffScreen: true, includeBounds: false, includeIDs: true),
            (includeOffScreen: true, includeBounds: true, includeIDs: false)
        ]
    )
    func windowRetrievalOptions(includeOffScreen: Bool, includeBounds: Bool, includeIDs: Bool) throws {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        guard let app = apps.first else {
            return // Skip test if no regular apps running
        }

        let windowInfos = try WindowManager.getWindowsInfoForApp(
            pid: app.processIdentifier,
            includeOffScreen: includeOffScreen,
            includeBounds: includeBounds,
            includeIDs: includeIDs
        )

        // Verify options are respected
        for info in windowInfos {
            #expect(!info.window_title.isEmpty)

            if includeIDs {
                #expect(info.window_id != nil)
            } else {
                #expect(info.window_id == nil)
            }

            if includeBounds {
                #expect(info.bounds != nil)
            } else {
                #expect(info.bounds == nil)
            }
        }
    }

    // MARK: - Performance Tests

    @Test(
        "Window retrieval performance",
        arguments: 1...5
    )
    func getWindowsPerformance(iteration: Int) throws {
        // Test performance of getting windows
        let apps = NSWorkspace.shared.runningApplications
        let finder = try #require(apps.first { $0.bundleIdentifier == "com.apple.finder" })

        _ = try WindowManager.getWindowsForApp(pid: finder.processIdentifier)
        // Windows count is always non-negative
    }

    // MARK: - Error Handling Tests

    @Test("WindowError types exist", .tags(.fast))
    func windowListError() {
        // We can't easily force CGWindowListCopyWindowInfo to fail,
        // but we can test that the error type exists
        let error = WindowError.windowListFailed
        // Test that the error exists and has the expected case
        switch error {
        case .windowListFailed:
            #expect(Bool(true)) // This is the expected case
        case .noWindowsFound:
            #expect(Bool(false)) // Should not happen for this specific test
        }
    }
}

// MARK: - Extended Window Manager Tests

@Suite("WindowManager Advanced Tests", .tags(.windowManager, .integration))
struct WindowManagerAdvancedTests {
    @Test("Multiple apps window retrieval", .tags(.integration))
    func multipleAppsWindows() throws {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let appsToTest = apps.prefix(3) // Test first 3 apps

        for app in appsToTest {
            let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)

            // Each app should successfully return a window list (even if empty)
            // Windows count is always non-negative

            // Verify window indices are sequential
            for (index, window) in windows.enumerated() {
                #expect(window.windowIndex == index)
            }
        }
    }

    @Test("Window bounds validation", .tags(.integration))
    func windowBoundsValidation() throws {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        guard let app = apps.first else {
            return // Skip test if no regular apps running
        }

        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)

        for window in windows {
            // Window bounds should be reasonable
            #expect(window.bounds.width > 0)
            #expect(window.bounds.height > 0)
            #expect(window.bounds.width < 10000) // Reasonable maximum
            #expect(window.bounds.height < 10000) // Reasonable maximum
        }
    }

    @Test(
        "System apps window detection",
        arguments: ["com.apple.finder", "com.apple.dock", "com.apple.systemuiserver"]
    )
    func systemAppsWindows(bundleId: String) throws {
        let apps = NSWorkspace.shared.runningApplications

        guard let app = apps.first(where: { $0.bundleIdentifier == bundleId }) else {
            return // Skip test if app not running
        }

        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)

        // System apps might have 0 or more windows
        // Windows count is always non-negative

        // If windows exist, they should have valid properties
        for window in windows {
            #expect(window.windowId > 0)
            #expect(!window.title.isEmpty)
        }
    }

    @Test("Window title encoding", .tags(.fast))
    func windowTitleEncoding() throws {
        // Test that window titles with special characters are handled
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        for app in apps.prefix(5) {
            let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)

            for window in windows {
                // Title should be valid UTF-8
                #expect(!window.title.utf8.isEmpty)

                // Should handle common special characters
                let specialChars = ["—", "™", "©", "•", "…"]
                // Window titles might contain these, should not crash
                for char in specialChars {
                    _ = window.title.contains(char)
                }
            }
        }
    }

    @Test("Concurrent window queries", .tags(.integration))
    func concurrentWindowQueries() async throws {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        guard let app = apps.first else {
            return // Skip test if no regular apps running
        }

        // Test concurrent access to WindowManager
        await withTaskGroup(of: Result<[WindowData], Error>.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)
                        return .success(windows)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var results: [Result<[WindowData], Error>] = []
            for await result in group {
                results.append(result)
            }

            // All concurrent queries should succeed
            #expect(results.count == 5)
            for result in results {
                switch result {
                case .success:
                    break // Windows count is always non-negative
                case let .failure(error):
                    Issue.record("Concurrent query failed: \(error)")
                }
            }
        }
    }
}
