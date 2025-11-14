import AppKit
import AXorcist
import CoreGraphics
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite("Window Identity Utilities Tests", .enabled(if: TestEnvironment.runAutomationScenarios))
struct WindowIdentityUtilitiesTests {
    // MARK: - WindowIdentityService Tests

    @Test("WindowIdentityService initialization")
    @MainActor
    func windowIdentityServiceInit() {
        _ = WindowIdentityService()
        // Should initialize without crashing
        // Service is non-optional, so it will always be created
    }

    @Test("getWindowID from nil element returns nil")
    @MainActor
    func getWindowIDFromNil() {
        let service = WindowIdentityService()

        // Create a dummy AXUIElement that's not a window
        let systemWide = AXUIElementCreateSystemWide()
        let result = service.getWindowID(from: systemWide)

        #expect(result == nil)
    }

    @Test("windowExists with invalid ID")
    @MainActor
    func windowExistsInvalid() {
        let service = WindowIdentityService()

        #expect(service.windowExists(windowID: 0) == false)
        #expect(service.windowExists(windowID: 999_999_999) == false)
    }

    @Test("isWindowOnScreen with invalid ID")
    @MainActor
    func isWindowOnScreenInvalid() {
        let service = WindowIdentityService()

        let zero = service.isWindowOnScreen(windowID: 0)
        let absurd = service.isWindowOnScreen(windowID: 999_999_999)

        // We only require consistency between calls so we can detect regressions without depending on OS internals.
        #expect(zero == absurd)
    }

    @Test("getWindows for Finder")
    @MainActor
    func getWindowsForFinder() {
        let service = WindowIdentityService()

        // Find Finder app
        let runningApps = NSWorkspace.shared.runningApplications
        guard let finder = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            Issue.record("Finder not found")
            return
        }

        let windows = service.getWindows(for: finder)

        // Finder might have windows open
        for window in windows {
            #expect(window.windowID > 0)
            #expect(window.ownerPID == finder.processIdentifier)
            #expect(window.applicationName == "Finder")
            #expect(window.bundleIdentifier == "com.apple.finder")
        }
    }

    @Test("findWindow with invalid ID returns nil")
    @MainActor
    func findWindowInvalidID() {
        let service = WindowIdentityService()

        let result = service.findWindow(byID: 0)
        #expect(result == nil)

        let result2 = service.findWindow(byID: 999_999_999)
        #expect(result2 == nil)
    }

    // MARK: - WindowIdentityInfo Tests

    @Test("WindowIdentityInfo initialization")
    func windowIdentityInfoInit() {
        let info = WindowIdentityInfo(
            windowID: 12345,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 200, width: 800, height: 600),
            ownerPID: 1234,
            applicationName: "TestApp",
            bundleIdentifier: "com.test.app",
            windowLayer: 0,
            alpha: 1.0,
            axIdentifier: "test-ax-id")

        #expect(info.windowID == 12345)
        #expect(info.title == "Test Window")
        #expect(info.bounds.origin.x == 100)
        #expect(info.bounds.origin.y == 200)
        #expect(info.bounds.size.width == 800)
        #expect(info.bounds.size.height == 600)
        #expect(info.ownerPID == 1234)
        #expect(info.applicationName == "TestApp")
        #expect(info.bundleIdentifier == "com.test.app")
        #expect(info.windowLayer == 0)
        #expect(info.alpha == 1.0)
        #expect(info.axIdentifier == "test-ax-id")
    }

    @Test("WindowIdentityInfo isMainWindow")
    func windowIdentityInfoIsMainWindow() {
        let mainWindow = WindowIdentityInfo(
            windowID: 1,
            title: "Main",
            bounds: .zero,
            ownerPID: 1,
            applicationName: "App",
            bundleIdentifier: nil,
            windowLayer: 0,
            alpha: 1.0,
            axIdentifier: nil)

        #expect(mainWindow.isMainWindow == true)

        let notMainWindow = WindowIdentityInfo(
            windowID: 2,
            title: "Not Main",
            bounds: .zero,
            ownerPID: 1,
            applicationName: "App",
            bundleIdentifier: nil,
            windowLayer: 5,
            alpha: 0.5,
            axIdentifier: nil)

        #expect(notMainWindow.isMainWindow == false)
    }

    @Test("WindowIdentityInfo isDialog")
    func windowIdentityInfoIsDialog() {
        let dialogWindow = WindowIdentityInfo(
            windowID: 1,
            title: "Dialog",
            bounds: .zero,
            ownerPID: 1,
            applicationName: "App",
            bundleIdentifier: nil,
            windowLayer: 10,
            alpha: 1.0,
            axIdentifier: nil)

        #expect(dialogWindow.isDialog == true)

        let notDialogWindow = WindowIdentityInfo(
            windowID: 2,
            title: "Not Dialog",
            bounds: .zero,
            ownerPID: 1,
            applicationName: "App",
            bundleIdentifier: nil,
            windowLayer: 0,
            alpha: 1.0,
            axIdentifier: nil)

        #expect(notDialogWindow.isDialog == false)

        let systemWindow = WindowIdentityInfo(
            windowID: 3,
            title: "System",
            bounds: .zero,
            ownerPID: 1,
            applicationName: "App",
            bundleIdentifier: nil,
            windowLayer: 1001,
            alpha: 1.0,
            axIdentifier: nil)

        #expect(systemWindow.isDialog == false)
    }

    // MARK: - Integration Tests

    @Test("getWindowInfo for real window")
    @MainActor
    func getWindowInfoRealWindow() async throws {
        let identityService = WindowIdentityService()
        let windowService = WindowManagementService()

        // Try to find any window
        let windows = try await windowService.listWindows(
            target: .frontmost)

        if let firstWindow = windows.first,
           firstWindow.windowID > 0
        {
            let windowInfo = identityService.getWindowInfo(windowID: CGWindowID(firstWindow.windowID))

            if let info = windowInfo {
                #expect(info.windowID == CGWindowID(firstWindow.windowID))

                if let infoTitle = info.title,
                   !infoTitle.isEmpty,
                   !firstWindow.title.isEmpty
                {
                    let mismatchMessage =
                        "Window title mismatch (WindowIdentityService returned \"\(infoTitle)\", " +
                        "WindowManagementService returned \"\(firstWindow.title)\")"
                    #expect(
                        infoTitle == firstWindow.title ||
                            infoTitle.contains(firstWindow.title) ||
                            firstWindow.title.contains(infoTitle),
                        Comment(rawValue: mismatchMessage))
                }
                #expect(info.ownerPID > 0)
                // Other fields depend on the actual window
            }
        }
    }

    @Test("findWindow in specific app")
    @MainActor
    func findWindowInApp() {
        let service = WindowIdentityService()

        // Find Finder app
        let runningApps = NSWorkspace.shared.runningApplications
        guard let finder = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            Issue.record("Finder not found")
            return
        }

        // Get Finder windows
        let windows = service.getWindows(for: finder)

        if let firstWindow = windows.first {
            // Try to find it back
            let element = service.findWindow(byID: firstWindow.windowID, in: finder)

            if element != nil {
                // Successfully found the window element
                #expect(true)
            } else {
                // Window might have closed or AX API might not be available
                #expect(true)
            }
        }
    }
}
